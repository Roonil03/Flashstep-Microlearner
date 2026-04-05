import 'dart:async';

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
      final me = await api.getMe(session.token);

      if (me.userId.isEmpty) {
        throw StateError('Login succeeded but user id could not be resolved.');
      }

      resolvedUserId = me.userId;
      if (me.username.isNotEmpty) {
        resolvedUsername = me.username;
      }
      if (me.email.isNotEmpty) {
        resolvedEmail = me.email;
      }
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

    final storedUserId = await storage.readUserId();
    final hasStoredUser = storedUserId != null && storedUserId.isNotEmpty;

    if (hasStoredUser) {
      await databaseManager.switchToUser(storedUserId!);
    }

    try {
      final me = await api.getMe(token).timeout(const Duration(seconds: 3));

      if (me.userId.isEmpty) {
        await _resetSessionOnly();
        return false;
      }

      await storage.writeUserId(me.userId);

      if (me.username.isNotEmpty) {
        await storage.writeUsername(me.username);
      }

      await databaseManager.switchToUser(me.userId);
      return true;
    } on AuthApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) {
        await _resetSessionOnly();
        return false;
      }
      return hasStoredUser;
    } on TimeoutException {
      return hasStoredUser;
    } catch (_) {
      return hasStoredUser;
    }
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

  Future<void> _resetSessionOnly() async {
    await storage.clearAll();
    await databaseManager.switchToAnonymous();
  }
}
