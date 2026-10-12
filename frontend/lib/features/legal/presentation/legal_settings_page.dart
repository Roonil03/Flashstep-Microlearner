import 'package:flutter/material.dart';

import '../../../app/app_version.dart';
import '../../../app/router.dart';

class LegalSettingsPage extends StatelessWidget {
  const LegalSettingsPage({super.key});

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
              subtitle: const Text('Draft for attorney review'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap:
                  () =>
                      Navigator.of(context).pushNamed(AppRoutes.privacyPolicy),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('Terms of Service'),
              subtitle: const Text('Draft for attorney review'),
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
              onTap:
                  () => showLicensePage(
                    context: context,
                    applicationName: 'Flashstep Microlearner',
                    applicationVersion: AppVersion.name,
                    applicationLegalese:
                        'Logo images and variants created by Roonil03. '
                        'Licensed under Creative Commons Attribution-ShareAlike 4.0 International. '
                        'Source: https://github.com/Roonil03/Flashstep-Microlearner/tree/v1.1.0/frontend/assets. '
                        'License: https://creativecommons.org/licenses/by-sa/4.0/',
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
