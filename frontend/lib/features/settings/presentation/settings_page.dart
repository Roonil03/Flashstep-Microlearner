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
  final String? initialUsername;
  final ReviewPreferenceSnapshot? initialReviewPreferences;
  final VoidCallback? onUsernameSaved;
  final VoidCallback? onReviewPreferencesSaved;

  const SettingsPage({
    super.key,
    this.initialUsername,
    this.initialReviewPreferences,
    this.onUsernameSaved,
    this.onReviewPreferencesSaved,
  });

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

enum _SettingsView { main, account, system }

class _SettingsPageState extends ConsumerState<SettingsPage> {
  _SettingsView _view = _SettingsView.main;
  String _username = '';
  bool _usernameEdited = false;
  bool _usernameLoadFailed = false;
  late final _reviewPreferences = _ReviewPreferences(
    ref.read(sessionStorageProvider),
    initial: widget.initialReviewPreferences,
  );

  @override
  void initState() {
    super.initState();
    _username = widget.initialUsername?.trim() ?? '';
    if (widget.initialUsername == null) _loadUsername();
  }

  Future<void> _loadUsername() async {
    _usernameLoadFailed = false;
    try {
      final username = await ref.read(sessionStorageProvider).readUsername();
      if (!mounted || _usernameEdited) return;
      setState(() => _username = username?.trim() ?? '');
    } catch (_) {
      // Keep the same unnamed profile fallback when local storage is unavailable.
      _usernameLoadFailed = true;
    }
  }

  void _updateUsername(String username) {
    setState(() {
      _usernameEdited = true;
      _username = username;
    });
    widget.onUsernameSaved?.call();
  }

  void _reviewPreferencesSaved() {
    // A write may finish after its originating System view was replaced.
    if (mounted) setState(() {});
    widget.onReviewPreferencesSaved?.call();
  }

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
    if (_usernameLoadFailed && !_usernameEdited) _loadUsername();
    setState(() {
      _view = _SettingsView.main;
    });
  }

  @override
  Widget build(BuildContext context) {
    final Widget view;
    switch (_view) {
      case _SettingsView.account:
        view = _AccountSettings(
          onBack: _goBack,
          username: _username,
          onUsernameChanged: _updateUsername,
        );
        break;
      case _SettingsView.system:
        view = _SystemSettings(
          onBack: _goBack,
          preferences: _reviewPreferences,
          onPreferencesSaved: _reviewPreferencesSaved,
        );
        break;
      case _SettingsView.main:
        view = _MainSettings(
          username: _username,
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

class _MainSettings extends StatelessWidget {
  final String username;
  final VoidCallback onAccountTap;
  final VoidCallback onSystemTap;
  final VoidCallback onLogout;
  final VoidCallback onReplayTour;

  const _MainSettings({
    required this.username,
    required this.onAccountTap,
    required this.onSystemTap,
    required this.onLogout,
    required this.onReplayTour,
  });

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
                _ProfileSettingsEntry(name: username, onTap: onAccountTap),
                const SizedBox(height: 18),
                entry(
                  'System Settings',
                  'Theme, font size and daily review limits',
                  Icons.tune_rounded,
                  onSystemTap,
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
                  onReplayTour,
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
                      onPressed: onLogout,
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
  final String username;
  final ValueChanged<String> onUsernameChanged;

  const _AccountSettings({
    required this.onBack,
    required this.username,
    required this.onUsernameChanged,
  });

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
    final result = await showDialog<String>(
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
                Navigator.of(dialogContext).pop(username);
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
                            : () => Navigator.of(dialogContext).pop(),
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

    if (result != null) {
      widget.onUsernameChanged(result);
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
                    AccountSectionHeader(
                      title:
                          widget.username.isNotEmpty
                              ? widget.username
                              : 'Your account',
                      icon: Icons.person_outline_rounded,
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

// Route-local storage reads survive section switches without retaining hidden
// Scaffolds or rebuilding a waiting FutureBuilder on each return.
class _ReviewPreferences {
  final SessionStorage storage;
  int? dailyLimit;
  bool? selectiveDecksOnly;
  bool? bypassSrs;

  Future<int>? _dailyLimitFuture;
  Future<bool>? _selectiveDecksOnlyFuture;
  Future<bool>? _bypassSrsFuture;

  _ReviewPreferences(this.storage, {ReviewPreferenceSnapshot? initial})
    : dailyLimit = initial?.dailyLimit,
      selectiveDecksOnly = initial?.selectiveDecksOnly,
      bypassSrs = initial?.bypassSrs;

  Future<int> get dailyLimitFuture =>
      _dailyLimitFuture ??=
          dailyLimit != null
              ? Future<int>.value(dailyLimit)
              : storage.readDailyReviewLimit().then(
                (value) => dailyLimit ??= value,
                onError: (Object error, StackTrace stack) {
                  _dailyLimitFuture = null;
                  Error.throwWithStackTrace(error, stack);
                },
              );

  Future<bool> get selectiveDecksOnlyFuture =>
      _selectiveDecksOnlyFuture ??=
          selectiveDecksOnly != null
              ? Future<bool>.value(selectiveDecksOnly)
              : storage.readSelectiveReviewDecksOnly().then(
                (value) => selectiveDecksOnly ??= value,
                onError: (Object error, StackTrace stack) {
                  _selectiveDecksOnlyFuture = null;
                  Error.throwWithStackTrace(error, stack);
                },
              );

  Future<bool> get bypassSrsFuture =>
      _bypassSrsFuture ??=
          bypassSrs != null
              ? Future<bool>.value(bypassSrs)
              : storage.readBypassSrs().then(
                (value) => bypassSrs ??= value,
                onError: (Object error, StackTrace stack) {
                  _bypassSrsFuture = null;
                  Error.throwWithStackTrace(error, stack);
                },
              );

  void updateDailyLimit(int value) {
    dailyLimit = value;
    _dailyLimitFuture = Future<int>.value(value);
  }

  void updateSelectiveDecksOnly(bool value) {
    selectiveDecksOnly = value;
    _selectiveDecksOnlyFuture = Future<bool>.value(value);
  }

  void updateBypassSrs(bool value) {
    bypassSrs = value;
    _bypassSrsFuture = Future<bool>.value(value);
  }
}

class _SystemSettings extends ConsumerStatefulWidget {
  final VoidCallback onBack;
  final _ReviewPreferences preferences;
  final VoidCallback? onPreferencesSaved;

  const _SystemSettings({
    required this.onBack,
    required this.preferences,
    this.onPreferencesSaved,
  });

  @override
  ConsumerState<_SystemSettings> createState() => _SystemSettingsState();
}

class _SystemSettingsState extends ConsumerState<_SystemSettings> {
  _ReviewPreferences get _preferences => widget.preferences;

  Future<void> _showDailyReviewLimitDialog() async {
    final preferences = _preferences;
    final onSaved = widget.onPreferencesSaved;
    final currentLimit =
        preferences.dailyLimit ?? await preferences.dailyLimitFuture;
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
                              if (selectedLimit != currentLimit) {
                                await preferences.storage.writeDailyReviewLimit(
                                  selectedLimit,
                                );
                                preferences.updateDailyLimit(selectedLimit);
                                onSaved?.call();
                              }
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
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Daily review limit updated')),
      );
    }
  }

  Future<void> _toggleSelectiveDecksOnly(bool value) async {
    final preferences = _preferences;
    final onSaved = widget.onPreferencesSaved;
    if (value == preferences.selectiveDecksOnly) return;
    await preferences.storage.writeSelectiveReviewDecksOnly(value);
    preferences.updateSelectiveDecksOnly(value);
    onSaved?.call();

    if (!mounted) return;

    setState(() {});

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
    final preferences = _preferences;
    final onSaved = widget.onPreferencesSaved;
    if (value == preferences.bypassSrs) return;
    await preferences.storage.writeBypassSrs(value);
    preferences.updateBypassSrs(value);
    onSaved?.call();

    if (!mounted) return;

    setState(() {});

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
                      future: _preferences.dailyLimitFuture,
                      initialData: _preferences.dailyLimit,
                      builder:
                          (context, snapshot) => DailyReviewLimitTile(
                            limit:
                                _preferences.dailyLimit ?? snapshot.data ?? 25,
                            onTap: _showDailyReviewLimitDialog,
                          ),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    FutureBuilder<bool>(
                      future: _preferences.selectiveDecksOnlyFuture,
                      initialData: _preferences.selectiveDecksOnly,
                      builder: (context, snapshot) {
                        final value =
                            _preferences.selectiveDecksOnly ??
                            snapshot.data ??
                            true;
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
                      future: _preferences.bypassSrsFuture,
                      initialData: _preferences.bypassSrs,
                      builder: (context, snapshot) {
                        final value =
                            _preferences.bypassSrs ?? snapshot.data ?? false;
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
