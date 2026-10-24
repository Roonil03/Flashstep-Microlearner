import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../app/app_version.dart';
import '../../../app/router.dart';

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
        'Source: https://github.com/Roonil03/Flashstep-Microlearner/tree/v1.2.0/frontend/assets\n'
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
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('Privacy Policy'),
              subtitle: const Text('Current information placeholder'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap:
                  () =>
                      Navigator.of(context).pushNamed(AppRoutes.privacyPolicy),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('Terms of Service'),
              subtitle: const Text('Current information placeholder'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap:
                  () =>
                      Navigator.of(context).pushNamed(AppRoutes.termsOfService),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.code_outlined),
              title: const Text('Open-source licenses'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                _registerProjectLicenses();
                showLicensePage(
                  context: context,
                  applicationName: 'Flashstep Microlearner',
                  applicationVersion: AppVersion.name,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
