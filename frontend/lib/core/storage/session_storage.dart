import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionStorage {
  static const _tokenKey = 'jwt_token';

  const SessionStorage();

  FlutterSecureStorage get _storage => const FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
      );

  Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<String?> readToken() async {
    return _storage.read(key: _tokenKey);
  }

  Future<void> clearToken() async {
    await _storage.delete(key: _tokenKey);
  }

  static const String _usernameKey = 'username';

  Future<void> writeUsername(String username) async {
  await _storage.write(key: _usernameKey, value: username);
  }

  Future<String?> readUsername() async {
    return _storage.read(key: _usernameKey);
  }

  Future<void> clearUsername() async {
    await _storage.delete(key: _usernameKey);
  }

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}