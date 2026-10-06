import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/theme_storage.dart';

final themeStorageProvider = Provider<ThemeStorage>(
  (ref) => const ThemeStorage(),
);

final appThemeModeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((
  ref,
) {
  final storage = ref.read(themeStorageProvider);
  return ThemeNotifier(storage);
});

class ThemeNotifier extends StateNotifier<ThemeMode> {
  final ThemeStorage _storage;

  ThemeNotifier(this._storage) : super(ThemeMode.light) {
    _load();
  }

  Future<void> _load() async {
    try {
      final mode = await _storage.readThemeMode();
      if (mounted) state = mode;
    } catch (_) {
      // Keep the usable default when device preference storage is unavailable.
    }
  }

  Future<void> setTheme(ThemeMode mode) async {
    state = mode;
    await _storage.writeThemeMode(mode);
  }
}

class AppTheme {
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
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
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.black,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF7EC8E3),
        brightness: Brightness.dark,
      ),
    );
  }
}
