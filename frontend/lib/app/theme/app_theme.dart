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
  static ThemeData light() => _studyTheme(Brightness.light);
  static ThemeData dark() => _studyTheme(Brightness.dark);

  static ThemeData _studyTheme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final paper = dark ? const Color(0xFF10242F) : const Color(0xFFF5F8F8);
    final ink = dark ? const Color(0xFFEDF5F4) : const Color(0xFF102F47);
    final accent = dark ? const Color(0xFF8BDACB) : const Color(0xFF006D66);
    final colors = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
    ).copyWith(
      primary: accent,
      onPrimary: dark ? paper : Colors.white,
      primaryContainer:
          dark ? const Color(0xFF1A3642) : const Color(0xFFE4F1EE),
      onPrimaryContainer: ink,
      surface: paper,
      onSurface: ink,
      onSurfaceVariant:
          dark ? const Color(0xFFB5C8CC) : const Color(0xFF486270),
      outlineVariant: dark ? const Color(0xFF425E68) : const Color(0xFFCBD8D9),
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
    );
    final border = OutlineInputBorder(borderRadius: BorderRadius.circular(8));
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colors,
      scaffoldBackgroundColor: paper,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      appBarTheme: AppBarTheme(
        backgroundColor: paper,
        foregroundColor: ink,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 23,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape: shape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: shape,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colors.outlineVariant,
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? colors.primaryContainer : Colors.white,
        border: border,
        enabledBorder: border.copyWith(
          borderSide: BorderSide(color: colors.outline),
        ),
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: accent, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }
}
