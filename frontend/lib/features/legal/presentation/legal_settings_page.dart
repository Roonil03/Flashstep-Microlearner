import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../app/router.dart';
import '../../settings/presentation/account_sections.dart';
import 'open_source_licenses_page.dart';

class LegalSettingsPage extends StatelessWidget {
  const LegalSettingsPage({super.key});

  static bool _licensesRegistered = false;

  static void _registerProjectLicenses() {
    if (_licensesRegistered) return;
    _licensesRegistered = true;
    LicenseRegistry.addLicense(() async* {
      final project = await rootBundle.loadString(
        'assets/legal/project_license.txt',
      );
      yield LicenseEntryWithLineBreaks(const [
        'Flashstep Microlearner',
      ], project);

      final artwork = await rootBundle.loadString(
        'assets/legal/artwork_license.txt',
      );
      yield LicenseEntryWithLineBreaks(
        const ['Flashstep logo and image variants — Roonil03'],
        'Creator: Roonil03\n'
        'License: Creative Commons Attribution-ShareAlike 4.0 International\n'
        'Source: https://github.com/Roonil03/Flashstep-Microlearner/tree/main/frontend/assets\n'
        'Asset license: https://github.com/Roonil03/Flashstep-Microlearner/blob/main/frontend/assets/LICENSE\n'
        'License URL: https://creativecommons.org/licenses/by-sa/4.0/\n\n'
        '$artwork',
      );

      final raw = await rootBundle.loadString(
        'assets/legal/backend_licenses.json',
      );
      final modules = jsonDecode(raw) as List<dynamic>;
      for (final item in modules) {
        final module = item as Map<String, dynamic>;
        yield LicenseEntryWithLineBreaks([
          '${module['module']} ${module['version']} (Go backend)',
        ], module['license'] as String);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Legal')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const AccountSectionHeader(
                  title: 'Policies & licenses',
                  icon: Icons.description_outlined,
                ),
                const SizedBox(height: 20),
                AccountSettingsRow(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy Policy',
                  subtitle: 'Current information placeholder',
                  onTap:
                      () => Navigator.of(
                        context,
                      ).pushNamed(AppRoutes.privacyPolicy),
                ),
                const Divider(height: 1),
                AccountSettingsRow(
                  icon: Icons.description_outlined,
                  title: 'Terms of Service',
                  subtitle: 'Current information placeholder',
                  onTap:
                      () => Navigator.of(
                        context,
                      ).pushNamed(AppRoutes.termsOfService),
                ),
                const Divider(height: 1),
                AccountSettingsRow(
                  icon: Icons.code_outlined,
                  title: 'Open-source licenses',
                  onTap: () {
                    _registerProjectLicenses();
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const OpenSourceLicensesPage(),
                      ),
                    );
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
