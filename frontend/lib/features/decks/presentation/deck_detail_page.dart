import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/app_database.dart' as db;
import '../data/data_sync_service.dart';
import '../data/deck_repository.dart';
import 'csv_import_page.dart';
import '../model/csv_import_models.dart';

enum _DeckDetailAction { editDeck, deleteDeck }
enum _CardMenuAction { edit, delete }

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

  void _triggerBackgroundSync() {
    unawaited(ref.read(deckSyncServiceProvider).syncNow());
  }

  Future<void> _undoDeckDeletion(PendingDeckDeletion deletion) async {
    await ref.read(deckRepositoryProvider).undoDeckDeletion(deletion);
    _triggerBackgroundSync();
  }

  Future<void> _undoCardDeletion(PendingCardDeletion deletion) async {
    await ref.read(deckRepositoryProvider).undoCardDeletion(deletion);
    _triggerBackgroundSync();
  }

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

      await repo.createCardOffline(
        deckId: widget.deckId,
        front: _frontController.text.trim(),
        back: _backController.text.trim(),
      );

      _triggerBackgroundSync();

      if (!mounted) return;

      _frontController.clear();
      _backController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Card created successfully.'),
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
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _handleDeckAction(_DeckDetailAction action, db.Deck deck) async {
    switch (action) {
      case _DeckDetailAction.editDeck:
        await _showEditDeckDialog(deck);
        break;
      case _DeckDetailAction.deleteDeck:
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
      await ref.read(deckRepositoryProvider).updateDeckOffline(
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
          content: Text('Failed to update deck: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _confirmAndDeleteDeck(db.Deck deck) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
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
      final deletion = await repo.markDeckDeletedOffline(deck.id);
      _triggerBackgroundSync();
      if (!mounted) return;

      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      final controller = messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 10),
          behavior: SnackBarBehavior.floating,
          content: Text('Deck deleted: ${deck.title}'),
          action: SnackBarAction(
            label: 'UNDO',
            onPressed: () {
              unawaited(_undoDeckDeletion(deletion).catchError((_) {}));
            },
          ),
        ),
      );

      if (mounted) {
        Navigator.of(context).pop(true);
      }

      unawaited(controller.closed.then((reason) async {
        if (reason == SnackBarClosedReason.action) {
          return;
        }
        await repo.finalizeDeckDeletion(deletion);
      }));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete deck: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleCardAction(_CardMenuAction action, db.Card card) async {
    switch (action) {
      case _CardMenuAction.edit:
        await _showEditCardDialog(card);
        break;
      case _CardMenuAction.delete:
        await _deleteCard(card);
        break;
    }
  }

  Future<void> _showEditCardDialog(db.Card card) async {
    final result = await showDialog<_CardEditResult>(
      context: context,
      builder: (context) => _CardEditDialog(card: card),
    );
    if (result == null) return;

    try {
      await ref.read(deckRepositoryProvider).updateCardOffline(
            cardId: card.id,
            front: result.front,
            back: result.back,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Card updated successfully.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _triggerBackgroundSync();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update card: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _deleteCard(db.Card card) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete card?'),
            content: const Text(
              'This card will be removed. You can undo this for 10 seconds.',
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
      final deletion = await repo.markCardDeletedOffline(card.id);
      _triggerBackgroundSync();
      if (!mounted) return;

      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      final controller = messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 10),
          behavior: SnackBarBehavior.floating,
          content: const Text('Card deleted'),
          action: SnackBarAction(
            label: 'UNDO',
            onPressed: () {
              unawaited(_undoCardDeletion(deletion).catchError((_) {}));
            },
          ),
        ),
      );

      unawaited(controller.closed.then((reason) async {
        if (reason == SnackBarClosedReason.action) {
          return;
        }
        await repo.finalizeCardDeletion(deletion);
      }));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete card: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  int _dueCount(List<db.Card> cards) {
    final now = DateTime.now().toUtc();
    return cards.where((card) {
      final due = card.dueTimestamp;
      return due == null || !due.isAfter(now);
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(deckRepositoryProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final backgroundColor = isDark ? Colors.black : Colors.white;
    final greenFieldFill =
        isDark ? const Color(0xFF063B2E) : const Color(0xFFEAF7EC);
    final greenTextColor =
        isDark ? const Color(0xFFB8F2C8) : const Color(0xFF0B5D1E);
    final fieldBorderColor = const Color(0xFF2E8B57);
    final buttonColor =
        isDark ? const Color(0xFF6EC1E4) : const Color(0xFF003153);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: backgroundColor,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(true),
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
              final cards = cardsSnapshot.data ?? const <db.Card>[];
              final totalCards = cards.length;
              final dueCards = _dueCount(cards);
              final hasReachedLimit = totalCards >= DeckRepository.maxCardsPerDeck;

              return SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.fromLTRB(
                        16,
                        16,
                        16,
                        16 + MediaQuery.of(context).viewInsets.bottom,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: isDark
                                    ? const Color(0xFF1A2D3D)
                                    : const Color(0xFFF5F5F5),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          deck.title,
                                          style: theme.textTheme.titleLarge
                                              ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      PopupMenuButton<_DeckDetailAction>(
                                        onSelected: (action) =>
                                            _handleDeckAction(action, deck),
                                        itemBuilder: (context) => const [
                                          PopupMenuItem(
                                            value:
                                                _DeckDetailAction.editDeck,
                                            child: ListTile(
                                              contentPadding: EdgeInsets.zero,
                                              leading:
                                                  Icon(Icons.edit_outlined),
                                              title: Text('Edit deck'),
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value:
                                                _DeckDetailAction.deleteDeck,
                                            child: ListTile(
                                              contentPadding: EdgeInsets.zero,
                                              leading:
                                                  Icon(Icons.delete_outline),
                                              title: Text('Delete deck'),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    deck.description ?? 'No description yet.',
                                    style:
                                        theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.textTheme.bodySmall?.color
                                          ?.withOpacity(0.8),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: [
                                      _Pill(
                                        label:
                                            '$totalCards/${DeckRepository.maxCardsPerDeck} cards',
                                      ),
                                      _Pill(label: '$dueCards due'),
                                      _Pill(
                                        label: deck.isPublic
                                            ? 'Public'
                                            : 'Private',
                                      ),
                                    ],
                                  ),
                                  if (hasReachedLimit) ...[
                                    const SizedBox(height: 12),
                                    Text(
                                      'This deck already has the maximum 50 cards.',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                        color: Colors.redAccent,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Form(
                              key: _formKey,
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  color: isDark
                                      ? const Color(0xFF111827)
                                      : Colors.white,
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.white12
                                        : const Color(0xFFE3E3E3),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Add card',
                                                style: theme.textTheme.titleMedium?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                'Limit: ${DeckRepository.maxCardsPerDeck} cards per deck',
                                                style: theme.textTheme.bodySmall,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        OutlinedButton.icon(
                                          onPressed: (hasReachedLimit || _loading) ? null : _openCsvImport,
                                          icon: const Icon(Icons.upload_file_outlined),
                                          label: const Text('Import CSV'),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      controller: _frontController,
                                      enabled: !hasReachedLimit && !_loading,
                                      style:
                                          TextStyle(color: greenTextColor),
                                      cursorColor: greenTextColor,
                                      textInputAction: TextInputAction.next,
                                      decoration: InputDecoration(
                                        labelText: 'Front',
                                        labelStyle: TextStyle(
                                          color: greenTextColor,
                                        ),
                                        filled: true,
                                        fillColor: greenFieldFill,
                                        enabledBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: fieldBorderColor,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: fieldBorderColor,
                                            width: 2,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                      ),
                                      validator: (value) {
                                        if (value == null ||
                                            value.trim().isEmpty) {
                                          return 'Enter the front of the card';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: _backController,
                                      enabled: !hasReachedLimit && !_loading,
                                      style:
                                          TextStyle(color: greenTextColor),
                                      cursorColor: greenTextColor,
                                      maxLines: 3,
                                      minLines: 3,
                                      textInputAction: TextInputAction.done,
                                      decoration: InputDecoration(
                                        labelText: 'Back',
                                        labelStyle: TextStyle(
                                          color: greenTextColor,
                                        ),
                                        filled: true,
                                        fillColor: greenFieldFill,
                                        enabledBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: fieldBorderColor,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: fieldBorderColor,
                                            width: 2,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                      ),
                                      validator: (value) {
                                        if (value == null ||
                                            value.trim().isEmpty) {
                                          return 'Enter the back of the card';
                                        }
                                        return null;
                                      },
                                      onFieldSubmitted: (_) {
                                        if (!_loading && !hasReachedLimit) {
                                          _addCard();
                                        }
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    SizedBox(
                                      height: 50,
                                      child: ElevatedButton(
                                        onPressed:
                                            (_loading || hasReachedLimit)
                                                ? null
                                                : _addCard,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: buttonColor,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(14),
                                          ),
                                        ),
                                        child: _loading
                                            ? const SizedBox(
                                                height: 18,
                                                width: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : Text(
                                                hasReachedLimit
                                                    ? 'Card limit reached'
                                                    : 'Save Card',
                                              ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Cards in this deck',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (cards.isEmpty)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 24),
                                child: Center(
                                  child: Text(
                                    'No cards yet. Add your first one.',
                                    style:
                                        theme.textTheme.bodyMedium?.copyWith(
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics:
                                    const NeverScrollableScrollPhysics(),
                                itemCount: cards.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final card = cards[index];
                                  return Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      borderRadius:
                                          BorderRadius.circular(18),
                                      color: isDark
                                          ? const Color(0xFF111827)
                                          : Colors.white,
                                      border: Border.all(
                                        color: isDark
                                            ? Colors.white12
                                            : const Color(0xFFE8E8E8),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                card.front,
                                                style: theme
                                                    .textTheme.titleSmall
                                                    ?.copyWith(
                                                  fontWeight:
                                                      FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            PopupMenuButton<_CardMenuAction>(
                                              onSelected: (action) =>
                                                  _handleCardAction(
                                                action,
                                                card,
                                              ),
                                              itemBuilder: (context) => const [
                                                PopupMenuItem(
                                                  value:
                                                      _CardMenuAction.edit,
                                                  child: ListTile(
                                                    contentPadding:
                                                        EdgeInsets.zero,
                                                    leading: Icon(
                                                      Icons.edit_outlined,
                                                    ),
                                                    title: Text('Edit'),
                                                  ),
                                                ),
                                                PopupMenuItem(
                                                  value:
                                                      _CardMenuAction.delete,
                                                  child: ListTile(
                                                    contentPadding:
                                                        EdgeInsets.zero,
                                                    leading: Icon(
                                                      Icons.delete_outline,
                                                    ),
                                                    title: Text('Delete'),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(card.back),
                                      ],
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openCsvImport() async {
    final result = await Navigator.of(context).push<CsvImportSuccessResult>(
      MaterialPageRoute(
        builder: (_) => CsvImportPage(deckId: widget.deckId),
      ),
    );

    if (!mounted || result == null) return;

    final isSyncedNow = result.syncedNow;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            isSyncedNow ? Colors.green : const Color(0xFFFACC15),
        content: Text(
          result.message,
          style: TextStyle(
            color: isSyncedNow ? Colors.white : Colors.black,
          ),
        ),
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
    _descriptionController =
        TextEditingController(text: widget.deck.description ?? '');
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

class _CardEditResult {
  final String front;
  final String back;

  const _CardEditResult({
    required this.front,
    required this.back,
  });
}

class _CardEditDialog extends StatefulWidget {
  final db.Card card;

  const _CardEditDialog({required this.card});

  @override
  State<_CardEditDialog> createState() => _CardEditDialogState();
}

class _CardEditDialogState extends State<_CardEditDialog> {
  late final TextEditingController _frontController;
  late final TextEditingController _backController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _frontController = TextEditingController(text: widget.card.front);
    _backController = TextEditingController(text: widget.card.back);
  }

  @override
  void dispose() {
    _frontController.dispose();
    _backController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit card'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _frontController,
                decoration: const InputDecoration(labelText: 'Front'),
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
                decoration: const InputDecoration(labelText: 'Back'),
                minLines: 3,
                maxLines: 4,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter the back of the card';
                  }
                  return null;
                },
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
              _CardEditResult(
                front: _frontController.text.trim(),
                back: _backController.text.trim(),
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;

  const _Pill({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
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
