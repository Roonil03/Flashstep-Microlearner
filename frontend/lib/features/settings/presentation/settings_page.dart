import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/storage/session_storage.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

enum _SettingsView { main, account, system }

class _SettingsPageState extends ConsumerState<SettingsPage> {
  _SettingsView _view = _SettingsView.main;

  Future<void> _logout() async {
    const storage = SessionStorage();
    await storage.clearAll();

    if (!mounted) return;

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
      default:
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

class _AccountSettings extends StatelessWidget {
  final VoidCallback onBack;

  const _AccountSettings({required this.onBack});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: onBack,
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
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('API not implemented')),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                dense: true,
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete Account'),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('API not implemented')),
                  );
                },
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