import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionStorage {
  static const _tokenKey = 'jwt_token';
  static const _deviceIdKey = 'device_id';
  static const _usernameKey = 'username';
  static const _userIdKey = 'user_id';
  static const _lastSyncAtKeyPrefix = 'last_sync_at';
  static const _dailyReviewLimitKey = 'daily_review_limit';
  static const _selectiveReviewDecksOnlyKey = 'selective_review_decks_only';

  const SessionStorage();

  FlutterSecureStorage get _storage => const FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
      );

  String _lastSyncKeyFor(String userId) => '$_lastSyncAtKeyPrefix::$userId';

  Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<String?> readToken() async {
    return _storage.read(key: _tokenKey);
  }

  Future<void> clearToken() async {
    await _storage.delete(key: _tokenKey);
  }

  Future<void> writeUsername(String username) async {
    await _storage.write(key: _usernameKey, value: username);
  }

  Future<String?> readUsername() async {
    return _storage.read(key: _usernameKey);
  }

  Future<void> clearUsername() async {
    await _storage.delete(key: _usernameKey);
  }

  Future<void> writeLastSyncAt(DateTime time, {String? userId}) async {
    final resolvedUserId = userId ?? await readUserId();
    if (resolvedUserId == null || resolvedUserId.isEmpty) {
      return;
    }
    await _storage.write(
      key: _lastSyncKeyFor(resolvedUserId),
      value: time.toUtc().toIso8601String(),
    );
  }

  Future<DateTime?> readLastSyncAt({String? userId}) async {
    final resolvedUserId = userId ?? await readUserId();
    if (resolvedUserId == null || resolvedUserId.isEmpty) {
      return null;
    }
    final value = await _storage.read(key: _lastSyncKeyFor(resolvedUserId));
    if (value == null) return null;
    return DateTime.tryParse(value);
  }

  Future<void> clearLastSyncAt({String? userId}) async {
    final resolvedUserId = userId ?? await readUserId();
    if (resolvedUserId == null || resolvedUserId.isEmpty) {
      return;
    }
    await _storage.delete(key: _lastSyncKeyFor(resolvedUserId));
  }

  Future<void> writeDeviceId(String deviceId) async {
    await _storage.write(key: _deviceIdKey, value: deviceId);
  }

  Future<String?> readDeviceId() async {
    return _storage.read(key: _deviceIdKey);
  }

  Future<void> clearDeviceId() async {
    await _storage.delete(key: _deviceIdKey);
  }


  Future<void> writeDailyReviewLimit(int limit) async {
    final normalized = limit.clamp(1, 500) as int;
    await _storage.write(key: _dailyReviewLimitKey, value: normalized.toString());
  }

  Future<int> readDailyReviewLimit() async {
    final value = await _storage.read(key: _dailyReviewLimitKey);
    final parsed = int.tryParse(value ?? '');
    if (parsed == null || parsed < 1) {
      return 25;
    }
    return parsed;
  }

  Future<void> writeSelectiveReviewDecksOnly(bool value) async {
    await _storage.write(
      key: _selectiveReviewDecksOnlyKey,
      value: value ? 'true' : 'false',
    );
  }

  Future<bool> readSelectiveReviewDecksOnly() async {
    final value = await _storage.read(key: _selectiveReviewDecksOnlyKey);
    if (value == null) {
      return true;
    }
    return value.toLowerCase() == 'true';
  }

  Future<void> clearAll() async {
    await clearToken();
    await clearUsername();
    await clearUserId();
  }

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
