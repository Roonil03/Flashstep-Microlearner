import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/theme_storage.dart';

final themeStorageProvider = Provider<ThemeStorage>((ref) => const ThemeStorage());

final appThemeModeProvider = FutureProvider<ThemeMode>((ref) async {
  final storage = ref.read(themeStorageProvider);
  return storage.readThemeMode();
});

class AppTheme {
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: Colors.white,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF003153),
        brightness: Brightness.light,
      ),
    );
  }

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.black,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF7EC8E3),
        brightness: Brightness.dark,
      ),
    );
  }
}