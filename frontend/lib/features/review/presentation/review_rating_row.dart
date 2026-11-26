import 'package:flutter/material.dart';

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
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 64),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        alignment: Alignment.centerLeft,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: onPressed,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final title = Text(
            label,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: onPressed == null ? theme.disabledColor : null,
            ),
          );
          final detail = Text(
            description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color:
                  onPressed == null
                      ? theme.disabledColor
                      : theme.colorScheme.onSurfaceVariant,
            ),
          );
          if (constraints.maxWidth < 280 ||
              MediaQuery.textScalerOf(context).scale(16) > 22) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [title, const SizedBox(height: 4), detail],
            );
          }
          return Row(
            children: [
              Expanded(child: title),
              const SizedBox(width: 12),
              Flexible(child: detail),
            ],
          );
        },
      ),
    );
  }
}
