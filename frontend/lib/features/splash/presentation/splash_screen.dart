import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router.dart';
import '../../../core/network/providers.dart';
import '../../../core/widgets/image_decode_size.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _redirecting = false;

  @override
  void initState() {
    super.initState();
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
    Navigator.of(context).pushNamedAndRemoveUntil(
      valid ? AppRoutes.home : AppRoutes.login,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/LogoWithoutText_WithoutBGLarge_Square_Monochrome.png',
                  width: 136,
                  height: 136,
                  excludeFromSemantics: true,
                  cacheWidth: imageDecodeSize(
                    logicalSize: 136,
                    devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
                    sourceSize: 768,
                  ),
                  color: theme.colorScheme.onSurface,
                ),
                const SizedBox(height: 24),
                Text(
                  'Flashstep Microlearner',
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text('Opening your study library'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
