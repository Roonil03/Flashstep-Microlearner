import '../../../core/storage/session_storage.dart';
import 'auth_api.dart';

class AuthRepository {
  final AuthApi api;
  final SessionStorage storage;

  AuthRepository({
    required this.api,
    required this.storage,
  });

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final session = await api.login(
      email: email,
      password: password,
    );

    await storage.saveToken(session.token);
    await storage.writeUsername(session.username);
    return session;
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
    return api.validateToken(token);
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