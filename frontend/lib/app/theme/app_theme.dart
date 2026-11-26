import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/theme_storage.dart';
import 'study_colors.dart';

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
    final paper = dark ? const Color(0xFF121924) : const Color(0xFFF9FAFC);
    final ink = dark ? const Color(0xFFF3F4FA) : const Color(0xFF182339);
    final study = StudyTone.forBrightness(StudyArea.study, brightness);
    final library = StudyTone.forBrightness(StudyArea.library, brightness);
    final progress = StudyTone.forBrightness(StudyArea.progress, brightness);
    final accent = study.accent;
    final colors = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
    ).copyWith(
      primary: accent,
      onPrimary: dark ? paper : Colors.white,
      primaryContainer: study.fill,
      onPrimaryContainer: study.ink,
      secondary: library.accent,
      onSecondary: dark ? paper : Colors.white,
      secondaryContainer: library.fill,
      onSecondaryContainer: library.ink,
      tertiary: progress.accent,
      onTertiary: dark ? paper : Colors.white,
      tertiaryContainer: progress.fill,
      onTertiaryContainer: progress.ink,
      surface: paper,
      onSurface: ink,
      onSurfaceVariant:
          dark ? const Color(0xFFBFC9DA) : const Color(0xFF4C5A70),
      outlineVariant: dark ? const Color(0xFF49536A) : const Color(0xFFCCD3DF),
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
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
        fillColor: dark ? const Color(0xFF1D2738) : Colors.white,
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
