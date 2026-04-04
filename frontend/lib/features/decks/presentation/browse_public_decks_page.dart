import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router.dart';
import '../data/deck_repository.dart';

class BrowsePublicDecksPage extends ConsumerStatefulWidget {
  const BrowsePublicDecksPage({super.key});

  @override
  ConsumerState<BrowsePublicDecksPage> createState() =>
      _BrowsePublicDecksPageState();
}

class _BrowsePublicDecksPageState extends ConsumerState<BrowsePublicDecksPage> {
  bool _loading = true;
  String? _error;
  List<PublicDeckSummary> _decks = const [];
  final Set<String> _downloadingDeckIds = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPublicDecks();
    });
  }

  Future<void> _loadPublicDecks() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final decks = await ref.read(deckRepositoryProvider).fetchPublicDecks();
      if (!mounted) return;
      setState(() {
        _decks = decks;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _downloadDeck(PublicDeckSummary deck) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Download this deck?'),
              content: Text(
                'This will create a separate copy of "${deck.title}" in your account. '
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Download'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed) return;

    setState(() {
      _downloadingDeckIds.add(deck.id);
    });

    try {
      final newDeckId =
          await ref.read(deckRepositoryProvider).downloadPublicDeck(deck.id);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${deck.title}" was added to your decks.'),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Open',
            onPressed: () {
              Navigator.of(context).pushNamed(
                AppRoutes.deckDetail,
                arguments: newDeckId,
              );
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to download deck: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _downloadingDeckIds.remove(deck.id);
        });
      }
    }
  }

  String _subtitle(PublicDeckSummary deck) {
    final description = deck.description?.trim();
    if (description != null && description.isNotEmpty) {
      return description;
    }
    return 'By ${deck.ownerUsername}';
  }

  String _meta(PublicDeckSummary deck) {
    final cardLabel = deck.cardCount == 1 ? '1 card' : '${deck.cardCount} cards';
    return '$cardLabel • By ${deck.ownerUsername}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Public decks'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadPublicDecks,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Builder(
        builder: (context) {
          if (_loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_error != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_outlined, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _loadPublicDecks,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (_decks.isEmpty) {
            return RefreshIndicator(
              onRefresh: _loadPublicDecks,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: const [
                  SizedBox(height: 120),
                  Icon(Icons.public_off_outlined, size: 52),
                  SizedBox(height: 16),
                  Text(
                    'No public decks available right now.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _loadPublicDecks,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: _decks.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final deck = _decks[index];
                final downloading = _downloadingDeckIds.contains(deck.id);
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    title: Text(
                      deck.title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_subtitle(deck)),
                          const SizedBox(height: 6),
                          Text(
                            _meta(deck),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    trailing: downloading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : IconButton(
                            onPressed: () => _downloadDeck(deck),
                            icon: const Icon(Icons.download_rounded),
                            tooltip: 'Download deck',
                          ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
