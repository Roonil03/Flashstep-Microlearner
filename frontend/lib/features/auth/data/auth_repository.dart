import '../../../core/storage/session_storage.dart';
import 'auth_api.dart';

class AuthRepository {
  final AuthApi api;
  final SessionStorage storage;

  AuthRepository({
    required this.api,
    required this.storage,
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

    await storage.saveToken(session.token);

    if (session.username.isNotEmpty) {
      await storage.writeUsername(session.username);
    }

    if (session.userId.isNotEmpty) {
      await storage.writeUserId(session.userId);
      return session;
    }

    final me = await api.getMe(session.token);

    if (me.userId.isEmpty) {
      throw StateError('Login succeeded but user id could not be resolved.');
    }

    if (me.username.isNotEmpty) {
      await storage.writeUsername(me.username);
    }

    await storage.writeUserId(me.userId);

    return AuthSession(
      token: session.token,
      userId: me.userId,
      email: me.email.isNotEmpty ? me.email : session.email,
      username: me.username.isNotEmpty ? me.username : session.username,
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
        return false;
      }

      await storage.writeUserId(me.userId);

      if (me.username.isNotEmpty) {
        await storage.writeUsername(me.username);
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> logout() async {
    await storage.clearAll();
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
    await storage.clearAll();
  }
}