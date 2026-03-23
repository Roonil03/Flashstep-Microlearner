import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/network/providers.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

enum _SettingsView { main, account, system }

class _SettingsPageState extends ConsumerState<SettingsPage> {
  _SettingsView _view = _SettingsView.main;

  Future<void> _logout() async {
    try {
      await ref.read(authRepositoryProvider).logout();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_messageFromError(e))),
      );
      return;
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Signed out successfully')),
    );

    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.login,
      (route) => false,
    );
  }

  void _goBack() {
    setState(() {
      _view = _SettingsView.main;
    });
  }

  @override
  Widget build(BuildContext context) {
    switch (_view) {
      case _SettingsView.account:
        return _AccountSettings(onBack: _goBack);
      case _SettingsView.system:
        return _SystemSettings(onBack: _goBack);
      case _SettingsView.main:
        return _MainSettings(
          onAccountTap: () => setState(() => _view = _SettingsView.account),
          onSystemTap: () => setState(() => _view = _SettingsView.system),
          onLogout: _logout,
        );
    }
  }
}

class _MainSettings extends StatelessWidget {
  final VoidCallback onAccountTap;
  final VoidCallback onSystemTap;
  final VoidCallback onLogout;

  const _MainSettings({
    required this.onAccountTap,
    required this.onSystemTap,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionCard(
            isDark,
            children: [
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Account Settings'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: onAccountTap,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.settings_suggest_outlined),
                title: const Text('System Settings'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: onSystemTap,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Column(
            children: [
              Image.asset(
                'assets/LogoWithText_WithoutBG.png',
                height: 80,
              ),
              const SizedBox(height: 8),
              Text(
                'Flashstep Microlearner',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Version 0.1.0 (Beta Build 1)',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: onLogout,
              icon: const Icon(Icons.logout),
              label: const Text('Sign Out'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark
                    ? Colors.red.shade400
                    : Colors.red.shade700,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountSettings extends ConsumerStatefulWidget {
  final VoidCallback onBack;

  const _AccountSettings({required this.onBack});

  @override
  ConsumerState<_AccountSettings> createState() => _AccountSettingsState();
}

class _AccountSettingsState extends ConsumerState<_AccountSettings> {
  String _messageFromError(Object error) {
    final text = error.toString();
    return text
        .replaceFirst('Exception: ', '')
        .replaceFirst('StateError: ', '')
        .trim();
  }

  Future<void> _showChangePasswordDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        final oldPasswordController = TextEditingController();
        final newPasswordController = TextEditingController();
        final confirmPasswordController = TextEditingController();

        bool isSubmitting = false;
        bool obscureOld = true;
        bool obscureNew = true;
        bool obscureConfirm = true;
        String? errorText;

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            Future<void> submit() async {
              if (isSubmitting) return;

              final oldPassword = oldPasswordController.text.trim();
              final newPassword = newPasswordController.text.trim();
              final confirmPassword = confirmPasswordController.text.trim();

              if (oldPassword.isEmpty ||
                  newPassword.isEmpty ||
                  confirmPassword.isEmpty) {
                setStateDialog(() {
                  errorText = 'All fields are required.';
                });
                return;
              }

              if (newPassword.length < 8) {
                setStateDialog(() {
                  errorText = 'New password must be at least 8 characters.';
                });
                return;
              }

              if (newPassword != confirmPassword) {
                setStateDialog(() {
                  errorText = 'New passwords do not match.';
                });
                return;
              }

              setStateDialog(() {
                isSubmitting = true;
                errorText = null;
              });

              try {
                await ref.read(authRepositoryProvider).changePassword(
                      oldPassword: oldPassword,
                      newPassword: newPassword,
                    );

                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop(true);
              } catch (e) {
                if (!dialogContext.mounted) return;
                setStateDialog(() {
                  errorText = _messageFromError(e);
                  isSubmitting = false;
                });
              }
            }

            return PopScope(
              canPop: !isSubmitting,
              child: AlertDialog(
                title: const Text('Change Password'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (errorText != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.red.withOpacity(0.2),
                            ),
                          ),
                          child: Text(
                            errorText!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                      TextField(
                        controller: oldPasswordController,
                        obscureText: obscureOld,
                        enabled: !isSubmitting,
                        decoration: InputDecoration(
                          labelText: 'Current Password',
                          suffixIcon: IconButton(
                            onPressed: isSubmitting
                                ? null
                                : () {
                                    setStateDialog(() {
                                      obscureOld = !obscureOld;
                                    });
                                  },
                            icon: Icon(
                              obscureOld
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: newPasswordController,
                        obscureText: obscureNew,
                        enabled: !isSubmitting,
                        decoration: InputDecoration(
                          labelText: 'New Password',
                          suffixIcon: IconButton(
                            onPressed: isSubmitting
                                ? null
                                : () {
                                    setStateDialog(() {
                                      obscureNew = !obscureNew;
                                    });
                                  },
                            icon: Icon(
                              obscureNew
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: confirmPasswordController,
                        obscureText: obscureConfirm,
                        enabled: !isSubmitting,
                        decoration: InputDecoration(
                          labelText: 'Confirm New Password',
                          suffixIcon: IconButton(
                            onPressed: isSubmitting
                                ? null
                                : () {
                                    setStateDialog(() {
                                      obscureConfirm = !obscureConfirm;
                                    });
                                  },
                            icon: Icon(
                              obscureConfirm
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: isSubmitting
                        ? null
                        : () => Navigator.of(dialogContext).pop(false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: isSubmitting ? null : submit,
                    child: isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Update'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (!mounted) return;

    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated successfully')),
      );
    }
  }

  Future<void> _showDeleteAccountDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        final confirmController = TextEditingController();

        bool isDeleting = false;
        String? errorText;

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            Future<void> submit() async {
              if (isDeleting) return;

              final confirmation = confirmController.text.trim().toUpperCase();

              if (confirmation != 'DELETE') {
                setStateDialog(() {
                  errorText = 'Type DELETE to confirm.';
                });
                return;
              }

              setStateDialog(() {
                isDeleting = true;
                errorText = null;
              });

              try {
                await ref.read(authRepositoryProvider).deleteAccount();

                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop(true);
              } catch (e) {
                if (!dialogContext.mounted) return;
                setStateDialog(() {
                  errorText = _messageFromError(e);
                  isDeleting = false;
                });
              }
            }

            return PopScope(
              canPop: !isDeleting,
              child: AlertDialog(
                title: const Text('Delete Account'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'This action permanently deletes your account. '
                        'All account data will be removed from the server.',
                      ),
                      const SizedBox(height: 16),
                      if (errorText != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.red.withOpacity(0.2),
                            ),
                          ),
                          child: Text(
                            errorText!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                      TextField(
                        controller: confirmController,
                        enabled: !isDeleting,
                        decoration: const InputDecoration(
                          labelText: 'Type DELETE to confirm',
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: isDeleting
                        ? null
                        : () => Navigator.of(dialogContext).pop(false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: isDeleting ? null : submit,
                    child: isDeleting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Delete'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (!mounted) return;

    if (result == true) {
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        const SnackBar(content: Text('Account deleted successfully')),
      );

      await Future.delayed(const Duration(milliseconds: 250));

      if (!mounted) return;

      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.login,
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
        title: const Text('Account Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Align(
          alignment: Alignment.topCenter,
          child: _sectionCard(
            isDark,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                child: Text(
                  'Account',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ListTile(
                dense: true,
                leading: const Icon(Icons.lock_outline),
                title: const Text('Change Password'),
                onTap: _showChangePasswordDialog,
              ),
              const Divider(height: 1),
              ListTile(
                dense: true,
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete Account'),
                onTap: _showDeleteAccountDialog,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SystemSettings extends ConsumerWidget {
  final VoidCallback onBack;

  const _SystemSettings({required this.onBack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themeMode = ref.watch(appThemeModeProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: onBack,
        ),
        title: const Text('System Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Align(
          alignment: Alignment.topLeft,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isDark
                  ? const Color(0xFF1A2D3D)
                  : const Color(0xFFF5F5F5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'App Theme',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                RadioListTile<ThemeMode>(
                  contentPadding: EdgeInsets.zero,
                  value: ThemeMode.light,
                  groupValue: themeMode,
                  title: const Text('Light Mode'),
                  onChanged: (value) {
                    ref.read(appThemeModeProvider.notifier).setTheme(value!);
                  },
                ),
                RadioListTile<ThemeMode>(
                  contentPadding: EdgeInsets.zero,
                  value: ThemeMode.dark,
                  groupValue: themeMode,
                  title: const Text('Dark Mode'),
                  onChanged: (value) {
                    ref.read(appThemeModeProvider.notifier).setTheme(value!);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Widget _sectionCard(bool isDark, {required List<Widget> children}) {
  return Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      color: isDark ? const Color(0xFF1A2D3D) : const Color(0xFFF5F5F5),
    ),
    child: Column(children: children),
  );
}

String _messageFromError(Object error) {
  final text = error.toString();
  return text
      .replaceFirst('Exception: ', '')
      .replaceFirst('StateError: ', '')
      .trim();
}