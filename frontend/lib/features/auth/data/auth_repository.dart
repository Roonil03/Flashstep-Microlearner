import 'dart:async';
import 'dart:convert';

import '../../../core/storage/database_manager.dart';
import '../../../core/storage/session_storage.dart';
import 'auth_api.dart';

class AuthRepository {
  final AuthApi api;
  final SessionStorage storage;
  final DatabaseManager databaseManager;

  AuthRepository({
    required this.api,
    required this.storage,
    required this.databaseManager,
  });

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
  }) async {
    final session = await api.login(
      email: email,
      password: password,
    );

    if (session.token.isEmpty) {
      throw StateError('Login succeeded but no token was returned.');
    }

    String resolvedUserId = session.userId;
    String resolvedUsername = session.username;
    String resolvedEmail = session.email;

    if (resolvedUserId.isEmpty) {
      final claims = _decodeJwtClaims(session.token);
      resolvedUserId = _claimAsString(claims, 'user_id') ??
          _claimAsString(claims, 'sub') ??
          '';
    }

    if (resolvedUserId.isEmpty ||
        resolvedUsername.isEmpty ||
        resolvedEmail.isEmpty) {
      try {
        final me =
            await api.getMe(session.token).timeout(const Duration(seconds: 3));
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
      } on AuthApiException catch (e) {
        if (e.statusCode == 401 || e.statusCode == 403) {
          rethrow;
        }
      } catch (_) {
      }
    }

    if (resolvedUserId.isEmpty) {
      throw StateError('Login succeeded but user id could not be resolved.');
    }

    await storage.saveToken(session.token);
    await storage.writeUserId(resolvedUserId);

    if (resolvedUsername.isNotEmpty) {
      await storage.writeUsername(resolvedUsername);
    }

    await databaseManager.switchToUser(resolvedUserId);

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
    await api.register(
      email: email,
      username: username,
      password: password,
    );
  }

  Future<bool> hasValidSession() async {
    final token = await storage.readToken();
    if (token == null || token.isEmpty) return false;

    final claims = _decodeJwtClaims(token);
    if (_isExpired(claims)) {
      await _resetSessionOnly();
      return false;
    }

    String? resolvedUserId = await storage.readUserId();
    resolvedUserId ??= _claimAsString(claims, 'user_id');
    resolvedUserId ??= _claimAsString(claims, 'sub');

    if (resolvedUserId == null || resolvedUserId.trim().isEmpty) {
      try {
        final me = await api.getMe(token).timeout(const Duration(seconds: 3));
        if (me.userId.isEmpty) {
          await _resetSessionOnly();
          return false;
        }
        resolvedUserId = me.userId;
        await storage.writeUserId(me.userId);
        if (me.username.isNotEmpty) {
          await storage.writeUsername(me.username);
        }
      } on AuthApiException catch (e) {
        if (e.statusCode == 401 || e.statusCode == 403) {
          await _resetSessionOnly();
          return false;
        }
        return false;
      } on TimeoutException {
        return false;
      } catch (_) {
        return false;
      }
    }

    await storage.writeUserId(resolvedUserId.trim());
    await databaseManager.switchToUser(resolvedUserId.trim());

    unawaited(_refreshSessionProfile(token));
    return true;
  }

  Future<void> logout() async {
    await _resetSessionOnly();
  }

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

  Future<void> deleteAccount() async {
    final token = await _requireToken();
    final userId = await storage.readUserId();
    await api.deleteAccount(token: token);
    await storage.clearAll();
    if (userId != null && userId.isNotEmpty) {
      await storage.clearLastSyncAt(userId: userId);
      await databaseManager.deleteDatabaseForUser(userId);
    } else {
      await databaseManager.switchToAnonymous();
    }
  }

  Future<void> _refreshSessionProfile(String token) async {
    try {
      final me = await api.getMe(token).timeout(const Duration(seconds: 3));
      if (me.userId.isEmpty) {
        return;
      }

      await storage.writeUserId(me.userId);
      if (me.username.isNotEmpty) {
        await storage.writeUsername(me.username);
      }
      await databaseManager.switchToUser(me.userId);
    } on AuthApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) {
        await _resetSessionOnly();
      }
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
    return expiry.isBefore(DateTime.now().toUtc());
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

  Future<void> _resetSessionOnly() async {
    await storage.clearAll();
    await databaseManager.switchToAnonymous();
  }
}