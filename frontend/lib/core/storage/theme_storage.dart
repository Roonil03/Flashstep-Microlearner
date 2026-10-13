import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum AppFontSize { small, device, large, extraLarge }

class ThemeStorage {
  static const _key = 'app_theme_mode';
  static const _fontSizeKey = 'app_font_size';

  const ThemeStorage();

  FlutterSecureStorage get _storage => const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<ThemeMode> readThemeMode() async {
    final value = await _storage.read(key: _key);
    switch (value) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> writeThemeMode(ThemeMode mode) async {
    final value = switch (mode) {
      ThemeMode.dark => 'dark',
      ThemeMode.light => 'light',
      ThemeMode.system => 'system',
    };
    await _storage.write(key: _key, value: value);
  }

  Future<AppFontSize> readFontSize() async {
    final value = await _storage.read(key: _fontSizeKey);
    return AppFontSize.values.firstWhere(
      (size) => size.name == value,
      orElse: () => AppFontSize.device,
    );
  }

  Future<void> writeFontSize(AppFontSize size) =>
      _storage.write(key: _fontSizeKey, value: size.name);
}
