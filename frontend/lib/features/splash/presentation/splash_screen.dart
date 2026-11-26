import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/network/providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _redirecting = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    _verifyAuth();
  }

  Future<void> _verifyAuth() async {
    if (_redirecting) {
      return;
    }
    _redirecting = true;
    final authRepository = ref.read(authRepositoryProvider);
    bool valid = false;
    try {
      valid = await authRepository.hasValidSession();
    } catch (_) {
      valid = false;
    }
    if (!mounted) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushNamedAndRemoveUntil(
      valid ? AppRoutes.home : AppRoutes.login,
      (route) => false,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _blendPalette(List<Color> palette, double t) {
    final count = palette.length;
    final scaled = t * count;
    final i = scaled.floor() % count;
    final j = (i + 1) % count;
    final localT = Curves.easeInOut.transform(scaled - scaled.floor());
    return Color.lerp(palette[i], palette[j], localT)!;
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(appThemeModeProvider);

    final isDark = themeMode == ThemeMode.dark;

    final lightPalette = <Color>[
      const Color(0xFFFFD6E0),
      const Color(0xFFFFF1BA),
      const Color(0xFFD0F4DE),
      const Color(0xFFA9DEF9),
      const Color(0xFFE4C1F9),
    ];

    final darkPalette = <Color>[
      const Color(0xFF0B1320),
      const Color(0xFF1B1B3A),
      const Color(0xFF2D1E2F),
      const Color(0xFF1F3B4D),
      const Color(0xFF173F35),
    ];

    final palette = isDark ? darkPalette : lightPalette;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final c1 = _blendPalette(palette, t);
        final c2 = _blendPalette(palette, (t + 0.33) % 1.0);
        final c3 = _blendPalette(palette, (t + 0.66) % 1.0);
        return Scaffold(
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [c1, c2, c3],
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Transform.rotate(
                    angle: _controller.value * 2 * math.pi,
                    child: Image.asset(
                      'assets/LogoWithoutText_WithoutBGLarge_Square_Monochrome.png',
                      width: 150,
                      height: 150,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.auto_stories_rounded,
                        size: 120,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Flashstep Microlearner',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: isDark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}