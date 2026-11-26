import 'package:flutter/material.dart';

import '../../../app/theme/study_colors.dart';

/// The same question and answer sheets appear in the tour and real review.
class NotebookCard extends StatelessWidget {
  const NotebookCard({
    super.key,
    required this.heading,
    required this.text,
    this.answer = false,
  });

  final String heading;
  final String text;
  final bool answer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = context.studyTone(
      answer ? StudyArea.library : StudyArea.study,
    );
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: answer ? tone.fill : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tone.accent, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: tone.fill,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  answer ? Icons.task_alt : Icons.edit_note,
                  color: tone.ink,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    heading,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: tone.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Text(
              text,
              style: (answer
                      ? theme.textTheme.titleLarge
                      : theme.textTheme.headlineSmall)
                  ?.copyWith(
                    color: answer ? tone.ink : theme.colorScheme.onSurface,
                    fontWeight: answer ? FontWeight.w500 : FontWeight.w700,
                    height: 1.5,
                  ),
            ),
          ),
          if (!answer)
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
              child: Row(
                children: List.generate(
                  3,
                  (index) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Container(height: 2, color: tone.fill),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
