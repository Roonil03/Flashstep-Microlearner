import '../../onboarding/data/navigation_tour_storage.dart';
import 'dart:async';
import 'dart:convert';

import '../../../core/storage/database_manager.dart';
import '../../../core/storage/analytics_cache_store.dart';
import '../../../core/storage/session_storage.dart';
import '../../../core/network/api_errors.dart';
import '../../decks/data/sync_metadata_store.dart';
import 'auth_api.dart';

class AuthRepository {
  final AuthApi api;
  final SessionStorage storage;
  final DatabaseManager databaseManager;
  final AnalyticsCacheStore analyticsCache;
  final SyncMetadataStore syncMetadata;
  static Future<void> _sessionMutation = Future<void>.value();

  Future<T> _mutateSession<T>(Future<T> Function() action) {
    final next = _sessionMutation.then((_) => action());
    _sessionMutation = next.then<void>((_) {}, onError: (Object _) {});
    return next;
  }

  AuthRepository({
    required this.api,
    required this.storage,
    required this.databaseManager,
    AnalyticsCacheStore? analyticsCache,
    SyncMetadataStore? syncMetadata,
  }) : analyticsCache = analyticsCache ?? AnalyticsCacheStore(),
       syncMetadata = syncMetadata ?? const SyncMetadataStore();

  Future<String> _requireToken() async {
    final token = await storage.readToken();
    if (token == null || token.isEmpty) {
      throw StateError('No active session found. Please sign in again.');
    }
    return token;
  }

  Future<AuthSession> login({
    required String email,
    required String password,
    String? expectedUserId,
  }) async {
    final session = await api.login(email: email, password: password);

    if (session.token.isEmpty) {
      throw StateError('Login succeeded but no token was returned.');
    }

    String resolvedUserId = session.userId;
    String resolvedUsername = session.username;
    String resolvedEmail = session.email;

    if (resolvedUserId.isEmpty) {
      final claims = _decodeJwtClaims(session.token);
      resolvedUserId =
          _claimAsString(claims, 'user_id') ??
          _claimAsString(claims, 'sub') ??
          '';
    }

    if (resolvedUserId.isEmpty ||
        resolvedUsername.isEmpty ||
        resolvedEmail.isEmpty) {
      try {
        final me = await api
            .getMe(session.token)
            .timeout(const Duration(seconds: 3));
        if (resolvedUserId.isEmpty && me.userId.isNotEmpty) {
          resolvedUserId = me.userId;
        }
        if (resolvedUsername.isEmpty && me.username.isNotEmpty) {
          resolvedUsername = me.username;
        }
        if (resolvedEmail.isEmpty && me.email.isNotEmpty) {
          resolvedEmail = me.email;
        }
      } on TimeoutException {
        // The token claims may still provide enough information to sign in.
      } on AuthApiException catch (e) {
        if (e.statusCode == 401 || e.statusCode == 403) {
          rethrow;
        }
      } catch (_) {}
    }

    if (resolvedUserId.isEmpty) {
      throw StateError('Login succeeded but user id could not be resolved.');
    }
    if (expectedUserId != null && resolvedUserId != expectedUserId) {
      throw const AuthApiException(
        'Sign in to the same account to sync your saved decks and changes.',
      );
    }

    // Never expose a new token together with the previous account's ID or DB.
    await _mutateSession(() async {
      if (expectedUserId != null &&
          await storage.readUserId() != expectedUserId) {
        throw const AuthApiException(
          'Your account changed. Return to your saved decks and try again.',
        );
      }
      try {
        await storage.clearAll();
        // Database listeners must see the new account ID when they rebuild.
        await storage.writeUserId(resolvedUserId);
        await databaseManager.switchToUser(resolvedUserId);
        if (resolvedUsername.isNotEmpty) {
          await storage.writeUsername(resolvedUsername);
        }
        await storage.saveToken(session.token);
      } catch (_) {
        await storage.clearAll();
        await databaseManager.switchToAnonymous();
        rethrow;
      }
    });

    return AuthSession(
      token: session.token,
      userId: resolvedUserId,
      email: resolvedEmail,
      username: resolvedUsername,
    );
  }

  Future<void> register({
    required String email,
    required String username,
    required String password,
  }) async {
    final session = await api.register(
      email: email,
      username: username,
      password: password,
    );
    if (session != null && session.userId.isNotEmpty) {
      await NavigationTourStorage(storage).markEligible(session.userId);
    }
  }

  Future<bool> hasValidSession() async {
    final token = await storage.readToken();
    if (token == null || token.isEmpty) return false;

    final claims = _decodeJwtClaims(token);
    final savedUserId = (await storage.readUserId())?.trim();
    final claimedUserId =
        _claimAsString(claims, 'user_id') ?? _claimAsString(claims, 'sub');
    if (savedUserId != null &&
        savedUserId.isNotEmpty &&
        claimedUserId != null &&
        claimedUserId != savedUserId) {
      // A token must never select a different account's local database.
      await _resetSessionOnly(expectedToken: token);
      return false;
    }

    String? resolvedUserId =
        savedUserId != null && savedUserId.isNotEmpty
            ? savedUserId
            : claimedUserId;

    if (resolvedUserId == null || resolvedUserId.trim().isEmpty) {
      try {
        final me = await api.getMe(token).timeout(const Duration(seconds: 3));
        if (me.userId.isEmpty) {
          await _resetSessionOnly(expectedToken: token);
          return false;
        }
        resolvedUserId = me.userId;
      } on AuthApiException catch (e) {
        if (e.statusCode == 401 || e.statusCode == 403) {
          await _resetSessionOnly(expectedToken: token);
          return false;
        }
        return false;
      } on TimeoutException {
        return false;
      } catch (_) {
        return false;
      }
    }

    final restored = await _mutateSession(() async {
      if (await storage.readToken() != token) return false;
      await storage.writeUserId(resolvedUserId!.trim());
      await databaseManager.switchToUser(resolvedUserId.trim());
      return true;
    });
    if (!restored) return false;

    // Access-token expiry prevents online sync, not access to this account's
    // saved decks. No password login or network response is needed to restore
    // the local account; refresh failures leave it available offline.
    unawaited(_refreshSessionProfile(token, resolvedUserId.trim()));
    return true;
  }

  Future<void> logout({
    String? expectedUserId,
    String? expectedToken,
  }) => _mutateSession(() async {
    if ((expectedUserId != null &&
            await storage.readUserId() != expectedUserId) ||
        (expectedToken != null && await storage.readToken() != expectedToken)) {
      throw StateError('Your account changed. Please try signing out again.');
    }
    await storage.clearAll();
    await databaseManager.switchToAnonymous();
  });

  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final token = await _requireToken();
    await api.changePassword(
      token: token,
      oldPassword: oldPassword,
      newPassword: newPassword,
    );
  }

  Future<void> changeUsername({required String username}) async {
    final token = await _requireToken();
    await api.changeUsername(token: token, username: username);
    await _mutateSession(() async {
      if (await storage.readToken() == token) {
        await storage.writeUsername(username);
      }
    });
  }

  Future<void> deleteAccount() async {
    final token = await _requireToken();
    final userId = await storage.readUserId();
    if (userId == null ||
        userId.isEmpty ||
        await storage.readToken() != token) {
      throw StateError(
        'Your account changed. Sign in again before deleting it.',
      );
    }
    await api.deleteAccount(token: token);
    // Attempt every account-scoped cleanup even if one local store fails.
    final cleanup = await Future.wait(
      [
        Future.sync(() => analyticsCache.deleteForUser(userId)),
        Future.sync(() => syncMetadata.delete(userId)),
        Future.sync(() => NavigationTourStorage(storage).clear(userId)),
        Future.sync(() => storage.clearLastSyncAt(userId: userId)),
        _mutateSession(() async {
          if (await storage.readToken() == token &&
              await storage.readUserId() == userId) {
            await storage.clearAll();
          }
        }),
        _mutateSession(() => databaseManager.deleteDatabaseForUser(userId)),
      ].map(
        (operation) => operation.then<Object?>(
          (_) => null,
          onError: (Object error) => error,
        ),
      ),
    );
    if (cleanup.any((error) => error != null)) {
      throw const ApiRequestException(
        'Your account was deleted. Some local data could not be cleared. Restart the app and clear its local storage.',
      );
    }
  }

  Future<void> _refreshSessionProfile(String token, String userId) async {
    try {
      final me = await api.getMe(token).timeout(const Duration(seconds: 3));
      if (me.userId.isNotEmpty && me.userId != userId) {
        await _resetSessionOnly(expectedToken: token);
        return;
      }
      await _mutateSession(() async {
        if (me.userId == userId &&
            me.username.isNotEmpty &&
            await storage.readToken() == token &&
            await storage.readUserId() == userId) {
          await storage.writeUsername(me.username);
        }
      });
    } on AuthApiException catch (e) {
      final expiredAccessToken =
          e.statusCode == 401 && _isExpired(_decodeJwtClaims(token));
      if ((e.statusCode == 401 || e.statusCode == 403) &&
          !expiredAccessToken &&
          await storage.readToken() == token) {
        await _resetSessionOnly(expectedToken: token);
      }
      // An expired token is expected to receive 401. Preserve its local account
      // and pending changes; online sync will request a new sign-in. Explicit
      // forbidden responses or rejection of a current token still end access.
    } on TimeoutException {
      // Keep the locally restored session.
    } catch (_) {
      // Ignore transient refresh failures.
    }
  }

  bool _isExpired(Map<String, dynamic>? claims) {
    if (claims == null) {
      return false;
    }
    final exp = claims['exp'];
    int? epochSeconds;
    if (exp is int) {
      epochSeconds = exp;
    } else if (exp is String) {
      epochSeconds = int.tryParse(exp);
    }
    if (epochSeconds == null) {
      return false;
    }
    final expiry = DateTime.fromMillisecondsSinceEpoch(
      epochSeconds * 1000,
      isUtc: true,
    );
    return !expiry.isAfter(DateTime.now().toUtc());
  }

  String? _claimAsString(Map<String, dynamic>? claims, String key) {
    final value = claims?[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }

  Map<String, dynamic>? _decodeJwtClaims(String token) {
    final parts = token.split('.');
    if (parts.length != 3) {
      return null;
    }
    try {
      final normalized = base64Url.normalize(parts[1]);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final json = jsonDecode(decoded);
      if (json is Map<String, dynamic>) {
        return json;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<void> _resetSessionOnly({String? expectedToken}) => _mutateSession(
    () async {
      if (expectedToken != null && await storage.readToken() != expectedToken) {
        return;
      }
      await storage.clearAll();
      await databaseManager.switchToAnonymous();
    },
  );
}
