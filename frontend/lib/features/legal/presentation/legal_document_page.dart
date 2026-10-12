import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LegalDocumentPage extends StatefulWidget {
  const LegalDocumentPage.privacy({super.key})
    : title = 'Privacy Policy',
      assetPath = 'assets/legal/privacy_policy.md';

  const LegalDocumentPage.terms({super.key})
    : title = 'Terms of Service',
      assetPath = 'assets/legal/terms_of_service.md';

  final String title;
  final String assetPath;

  @override
  State<LegalDocumentPage> createState() => _LegalDocumentPageState();
}

class _LegalDocumentPageState extends State<LegalDocumentPage> {
  late final Future<String> _document;

  @override
  void initState() {
    super.initState();
    _document = rootBundle.loadString(widget.assetPath);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: FutureBuilder<String>(
          future: _document,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'The ${widget.title} could not be loaded. Please try again.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final blocks = snapshot.data!.trim().split(
              RegExp(r'\r?\n\s*\r?\n'),
            );
            return Scrollbar(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                itemCount: blocks.length,
                separatorBuilder: (_, _) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final block = blocks[index].trim();
                  final heading =
                      block.startsWith('# ')
                          ? block.substring(2)
                          : block.startsWith('## ')
                          ? block.substring(3)
                          : null;
                  if (heading != null) {
                    return Semantics(
                      header: true,
                      child: SelectableText(
                        heading,
                        style:
                            block.startsWith('# ')
                                ? theme.textTheme.headlineMedium
                                : theme.textTheme.titleLarge,
                      ),
                    );
                  }
                  return SelectableText(
                    block,
                    style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
