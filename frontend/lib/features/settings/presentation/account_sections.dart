import 'package:flutter/material.dart';

import '../../../app/theme/study_colors.dart';

class AccountSectionHeader extends StatelessWidget {
  const AccountSectionHeader({
    super.key,
    required this.title,
    required this.icon,
    this.subtitle,
  });

  final String title;
  final IconData icon;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final tone = context.studyTone(StudyArea.account);
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tone.fill,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: tone.accent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color:
                  theme.brightness == Brightness.dark
                      ? const Color(0xFF311B22)
                      : Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: tone.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: tone.ink,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AccountSettingsRow extends StatelessWidget {
  const AccountSettingsRow({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
    this.subtitle,
    this.destructive = false,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final tone = context.studyTone(StudyArea.account);
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: destructive ? colors.errorContainer : tone.fill,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: destructive ? colors.onErrorContainer : tone.ink,
          size: 22,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: destructive ? colors.error : null,
        ),
      ),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
