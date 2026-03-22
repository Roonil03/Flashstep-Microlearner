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
    required String identifier,
    required String password,
  }) async {
    final session = await api.login(
      identifier: identifier,
      password: password,
    );

    await storage.saveToken(session.token);
    return session;
  }

  Future<bool> hasValidSession() async {
    final token = await storage.readToken();
    if (token == null || token.isEmpty) return false;
    return api.validateToken(token);
  }

  Future<void> logout() async {
    await storage.clearToken();
  }
}