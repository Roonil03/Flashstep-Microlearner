import 'package:flutter/material.dart';

import '../../../app/theme/study_colors.dart';
import '../../../core/widgets/flashstep_logo.dart';

/// A centered account form that can grow and scroll with the keyboard or text.
class AccountFrame extends StatelessWidget {
  const AccountFrame({super.key, required this.child, this.theme});

  final Widget child;
  final ThemeData? theme;

  @override
  Widget build(BuildContext context) {
    final base = theme ?? Theme.of(context);
    final tone = StudyTone.forBrightness(StudyArea.account, base.brightness);
    final accountTheme = base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: tone.accent,
        onPrimary:
            base.brightness == Brightness.dark
                ? const Color(0xFF311B22)
                : Colors.white,
        primaryContainer: tone.fill,
        onPrimaryContainer: tone.ink,
      ),
    );
    return Theme(
      data: accountTheme,
      child: Scaffold(
        backgroundColor: tone.fill,
        body: SafeArea(
          child: LayoutBuilder(
            builder:
                (context, constraints) => SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: (constraints.maxHeight - 48).clamp(
                        0,
                        double.infinity,
                      ),
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: base.colorScheme.surface,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: tone.accent.withValues(alpha: .35),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: tone.accent.withValues(alpha: .10),
                                blurRadius: 0,
                                offset: const Offset(7, 8),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 28,
                            ),
                            child: child,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
          ),
        ),
      ),
    );
  }
}

/// Identifies Flashstep on both account forms.
class AccountMark extends StatelessWidget {
  const AccountMark({super.key});

  @override
  Widget build(BuildContext context) {
    final tone = context.studyTone(StudyArea.account);
    return Column(
      children: [
        FlashstepLogo(size: 64, color: tone.accent),
        const SizedBox(height: 12),
        Text(
          'Flashstep Microlearner',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(color: tone.ink),
        ),
      ],
    );
  }
}
