import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router.dart';
import '../../../app/theme/study_colors.dart';
import '../../../core/network/providers.dart';
import '../../../core/widgets/flashstep_logo.dart';

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
    final tone = context.studyTone(StudyArea.account);
    return Scaffold(
      backgroundColor: tone.fill,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: tone.accent, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: tone.accent.withValues(alpha: .2),
                        offset: const Offset(8, 8),
                      ),
                    ],
                  ),
                  child: const FlashstepLogo(size: 136),
                ),
                const SizedBox(height: 24),
                Text(
                  'Flashstep Microlearner',
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text('Opening your study library'),
                const SizedBox(height: 24),
                SizedBox(
                  width: 120,
                  child: LinearProgressIndicator(
                    color: tone.accent,
                    backgroundColor: tone.accent.withValues(alpha: .15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
