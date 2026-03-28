import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router.dart';
import '../../../core/storage/app_database.dart' as db;
import '../data/data_sync_service.dart';
import '../data/deck_repository.dart';
import 'browse_public_decks_page.dart';

class BrowseDecksPage extends ConsumerStatefulWidget {
  const BrowseDecksPage({super.key});

  @override
  ConsumerState<BrowseDecksPage> createState() => _BrowseDecksPageState();
}

class _BrowseDecksPageState extends ConsumerState<BrowseDecksPage> {
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refresh();
    });
  }

  Future<void> _refresh() async {
    if (_refreshing) return;

    setState(() => _refreshing = true);
    try {
      final result = await ref.read(deckSyncServiceProvider).syncNow();
      if (!mounted) return;
      if (result.warning) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _refreshing = false);
      }
    }
  }

  void _openDeck(String deckId) {
    Navigator.of(context).pushNamed(AppRoutes.deckDetail, arguments: deckId);
  }

  Future<void> _openPublicDecks() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const BrowsePublicDecksPage()),
    );
  }

  String _subtitle(db.Deck deck) {
    final description = (deck.description ?? '').toString().trim();
    if (description.isNotEmpty) {
      return description;
    }
    return deck.isPublic ? 'Public deck' : 'Private deck';
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(deckRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your decks'),
        actions: [
          IconButton(
            onPressed: _refreshing ? null : _refresh,
            icon: _refreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            tooltip: 'Sync now',
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openPublicDecks,
        icon: const Icon(Icons.public),
        label: const Text('Browse public decks'),
      ),
      body: StreamBuilder<List<db.Deck>>(
        stream: repo.watchDecks(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final decks = snapshot.data ?? const <db.Deck>[];
          if (decks.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 32, 20, 120),
                children: const [
                  SizedBox(height: 120),
                  Icon(Icons.style_outlined, size: 52),
                  SizedBox(height: 16),
                  Text(
                    'No decks yet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Create a deck or download one from the public library.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              itemCount: decks.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final deck = decks[index];
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    onTap: () => _openDeck(deck.id),
                    title: Text(
                      deck.title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(_subtitle(deck)),
                    ),
                    trailing: Icon(
                      deck.isPublic == true ? Icons.public : Icons.lock_outline,
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
