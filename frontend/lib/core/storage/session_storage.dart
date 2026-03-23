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

   Future<void> writeLastSyncAt(DateTime time) async {
    await _storage.write(
      key: _lastSyncAtKey,
      value: time.toIso8601String(),
    );
  }

  Future<DateTime?> readLastSyncAt() async {
    final value = await _storage.read(key: _lastSyncAtKey);
    if (value == null) return null;
    return DateTime.tryParse(value);
  }

  Future<void> clearLastSyncAt() async {
    await _storage.delete(key: _lastSyncAtKey);
  }

  Future<void> clearAll() async {
    await clearToken();
    await clearUsername();
    await clearUserId();
    await clearLastSyncAt();
  }  

  static const _userIdKey = 'user_id';
  static const _lastSyncAtKey = 'last_sync_at';

  // Future<void> writeUserId(String userId) async {
  //   await _storage.write(key: _userIdKey, value: userId);
  // }

  // Future<String?> readUserId() async {
  //   return _storage.read(key: _userIdKey);
  // }

  // Future<void> clearUserId() async {
  //   await _storage.delete(key: _userIdKey);
  // }

  Future<void> writeUserId(String userId) async {
    await _storage.write(key: _userIdKey, value: userId);
  }

  Future<String?> readUserId() async {
    return _storage.read(key: _userIdKey);
  }

  Future<void> clearUserId() async {
    await _storage.delete(key: _userIdKey);
  }
}