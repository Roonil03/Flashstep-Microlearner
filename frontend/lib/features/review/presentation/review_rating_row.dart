import 'package:flutter/material.dart';

import '../../../app/theme/study_colors.dart';

/// A full-width rating target that reflows with the learner's text size.
class ReviewRatingRow extends StatelessWidget {
  const ReviewRatingRow({
    super.key,
    required this.label,
    required this.description,
    required this.onPressed,
  });

  final String label;
  final String description;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (mark, area) = switch (label) {
      'Again' => (Icons.replay_rounded, StudyArea.account),
      'Hard' => (Icons.fitness_center_rounded, StudyArea.progress),
      'Good' => (Icons.check_rounded, StudyArea.study),
      _ => (Icons.done_all_rounded, StudyArea.library),
    };
    final tone = context.studyTone(area);
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: tone.ink,
        backgroundColor: tone.fill,
        side: BorderSide(color: tone.accent),
        minimumSize: const Size(48, 64),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        alignment: Alignment.centerLeft,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: onPressed,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final title = Text(
            label,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: onPressed == null ? theme.disabledColor : tone.ink,
            ),
          );
          final detail = Text(
            description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: onPressed == null ? theme.disabledColor : tone.ink,
            ),
          );
          final compact =
              constraints.maxWidth < 320 ||
              MediaQuery.textScalerOf(context).scale(16) > 22;
          final copy =
              compact
                  ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [title, const SizedBox(height: 4), detail],
                  )
                  : Row(
                    children: [
                      Expanded(child: title),
                      const SizedBox(width: 12),
                      Flexible(child: detail),
                    ],
                  );
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ExcludeSemantics(
                child: Icon(
                  mark,
                  color: onPressed == null ? theme.disabledColor : tone.ink,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(child: copy),
            ],
          );
        },
      ),
    );
  }
}
