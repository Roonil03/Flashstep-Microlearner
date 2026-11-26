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

final appFontSizeProvider =
    StateNotifierProvider<FontSizeNotifier, AppFontSize>(
      (ref) => FontSizeNotifier(ref.read(themeStorageProvider)),
    );

class FontSizeNotifier extends StateNotifier<AppFontSize> {
  final ThemeStorage _storage;

  FontSizeNotifier(this._storage) : super(AppFontSize.device) {
    _load();
  }

  Future<void> _load() async {
    try {
      final size = await _storage.readFontSize();
      if (mounted) state = size;
    } catch (_) {
      // Keep device sizing when preferences cannot be read.
    }
  }

  Future<void> setSize(AppFontSize size) async {
    state = size;
    try {
      await _storage.writeFontSize(size);
    } catch (_) {
      // The chosen size remains usable for this app session.
    }
  }
}

extension AppFontSizeFactor on AppFontSize {
  double get factor => switch (this) {
    AppFontSize.small => 0.9,
    AppFontSize.device => 1.0,
    AppFontSize.large => 1.15,
    AppFontSize.extraLarge => 1.3,
  };
}

class AppTextScaler extends TextScaler {
  final TextScaler deviceScaler;
  final double factor;

  const AppTextScaler(this.deviceScaler, this.factor);

  @override
  double scale(double fontSize) => deviceScaler.scale(fontSize) * factor;

  @override
  double get textScaleFactor => scale(14) / 14;

  @override
  bool operator ==(Object other) =>
      other is AppTextScaler &&
      other.deviceScaler == deviceScaler &&
      other.factor == factor;

  @override
  int get hashCode => Object.hash(deviceScaler, factor);
}

class ThemeNotifier extends StateNotifier<ThemeMode> {
  final ThemeStorage _storage;

  ThemeNotifier(this._storage) : super(ThemeMode.system) {
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
