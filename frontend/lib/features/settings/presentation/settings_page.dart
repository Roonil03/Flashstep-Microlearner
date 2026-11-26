import '../../../core/network/api_errors.dart';
import '../../auth/data/auth_api.dart';
import '../../../app/app_version.dart';
import '../../onboarding/presentation/navigation_tour_launcher.dart';
import '../../../core/widgets/learning_controls.dart';
import '../../../core/widgets/image_decode_size.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/cupertino.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/theme/study_colors.dart';
import 'account_sections.dart';
import '../../../core/network/providers.dart';
import '../../../core/storage/session_storage.dart';
import '../../../core/storage/theme_storage.dart';

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_messageFromError(e))));
      return;
    }

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Signed out successfully')));

    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
  }

  void _goBack() {
    setState(() {
      _view = _SettingsView.main;
    });
  }

  @override
  Widget build(BuildContext context) {
    final Widget view;
    switch (_view) {
      case _SettingsView.account:
        view = _AccountSettings(onBack: _goBack);
        break;
      case _SettingsView.system:
        view = _SystemSettings(onBack: _goBack);
        break;
      case _SettingsView.main:
        view = _MainSettings(
          onAccountTap: () => setState(() => _view = _SettingsView.account),
          onSystemTap: () => setState(() => _view = _SettingsView.system),
          onLogout: _logout,
          onReplayTour:
              () => launchNavigationTour(
                context,
                ref.read(sessionStorageProvider),
                replay: true,
              ),
        );
        break;
    }
    return PopScope(
      canPop: _view == _SettingsView.main,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _view != _SettingsView.main) _goBack();
      },
      child: view,
    );
  }
}

class _MainSettings extends ConsumerStatefulWidget {
  final VoidCallback onAccountTap;
  final VoidCallback onSystemTap;
  final VoidCallback onLogout;
  final VoidCallback onReplayTour;

  const _MainSettings({
    required this.onAccountTap,
    required this.onSystemTap,
    required this.onLogout,
    required this.onReplayTour,
  });

  @override
  ConsumerState<_MainSettings> createState() => _MainSettingsState();
}

class _MainSettingsState extends ConsumerState<_MainSettings> {
  late final _username = ref.read(sessionStorageProvider).readUsername();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    Widget entry(
      String title,
      String subtitle,
      IconData icon,
      VoidCallback open,
    ) {
      return ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 4),
        leading: Icon(icon, color: colors.onSurfaceVariant),
        title: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded, size: 20),
        onTap: open,
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                FutureBuilder<String?>(
                  future: _username,
                  builder:
                      (context, snapshot) => _ProfileSettingsEntry(
                        name: snapshot.data?.trim() ?? '',
                        onTap: widget.onAccountTap,
                      ),
                ),
                const SizedBox(height: 18),
                entry(
                  'System Settings',
                  'Theme, font size and daily review limits',
                  Icons.tune_rounded,
                  widget.onSystemTap,
                ),
                const SizedBox(height: 18),
                Semantics(
                  header: true,
                  child: Text(
                    'Help & information',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.5,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Divider(height: 1),
                entry(
                  'Relearn app navigation',
                  'Replay the nine-step guide',
                  Icons.route_outlined,
                  widget.onReplayTour,
                ),
                const Divider(height: 1),
                entry(
                  'Legal',
                  'Privacy, terms and licenses',
                  Icons.gavel_outlined,
                  () => Navigator.of(context).pushNamed(AppRoutes.legal),
                ),
                const Divider(height: 1),
                entry(
                  'Report a Bug',
                  'Submit a public GitHub issue',
                  Icons.bug_report_outlined,
                  () => Navigator.of(context).pushNamed(AppRoutes.bugReport),
                ),
                const Divider(height: 1),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  children: [
                    TextButton.icon(
                      onPressed: widget.onLogout,
                      icon: const Icon(Icons.logout),
                      label: const Text('Sign Out'),
                    ),
                    Text(
                      'Version ${AppVersion.name}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileSettingsEntry extends StatelessWidget {
  final String name;
  final VoidCallback onTap;

  const _ProfileSettingsEntry({required this.name, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final sheet = dark ? const Color(0xFF603329) : const Color(0xFFFFC6A1);
    final lettering = dark ? const Color(0xFFFFE9D7) : const Color(0xFF402419);
    final avatar =
        name.isEmpty
            ? Icon(Icons.person_outline, color: sheet)
            : Padding(
              padding: const EdgeInsets.all(4),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  name.characters.first.toUpperCase(),
                  style: TextStyle(
                    color: sheet,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            );

    return Semantics(
      button: true,
      label: name.isEmpty ? 'Account Settings' : 'Account Settings, $name',
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: sheet,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          excludeFromSemantics: true,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: lettering,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: SizedBox(
                    width: 48,
                    height: 58,
                    child: Center(child: avatar),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Account Settings',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: lettering,
                        ),
                      ),
                      if (name.isNotEmpty)
                        Text(
                          name,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: lettering,
                            height: 1.2,
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: lettering),
              ],
            ),
          ),
        ),
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
    return error is AuthApiException
        ? error.message
        : networkErrorMessage(error);
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
                await ref
                    .read(authRepositoryProvider)
                    .changePassword(
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
                            color: Theme.of(context).colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                          child: Text(
                            errorText!,
                            style: TextStyle(
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.onErrorContainer,
                            ),
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
                            tooltip:
                                obscureOld
                                    ? 'Show current password'
                                    : 'Hide current password',
                            onPressed:
                                isSubmitting
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
                            tooltip:
                                obscureNew
                                    ? 'Show new password'
                                    : 'Hide new password',
                            onPressed:
                                isSubmitting
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
                            tooltip:
                                obscureConfirm
                                    ? 'Show confirmation password'
                                    : 'Hide confirmation password',
                            onPressed:
                                isSubmitting
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
                    onPressed:
                        isSubmitting
                            ? null
                            : () => Navigator.of(dialogContext).pop(false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: isSubmitting ? null : submit,
                    child:
                        isSubmitting
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

  Future<void> _showChangeUsernameDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        final usernameController = TextEditingController();

        bool isSubmitting = false;
        String? errorText;

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            Future<void> submit() async {
              if (isSubmitting) return;

              final username = usernameController.text.trim();

              if (username.isEmpty) {
                setStateDialog(() {
                  errorText = 'Username is required.';
                });
                return;
              }

              final usernameLength = username.toLowerCase().runes.length;
              if (usernameLength < 3 || usernameLength > 50) {
                setStateDialog(() {
                  errorText = 'Use 3 to 50 characters.';
                });
                return;
              }

              setStateDialog(() {
                isSubmitting = true;
                errorText = null;
              });

              try {
                await ref
                    .read(authRepositoryProvider)
                    .changeUsername(username: username);

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
                title: const Text('Change Username'),
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
                            color: Theme.of(context).colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                          child: Text(
                            errorText!,
                            style: TextStyle(
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                      TextField(
                        controller: usernameController,
                        enabled: !isSubmitting,
                        decoration: const InputDecoration(
                          labelText: 'New Username',
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed:
                        isSubmitting
                            ? null
                            : () => Navigator.of(dialogContext).pop(false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: isSubmitting ? null : submit,
                    child:
                        isSubmitting
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
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username updated successfully')),
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
                            color: Theme.of(context).colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                          child: Text(
                            errorText!,
                            style: TextStyle(
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.onErrorContainer,
                            ),
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
                    onPressed:
                        isDeleting
                            ? null
                            : () => Navigator.of(dialogContext).pop(false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                      foregroundColor: Theme.of(context).colorScheme.onError,
                    ),
                    onPressed: isDeleting ? null : submit,
                    child:
                        isDeleting
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

      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back to Settings',
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
        title: const Text('Account Settings'),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 28),
                  child: Opacity(
                    opacity: 0.35,
                    child: Image.asset(
                      'assets/LogoWithText_WithoutBG.png',
                      width: 320,
                      cacheWidth: imageDecodeSize(
                        logicalSize: 320,
                        devicePixelRatio: MediaQuery.devicePixelRatioOf(
                          context,
                        ),
                        sourceSize: 1056,
                      ),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  children: [
                    FutureBuilder<String?>(
                      future: ref.read(sessionStorageProvider).readUsername(),
                      builder:
                          (context, snapshot) => AccountSectionHeader(
                            title:
                                snapshot.data?.isNotEmpty == true
                                    ? snapshot.data!
                                    : 'Your account',
                            icon: Icons.person_outline_rounded,
                          ),
                    ),
                    const SizedBox(height: 20),
                    _sectionCard(
                      context,
                      children: [
                        AccountSettingsRow(
                          title: 'Change Username',
                          subtitle: 'Update the name on your account',
                          icon: Icons.person_outline,
                          onTap: _showChangeUsernameDialog,
                        ),
                        const Divider(height: 1, indent: 70, endIndent: 16),
                        AccountSettingsRow(
                          title: 'Change Password',
                          subtitle: 'Choose a new sign-in password',
                          icon: Icons.lock_outline,
                          onTap: _showChangePasswordDialog,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _sectionCard(
                      context,
                      children: [
                        AccountSettingsRow(
                          title: 'Delete Account',
                          subtitle: 'Permanently remove your account',
                          icon: Icons.delete_outline,
                          destructive: true,
                          onTap: _showDeleteAccountDialog,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SystemSettings extends ConsumerStatefulWidget {
  final VoidCallback onBack;

  const _SystemSettings({required this.onBack});

  @override
  ConsumerState<_SystemSettings> createState() => _SystemSettingsState();
}

class _SystemSettingsState extends ConsumerState<_SystemSettings> {
  static const _storage = SessionStorage();
  late Future<int> _dailyLimitFuture;
  late Future<bool> _selectiveDecksOnlyFuture;
  late Future<bool> _bypassSrsFuture;

  @override
  void initState() {
    super.initState();
    _dailyLimitFuture = _storage.readDailyReviewLimit();
    _selectiveDecksOnlyFuture = _storage.readSelectiveReviewDecksOnly();
    _bypassSrsFuture = _storage.readBypassSrs();
  }

  Future<void> _showDailyReviewLimitDialog() async {
    final currentLimit = await _storage.readDailyReviewLimit();
    if (!mounted) {
      return;
    }
    int selectedLimit = currentLimit.clamp(1, 500);
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 8,
                  bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily review limit',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Limits different cards reviewed each day (UTC) with selective review on. Review all cards overrides this limit.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        '$selectedLimit cards per day',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 220,
                      child: CupertinoPicker(
                        scrollController: FixedExtentScrollController(
                          initialItem: selectedLimit - 1,
                        ),
                        itemExtent: 40,
                        useMagnifier: true,
                        magnification: 1.08,
                        onSelectedItemChanged: (value) {
                          setSheetState(() {
                            selectedLimit = value + 1;
                          });
                        },
                        children: List<Widget>.generate(
                          500,
                          (index) => Center(
                            child: Text(
                              '${index + 1}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed:
                                () => Navigator.of(sheetContext).pop(false),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () async {
                              await _storage.writeDailyReviewLimit(
                                selectedLimit,
                              );
                              if (!sheetContext.mounted) return;
                              Navigator.of(sheetContext).pop(true);
                            },
                            child: const Text('Save'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (saved == true && mounted) {
      setState(() {
        _dailyLimitFuture = _storage.readDailyReviewLimit();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Daily review limit updated')),
      );
    }
  }

  Future<void> _toggleSelectiveDecksOnly(bool value) async {
    await _storage.writeSelectiveReviewDecksOnly(value);

    if (!mounted) return;

    setState(() {
      _selectiveDecksOnlyFuture = Future<bool>.value(value);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          value
              ? 'Selective review on. Daily limit applies unless Review all cards is on.'
              : 'Selective review off. Daily limit does not apply.',
        ),
      ),
    );
  }

  Future<void> _toggleBypassSrs(bool value) async {
    await _storage.writeBypassSrs(value);

    if (!mounted) return;

    setState(() {
      _bypassSrsFuture = Future<bool>.value(value);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          value
              ? 'Review includes all cards, ignoring daily limits and due dates.'
              : 'Review uses due dates; selective review controls the daily limit.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeMode = ref.watch(appThemeModeProvider);
    final fontSize = ref.watch(appFontSizeProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back to Settings',
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
        title: const Text('System Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AccountSectionHeader(
                  title: 'Study preferences',
                  subtitle: 'Appearance and review preferences',
                  icon: Icons.tune_rounded,
                ),
                const SizedBox(height: 20),
                _sectionCard(
                  context,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Semantics(
                            header: true,
                            child: Text(
                              'Appearance',
                              style: theme.textTheme.titleLarge,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text('App theme', style: theme.textTheme.titleMedium),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              for (final (mode, label) in [
                                (ThemeMode.system, 'System'),
                                (ThemeMode.light, 'Light'),
                                (ThemeMode.dark, 'Dark'),
                              ])
                                ChoiceChip(
                                  label: Text(label),
                                  selected: themeMode == mode,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.padded,
                                  onSelected:
                                      (_) => ref
                                          .read(appThemeModeProvider.notifier)
                                          .setTheme(mode),
                                ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text('Font size', style: theme.textTheme.titleMedium),
                          const SizedBox(height: 4),
                          Text(
                            'Adjusts text throughout the app relative to your device setting.',
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: 8),
                          Semantics(
                            label: 'Font size: ${_fontSizeLabel(fontSize)}',
                            value: _fontSizeLabel(fontSize),
                            child: Slider(
                              min: 0,
                              max: (AppFontSize.values.length - 1).toDouble(),
                              divisions: AppFontSize.values.length - 1,
                              value: fontSize.index.toDouble(),
                              label: _fontSizeLabel(fontSize),
                              semanticFormatterCallback:
                                  (value) => _fontSizeLabel(
                                    AppFontSize.values[value.round()],
                                  ),
                              onChanged: (value) {
                                final next =
                                    AppFontSize.values[value.round().clamp(
                                      0,
                                      AppFontSize.values.length - 1,
                                    )];
                                ref
                                    .read(appFontSizeProvider.notifier)
                                    .setSize(next);
                              },
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              for (final size in AppFontSize.values)
                                Expanded(
                                  child: Text(
                                    _fontSizeLabel(size),
                                    textAlign:
                                        size == AppFontSize.small
                                            ? TextAlign.left
                                            : size == AppFontSize.extraLarge
                                            ? TextAlign.right
                                            : TextAlign.center,
                                    style: theme.textTheme.labelSmall,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _sectionCard(
                  context,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Semantics(
                          header: true,
                          child: Text(
                            'Review',
                            style: theme.textTheme.titleLarge,
                          ),
                        ),
                      ),
                    ),
                    FutureBuilder<int>(
                      future: _dailyLimitFuture,
                      builder:
                          (context, snapshot) => DailyReviewLimitTile(
                            limit: snapshot.data ?? 25,
                            onTap: _showDailyReviewLimitDialog,
                          ),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    FutureBuilder<bool>(
                      future: _selectiveDecksOnlyFuture,
                      builder: (context, snapshot) {
                        final value = snapshot.data ?? true;
                        return SwitchListTile.adaptive(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          secondary: const Icon(Icons.tune_outlined),
                          title: const Text('Use selective review decks'),
                          subtitle: Text(
                            value
                                ? 'Applies your daily limit to due cards, starting with recently updated decks. Review all cards overrides this.'
                                : 'Shows all due cards with no daily limit. Review all cards also includes cards not yet due.',
                          ),
                          value: value,
                          onChanged: _toggleSelectiveDecksOnly,
                        );
                      },
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    FutureBuilder<bool>(
                      future: _bypassSrsFuture,
                      builder: (context, snapshot) {
                        final value = snapshot.data ?? false;
                        return SwitchListTile.adaptive(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          secondary: const Icon(Icons.all_inclusive_outlined),
                          title: const Text('Review all cards'),
                          subtitle: Text(
                            value
                                ? 'Includes cards not yet due and ignores the daily limit and selective review.'
                                : 'Uses due dates. The daily limit applies only when selective review is on.',
                          ),
                          value: value,
                          onChanged: _toggleBypassSrs,
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Widget _sectionCard(BuildContext context, {required List<Widget> children}) {
  final colors = Theme.of(context).colorScheme;
  final tone = context.studyTone(StudyArea.account);
  return Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      color: colors.surfaceContainerLowest,
      border: Border.all(color: tone.accent.withValues(alpha: .28)),
    ),
    child: Column(children: children),
  );
}

String _messageFromError(Object error) {
  return error is AuthApiException ? error.message : networkErrorMessage(error);
}

String _fontSizeLabel(AppFontSize size) => switch (size) {
  AppFontSize.small => 'Small',
  AppFontSize.device => 'Device default',
  AppFontSize.large => 'Large',
  AppFontSize.extraLarge => 'Extra large',
};
