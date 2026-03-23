import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router.dart';
import '../data/deck_repository.dart';
import '../data/data_sync_service.dart';
import '../../home/domain/home_dashboard_models.dart';

class DeckDetailPage extends ConsumerStatefulWidget {
  final String deckId;

  const DeckDetailPage({super.key, required this.deckId});

  @override
  ConsumerState<DeckDetailPage> createState() => _DeckDetailPageState();
}

class _DeckDetailPageState extends ConsumerState<DeckDetailPage> {
  final _frontController = TextEditingController();
  final _backController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(deckSyncServiceProvider).syncNow();
    });
  }

  @override
  void dispose() {
    _frontController.dispose();
    _backController.dispose();
    super.dispose();
  }

  Future<void> _addCard() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _loading = true);

    try {
      final repo = ref.read(deckRepositoryProvider);
      final syncService = ref.read(deckSyncServiceProvider);

      await repo.createCardOffline(
        deckId: widget.deckId,
        front: _frontController.text.trim(),
        back: _backController.text.trim(),
      );

      await syncService.syncNow();

      if (!mounted) return;

      _frontController.clear();
      _backController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Card saved locally. Sync will run when online.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save card: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(deckRepositoryProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.black : Colors.white;
    final greenFieldFill = isDark
        ? const Color(0xFF063B2E)
        : const Color(0xFFEAF7EC);
    final greenTextColor = isDark
        ? const Color(0xFFB8F2C8)
        : const Color(0xFF0B5D1E);
    final fieldBorderColor = const Color(0xFF2E8B57);
    final buttonColor = isDark
        ? const Color(0xFF6EC1E4)
        : const Color(0xFF003153);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Deck'),
        actions: [
          IconButton(
            tooltip: 'Sync now',
            onPressed: () => ref.read(deckSyncServiceProvider).syncNow(),
            icon: const Icon(Icons.sync),
          ),
        ],
      ),
      body: StreamBuilder(
        stream: repo.watchDeckById(widget.deckId),
        builder: (context, deckSnapshot) {
          final deck = deckSnapshot.data;

          if (deck == null) {
            return const Center(
              child: Text('Deck not found'),
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: isDark ? const Color(0xFF1A2D3D) : const Color(0xFFF5F5F5),
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
                        deck.description ?? 'No description yet.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.textTheme.bodySmall?.color?.withOpacity(0.8),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _Pill(label: '${deck.totalCards} cards'),
                          _Pill(label: '${deck.dueCards} due'),
                          _Pill(
                            label: deck.isPublic ? 'Public' : 'Private',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Form(
                  key: _formKey,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: isDark ? const Color(0xFF111827) : Colors.white,
                      border: Border.all(
                        color: isDark ? Colors.white12 : const Color(0xFFE3E3E3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Add card',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _frontController,
                          style: TextStyle(color: greenTextColor),
                          cursorColor: greenTextColor,
                          decoration: InputDecoration(
                            labelText: 'Front',
                            labelStyle: TextStyle(color: greenTextColor),
                            filled: true,
                            fillColor: greenFieldFill,
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: fieldBorderColor),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: fieldBorderColor,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Enter the front of the card';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _backController,
                          style: TextStyle(color: greenTextColor),
                          cursorColor: greenTextColor,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: 'Back',
                            labelStyle: TextStyle(color: greenTextColor),
                            filled: true,
                            fillColor: greenFieldFill,
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: fieldBorderColor),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: fieldBorderColor,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Enter the back of the card';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _addCard,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: buttonColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: _loading
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Save Card'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Cards in this deck',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              Expanded(
                child: StreamBuilder(
                  stream: repo.watchCardsByDeck(widget.deckId),
                  builder: (context, snapshot) {
                    final cards = snapshot.data ?? const [];

                    if (cards.isEmpty) {
                      return Center(
                        child: Text(
                          'No cards yet. Add your first one.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: cards.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final card = cards[index];
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            color: isDark ? const Color(0xFF1A2D3D) : const Color(0xFFF5F5F5),
                            border: Border.all(
                              color: isDark ? Colors.white12 : const Color(0xFFE4E4E4),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                card.front,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                card.back,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.8),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;

  const _Pill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Theme.of(context).dividerColor.withOpacity(0.10),
      ),
      child: Text(label),
    );
  }
}