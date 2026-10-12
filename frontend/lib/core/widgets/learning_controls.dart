import 'package:flutter/material.dart';

/// Shared controls keep the navigation preview aligned with the real app.
class LearningAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  const LearningAction({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
  });
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onPressed,
    icon: Icon(icon),
    label: Text(label, textAlign: TextAlign.center),
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(48, 64),
      padding: const EdgeInsets.all(16),
    ),
  );
}

InputDecoration learningInputDecoration(String label, {String? helperText}) =>
    InputDecoration(
      labelText: label,
      helperText: helperText,
      helperMaxLines: 3,
    );

class PublicVisibilityControl extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  const PublicVisibilityControl({
    super.key,
    required this.value,
    this.onChanged,
  });
  @override
  Widget build(BuildContext context) => SwitchListTile.adaptive(
    contentPadding: EdgeInsets.zero,
    title: const Text('Make this deck public'),
    subtitle: const Text(
      'Other learners can find it after sync and add their own editable copy.',
    ),
    value: value,
    onChanged: onChanged,
  );
}

class DailyReviewLimitTile extends StatelessWidget {
  final int limit;
  final VoidCallback? onTap;
  const DailyReviewLimitTile({super.key, required this.limit, this.onTap});
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: const Icon(Icons.today_outlined),
    title: const Text('Daily review limit'),
    subtitle: Text(
      '$limit cards per day. Review all cards overrides this limit.',
    ),
    trailing: const Icon(Icons.edit_outlined),
    onTap: onTap,
  );
}

class AnalyticsRangeControl extends StatelessWidget {
  final int currentValue;
  final ValueChanged<int> onChanged;
  const AnalyticsRangeControl({
    super.key,
    required this.currentValue,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 10,
    runSpacing: 8,
    children: [
      for (final value in const [7, 30, 90])
        ChoiceChip(
          label: Text('$value days'),
          selected: currentValue == value,
          onSelected: (_) => onChanged(value),
        ),
    ],
  );
}
