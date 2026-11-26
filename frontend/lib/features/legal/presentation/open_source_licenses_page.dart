import 'package:flutter/foundation.dart'
    show LicenseEntry, LicenseParagraph, LicenseRegistry;
import 'package:flutter/material.dart';

import '../../../app/app_version.dart';

class OpenSourceLicensesPage extends StatefulWidget {
  const OpenSourceLicensesPage({super.key});

  @override
  State<OpenSourceLicensesPage> createState() => _OpenSourceLicensesPageState();
}

class _OpenSourceLicensesPageState extends State<OpenSourceLicensesPage> {
  late Future<List<_LicensePackage>> _packages;

  @override
  void initState() {
    super.initState();
    _packages = _loadPackages();
  }

  Future<List<_LicensePackage>> _loadPackages() async {
    final entries = await LicenseRegistry.licenses.toList();
    final grouped = <String, List<LicenseEntry>>{};
    for (final entry in entries) {
      for (final package in entry.packages) {
        grouped.putIfAbsent(package, () => []).add(entry);
      }
    }
    if (grouped.isEmpty) return const [];

    final packages =
        grouped.entries
            .map((entry) => _LicensePackage(entry.key, entry.value))
            .toList();
    packages.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return packages;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Licenses')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: FutureBuilder<List<_LicensePackage>>(
              future: _packages,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Open-source licenses could not be loaded.',
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed:
                                () =>
                                    setState(() => _packages = _loadPackages()),
                            child: const Text('Try again'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final packages = snapshot.data!;
                return Scrollbar(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                    children: [
                      Text(
                        'Flashstep Microlearner',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Version ${AppVersion.name}',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Powered by Flutter and Go',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 24),
                      if (packages.isEmpty)
                        const Text(
                          'No open-source license notices are available.',
                        ),
                      for (final package in packages)
                        ListTile(
                          title: Text(package.name),
                          subtitle: Text(
                            '${package.entries.length} ${package.entries.length == 1 ? 'license notice' : 'license notices'}',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap:
                              () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder:
                                      (_) =>
                                          _LicenseDetailPage(package: package),
                                ),
                              ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _LicensePackage {
  const _LicensePackage(this.name, this.entries);

  final String name;
  final List<LicenseEntry> entries;
}

class _LicenseDetailPage extends StatefulWidget {
  const _LicenseDetailPage({required this.package});

  final _LicensePackage package;

  @override
  State<_LicenseDetailPage> createState() => _LicenseDetailPageState();
}

class _LicenseDetailPageState extends State<_LicenseDetailPage> {
  late final Future<List<LicenseParagraph?>> _noticeRows;

  @override
  void initState() {
    super.initState();
    _noticeRows = _loadNoticeRows();
  }

  Future<List<LicenseParagraph?>> _loadNoticeRows() async {
    final rows = <LicenseParagraph?>[];
    for (final entry in widget.package.entries) {
      if (rows.isNotEmpty) rows.add(null);
      rows.addAll(entry.paragraphs);
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.package.name)),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: FutureBuilder<List<LicenseParagraph?>>(
              future: _noticeRows,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'This license notice could not be displayed.',
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final rows = snapshot.data!;
                return Scrollbar(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                    itemCount: rows.length,
                    itemBuilder: (context, index) {
                      final paragraph = rows[index];
                      if (paragraph == null) return const Divider(height: 32);
                      final centered =
                          paragraph.indent == LicenseParagraph.centeredIndent;
                      return Padding(
                        padding: EdgeInsetsDirectional.only(
                          top: 8,
                          start: centered ? 0 : 16.0 * paragraph.indent,
                        ),
                        child: SelectableText(
                          paragraph.text,
                          textAlign:
                              centered ? TextAlign.center : TextAlign.start,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.45,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
