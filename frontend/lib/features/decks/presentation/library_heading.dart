import 'package:flutter/material.dart';
import '../../../app/theme/study_colors.dart';

/// A paper-backed heading for the library and its editing tools.
class LibraryHeading extends StatelessWidget {
  final String title;
  final String description;
  final String? count;
  final Widget? action;
  const LibraryHeading({
    super.key,
    required this.title,
    required this.description,
    this.count,
    this.action,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = context.studyTone(StudyArea.library);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: tone.fill,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              style: theme.textTheme.headlineMedium?.copyWith(
                color: tone.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: theme.textTheme.bodyMedium?.copyWith(color: tone.ink),
          ),
          if (count != null || action != null) ...[
            const SizedBox(height: 20),
            Wrap(
              spacing: 20,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (count != null)
                  Text(
                    count!,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: tone.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                if (action != null) action!,
              ],
            ),
          ],
        ],
      ),
    );
  }
}
