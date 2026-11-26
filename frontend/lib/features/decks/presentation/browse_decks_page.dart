import 'library_heading.dart';
import '../../../app/theme/study_colors.dart';
import '../../../core/network/api_errors.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router.dart';
import '../../../core/storage/app_database.dart' as db;
import '../data/data_sync_service.dart';
import '../data/deck_repository.dart';
import 'browse_public_decks_page.dart';

enum _DeckMenuAction { rename, delete }

class BrowseDecksPage extends ConsumerStatefulWidget {
  const BrowseDecksPage({super.key});

  @override
  ConsumerState<BrowseDecksPage> createState() => _BrowseDecksPageState();
}

class _BrowseDecksPageState extends ConsumerState<BrowseDecksPage> {
  bool _refreshing = false;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  void _triggerBackgroundSync() {
    unawaited(ref.read(deckSyncServiceProvider).syncNow());
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refresh();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const BrowsePublicDecksPage()));
  }

  String _subtitle(db.Deck deck) {
    final description = (deck.description ?? '').trim();
    if (description.isNotEmpty) {
      return description;
    }
    return deck.isPublic ? 'Public deck' : 'Private deck';
  }

  Future<void> _handleDeckAction(_DeckMenuAction action, db.Deck deck) async {
    switch (action) {
      case _DeckMenuAction.rename:
        await _showEditDeckDialog(deck);
        break;
      case _DeckMenuAction.delete:
        await _confirmAndDeleteDeck(deck);
        break;
    }
  }

  Future<void> _showEditDeckDialog(db.Deck deck) async {
    final result = await showDialog<_DeckEditResult>(
      context: context,
      builder: (context) => _DeckEditDialog(deck: deck),
    );
    if (result == null) return;

    try {
      await ref
          .read(deckRepositoryProvider)
          .updateDeckOffline(
            deckId: deck.id,
            title: result.title,
            description: result.description,
            isPublic: result.isPublic,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Deck updated successfully.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _triggerBackgroundSync();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update deck: ${networkErrorMessage(e)}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _confirmAndDeleteDeck(db.Deck deck) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Delete deck?'),
                content: Text(
                  '"${deck.title}" will be removed. You can undo this for 10 seconds.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Delete'),
                  ),
                ],
              ),
        ) ??
        false;

    if (!confirmed) return;

    try {
      final repo = ref.read(deckRepositoryProvider);
      final sync = ref.read(deckSyncServiceProvider);
      final deletion = await repo.markDeckDeletedOffline(deck.id);
      if (!mounted) {
        await repo.finalizeDeckDeletion(deletion);
        unawaited(sync.syncAfterLocalChange());
        return;
      }

      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      final controller = messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 10),
          persist: MediaQuery.accessibleNavigationOf(context),
          behavior: SnackBarBehavior.floating,
          content: Text('Deck deleted: ${deck.title}'),
          action: SnackBarAction(
            label: 'UNDO',
            onPressed: () {
              unawaited(
                repo
                    .undoDeckDeletion(deletion)
                    .then((_) {
                      unawaited(sync.syncAfterLocalChange());
                    })
                    .catchError((_) async {
                      try {
                        await repo.finalizeDeckDeletion(deletion);
                        await sync.syncAfterLocalChange();
                      } catch (_) {
                        // An account switch may have closed this database.
                      }
                    }),
              );
            },
          ),
        ),
      );

      unawaited(
        controller.closed
            .then((reason) async {
              if (reason == SnackBarClosedReason.action) {
                return;
              }
              await repo.finalizeDeckDeletion(deletion);
              await sync.syncAfterLocalChange();
            })
            .catchError((_) {}),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete deck: ${networkErrorMessage(e)}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(deckRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title:
            _isSearching
                ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Search decks...',
                    border: InputBorder.none,
                  ),
                  style: const TextStyle(fontSize: 18),
                )
                : const Text('Your decks'),
        actions: [
          if (_isSearching)
            IconButton(
              tooltip: 'Close deck search',
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _isSearching = false;
                  _searchController.clear();
                });
              },
            )
          else
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                setState(() {
                  _isSearching = true;
                });
              },
              tooltip: 'Search',
            ),
          IconButton(
            onPressed: _refreshing ? null : _refresh,
            icon:
                _refreshing
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
      body: StreamBuilder<List<db.Deck>>(
        stream: repo.watchDecks(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          var decks = snapshot.data ?? const <db.Deck>[];

          if (_searchQuery.isNotEmpty) {
            decks =
                decks
                    .where(
                      (deck) => deck.title.toLowerCase().contains(_searchQuery),
                    )
                    .toList();
          }

          if (decks.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 32, 20, 120),
                children: [
                  LibraryHeading(
                    title: 'Your decks',
                    description: 'Keep your topics together in one library.',
                    count: '${decks.length} decks',
                    action: OutlinedButton.icon(
                      onPressed: _openPublicDecks,
                      icon: const Icon(Icons.public),
                      label: const Text('Browse public decks'),
                    ),
                  ),
                  const SizedBox(height: 40),
                  const Icon(Icons.style_outlined, size: 52),
                  const SizedBox(height: 16),
                  Text(
                    _searchQuery.isNotEmpty
                        ? 'No decks match "${_searchController.text.trim()}".'
                        : 'No decks yet. Create a deck from Home, or browse public decks.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _searchQuery.isNotEmpty
                        ? 'Try another title or clear your search.'
                        : 'Create a deck or download one from the public library.',
                    textAlign: TextAlign.center,
                  ),
                  if (_searchQuery.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Center(
                      child: OutlinedButton.icon(
                        onPressed: _searchController.clear,
                        icon: const Icon(Icons.clear),
                        label: const Text('Clear search'),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: EdgeInsets.fromLTRB(
                _pageInset(context),
                16,
                _pageInset(context),
                32,
              ),
              itemCount: decks.length + 1,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return LibraryHeading(
                    title: 'Your decks',
                    description: 'Open a topic to add cards or plan a review.',
                    count:
                        '${decks.length} ${decks.length == 1 ? 'deck' : 'decks'}',
                    action: OutlinedButton.icon(
                      onPressed: _openPublicDecks,
                      icon: const Icon(Icons.public),
                      label: const Text('Browse public decks'),
                    ),
                  );
                }
                final deck = decks[index - 1];
                return Material(
                  color: Colors.transparent,
                  child: Row(
                    children: [
                      Expanded(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 12,
                          ),
                          onTap: () => _openDeck(deck.id),
                          title: Text(
                            deck.title,
                            style: TextStyle(
                              color:
                                  context.studyTone(StudyArea.library).accent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(_subtitle(deck)),
                          ),
                        ),
                      ),
                      PopupMenuButton<_DeckMenuAction>(
                        tooltip: 'Deck actions for ${deck.title}',
                        onSelected: (action) => _handleDeckAction(action, deck),
                        itemBuilder:
                            (context) => const [
                              PopupMenuItem(
                                value: _DeckMenuAction.rename,
                                child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(Icons.edit_outlined),
                                  title: Text('Edit'),
                                ),
                              ),
                              PopupMenuItem(
                                value: _DeckMenuAction.delete,
                                child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(Icons.delete_outline),
                                  title: Text('Delete'),
                                ),
                              ),
                            ],
                        icon: Icon(
                          deck.isPublic ? Icons.public : Icons.lock_outline,
                        ),
                      ),
                    ],
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

class _DeckEditResult {
  final String title;
  final String? description;
  final bool isPublic;

  const _DeckEditResult({
    required this.title,
    required this.description,
    required this.isPublic,
  });
}

class _DeckEditDialog extends StatefulWidget {
  final db.Deck deck;

  const _DeckEditDialog({required this.deck});

  @override
  State<_DeckEditDialog> createState() => _DeckEditDialogState();
}

class _DeckEditDialogState extends State<_DeckEditDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late bool _isPublic;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.deck.title);
    _descriptionController = TextEditingController(
      text: widget.deck.description ?? '',
    );
    _isPublic = widget.deck.isPublic;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit deck'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Deck name'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter a deck name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                minLines: 2,
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                value: _isPublic,
                onChanged: (value) => setState(() => _isPublic = value),
                title: const Text('Make this deck public'),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) {
              return;
            }
            Navigator.of(context).pop(
              _DeckEditResult(
                title: _titleController.text.trim(),
                description: _descriptionController.text.trim(),
                isPublic: _isPublic,
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

double _pageInset(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  return width > 1080 ? (width - 1048) / 2 : 16;
}
