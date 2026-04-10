import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/app_database.dart' as db;
import '../data/csv_import_service.dart';
import '../data/data_sync_service.dart';
import '../data/deck_repository.dart';
import '../model/csv_import_models.dart';

class CsvImportPage extends ConsumerStatefulWidget {
  final String deckId;

  const CsvImportPage({
    super.key,
    required this.deckId,
  });

  @override
  ConsumerState<CsvImportPage> createState() => _CsvImportPageState();
}

class _CsvImportPageState extends ConsumerState<CsvImportPage> {
  CsvImportPreview? _preview;
  String? _errorText;
  bool _isPicking = false;
  bool _isImporting = false;

  Future<void> _pickCsv(int existingCardCount) async {
    setState(() {
      _isPicking = true;
      _errorText = null;
    });

    try {
      final preview = await ref.read(csvImportServiceProvider).pickAndValidateCsv(
            existingCardCount: existingCardCount,
            maxCardsAllowed: DeckRepository.maxCardsPerDeck,
          );

      if (!mounted) return;

      if (preview == null) {
        setState(() => _isPicking = false);
        return;
      }

      setState(() {
        _preview = preview;
        _errorText = null;
        _isPicking = false;
      });
    } on CsvImportException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText = e.message;
        _preview = null;
        _isPicking = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText = 'Could not open CSV: $e';
        _preview = null;
        _isPicking = false;
      });
    }
  }

  Future<void> _importCards() async {
    final preview = _preview;
    if (preview == null) return;

    setState(() {
      _isImporting = true;
      _errorText = null;
    });

    try {
      final importedCount = await ref.read(deckRepositoryProvider).importCardsOffline(
            deckId: widget.deckId,
            cards: preview.cards,
          );

      final syncResult = await ref.read(deckSyncServiceProvider).syncNow();

      if (!mounted) return;

      Navigator.of(context).pop(
        CsvImportSuccessResult(
          importedCount: importedCount,
          syncedNow: syncResult.success,
          message: syncResult.success
              ? '$importedCount cards were imported and synced.'
              : '$importedCount cards were imported locally. ${syncResult.message} They will sync automatically when internet is back.',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isImporting = false;
        _errorText = 'Import failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(deckRepositoryProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final scaffoldColor = theme.scaffoldBackgroundColor;
    final panelColor = isDark ? const Color(0xFF111827) : Colors.white;
    final mutedPanelColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE5E7EB);
    final primaryButton = isDark ? const Color(0xFF6EC1E4) : const Color(0xFF003153);
    final accentFill = isDark ? const Color(0xFF063B2E) : const Color(0xFFEAF7EC);
    final accentText = isDark ? const Color(0xFFB8F2C8) : const Color(0xFF0B5D1E);
    final warningFill = isDark ? const Color(0xFF3A2D00) : const Color(0xFFFFF7D6);

    return Scaffold(
      backgroundColor: scaffoldColor,
      appBar: AppBar(
        title: const Text('Import CSV'),
      ),
      body: StreamBuilder<db.Deck?>(
        stream: repo.watchDeckById(widget.deckId),
        builder: (context, deckSnapshot) {
          final deck = deckSnapshot.data;

          if (deck == null) {
            return const Center(
              child: Text('Deck not found'),
            );
          }

          return StreamBuilder<List<db.Card>>(
            stream: repo.watchCardsByDeck(widget.deckId),
            builder: (context, cardsSnapshot) {
              final existingCards = cardsSnapshot.data ?? const <db.Card>[];
              final existingCount = existingCards.length;
              final remainingSlots = existingCount >= DeckRepository.maxCardsPerDeck
                  ? 0
                  : DeckRepository.maxCardsPerDeck - existingCount;

              final preview = _preview;
              final previewCards = preview?.cards ?? const <CsvCardDraft>[];
              final previewTooLargeNow =
                  preview != null && previewCards.length > remainingSlots;

              return SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          color: mutedPanelColor,
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              deck.title,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Pick a CSV with exactly two columns: Front and Back. The cards will be created locally first and synced later when internet is available.',
                              style: theme.textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                _InfoPill(label: '$existingCount existing'),
                                _InfoPill(
                                  label: '$remainingSlots slots left',
                                  highlighted: remainingSlots > 0,
                                ),
                                _InfoPill(
                                  label: 'Max ${DeckRepository.maxCardsPerDeck}',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          color: panelColor,
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Expected CSV format',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                color: accentFill,
                              ),
                              child: Text(
                                'Front,Back\n'
                                'What is 2 + 2?,4\n'
                                'Hola,Hello\n'
                                'Capital of France,Paris',
                                style: TextStyle(
                                  color: accentText,
                                  fontWeight: FontWeight.w600,
                                  height: 1.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Rules: real CSV only, exactly 2 columns, header must be Front and Back, maximum 50 card rows, and the file must still fit inside the deck limit.',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          color: panelColor,
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.upload_file_outlined,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    preview == null
                                        ? 'Choose a CSV to preview'
                                        : preview.fileName,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              preview == null
                                  ? 'Nothing selected yet.'
                                  : '${preview.importedCount} cards validated and ready to import.',
                              style: theme.textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 50,
                              child: ElevatedButton.icon(
                                onPressed: (remainingSlots <= 0 || _isPicking || _isImporting)
                                    ? null
                                    : () => _pickCsv(existingCount),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryButton,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                icon: _isPicking
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.folder_open_outlined),
                                label: Text(
                                  _isPicking ? 'Reading CSV...' : 'Pick CSV file',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (remainingSlots <= 0) ...[
                        const SizedBox(height: 16),
                        _MessageBanner(
                          backgroundColor: warningFill,
                          icon: Icons.warning_amber_rounded,
                          title: 'Deck is full',
                          message:
                              'This deck already has the maximum number of cards, so CSV import is disabled.',
                        ),
                      ],
                      if (_errorText != null) ...[
                        const SizedBox(height: 16),
                        _MessageBanner(
                          backgroundColor: warningFill,
                          icon: Icons.error_outline,
                          title: 'Import validation failed',
                          message: _errorText!,
                        ),
                      ],
                      if (preview != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            color: panelColor,
                            border: Border.all(color: borderColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Preview',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  _InfoPill(
                                    label: '${preview.importedCount} cards',
                                    highlighted: true,
                                  ),
                                  const _InfoPill(label: '2 columns only'),
                                  const _InfoPill(label: 'Local-first import'),
                                  const _InfoPill(label: 'Auto-sync when online'),
                                ],
                              ),
                              if (previewTooLargeNow) ...[
                                const SizedBox(height: 14),
                                _MessageBanner(
                                  backgroundColor: warningFill,
                                  icon: Icons.warning_amber_rounded,
                                  title: 'Deck changed while this page was open',
                                  message:
                                      'Your preview now exceeds the remaining capacity. Pick a smaller CSV.',
                                ),
                              ],
                              const SizedBox(height: 14),
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: previewCards.length > 6 ? 6 : previewCards.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final card = previewCards[index];
                                  return Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      color: mutedPanelColor,
                                      border: Border.all(color: borderColor),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Row ${card.sourceRow}',
                                          style: theme.textTheme.labelMedium?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: theme.textTheme.bodySmall?.color,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          card.front,
                                          style: theme.textTheme.titleSmall?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(card.back),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              if (previewCards.length > 6) ...[
                                const SizedBox(height: 10),
                                Text(
                                  '+ ${previewCards.length - 6} more cards will be imported.',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                              const SizedBox(height: 18),
                              SizedBox(
                                height: 50,
                                child: ElevatedButton.icon(
                                  onPressed: (_isImporting || previewTooLargeNow || remainingSlots <= 0)
                                      ? null
                                      : _importCards,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryButton,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  icon: _isImporting
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.cloud_upload_outlined),
                                  label: Text(
                                    _isImporting
                                        ? 'Importing cards...'
                                        : 'Import cards into deck',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final String label;
  final bool highlighted;

  const _InfoPill({
    required this.label,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: highlighted
            ? theme.colorScheme.primary.withOpacity(0.12)
            : theme.colorScheme.primary.withOpacity(0.08),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MessageBanner extends StatelessWidget {
  final Color backgroundColor;
  final IconData icon;
  final String title;
  final String message;

  const _MessageBanner({
    required this.backgroundColor,
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(message),
              ],
            ),
          ),
        ],
      ),
    );
  }
}