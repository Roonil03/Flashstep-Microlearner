import '../../../core/storage/session_storage.dart';
import 'auth_api.dart';
import '../../../core/storage/app_database.dart';

class AuthRepository {
  final AuthApi api;
  final SessionStorage storage;
  final AppDatabase database;

  AuthRepository({
    required this.api,
    required this.storage,
    required this.database,
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
    final previousUserId = await storage.readUserId();

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

    if (previousUserId != null &&
        previousUserId.isNotEmpty &&
        previousUserId != resolvedUserId) {
      await _clearLocalAppData();
      await storage.clearLastSyncAt();
    }

    await storage.saveToken(session.token);
    await storage.writeUserId(resolvedUserId);

    if (resolvedUsername.isNotEmpty) {
      await storage.writeUsername(resolvedUsername);
    }

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

    try {
      final me = await api.getMe(token);

      if (me.userId.isEmpty) {
        await _resetSessionAndLocalData();
        return false;
      }

      await storage.writeUserId(me.userId);

      if (me.username.isNotEmpty) {
        await storage.writeUsername(me.username);
      }

      return true;
    } catch (_) {
      await _resetSessionAndLocalData();
      return false;
    }
  }

  Future<void> logout() async {
    await _resetSessionAndLocalData();
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
    await api.deleteAccount(token: token);
    await _resetSessionAndLocalData();
  }

  Future<void> _clearLocalAppData() async {
    await database.clearAllLocalData();
  }

  Future<void> _resetSessionAndLocalData() async {
    await _clearLocalAppData();
    await storage.clearAll();
  }
}