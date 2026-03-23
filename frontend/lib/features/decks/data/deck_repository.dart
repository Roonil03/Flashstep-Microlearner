import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/app_database.dart' as db;
import '../../../core/storage/database_provider.dart';
import '../../../core/storage/session_storage.dart';

final deckRepositoryProvider = Provider<DeckRepository>((ref) {
  return DeckRepository(
    database: ref.read(appDatabaseProvider),
    storage: const SessionStorage(),
  );
});

class DeckRepository {
  final db.AppDatabase _database;
  final SessionStorage _storage;

  DeckRepository({
    required db.AppDatabase database,
    required SessionStorage storage,
  })  : _database = database,
        _storage = storage;

  String _generateId() {
    final random = Random();
    final millis = DateTime.now().microsecondsSinceEpoch;
    final suffix = random.nextInt(1 << 32);
    return '$millis$suffix';
  }

  Future<String> createDeckOffline({
    required String title,
    String? description,
    required bool isPublic,
  }) async {
    final userId = await _storage.readUserId();
    if (userId == null || userId.isEmpty) {
      throw StateError('No signed-in user found.');
    }

    final now = DateTime.now().toUtc();
    final deckId = _generateId();
    final normalizedDescription =
        (description == null || description.trim().isEmpty)
            ? null
            : description.trim();

    await _database.into(_database.decks).insert(
          db.DecksCompanion.insert(
            id: deckId,
            userId: userId,
            title: title.trim(),
            description: Value(normalizedDescription),
            totalCards: const Value(0),
            dueCards: const Value(0),
            progress: const Value(0),
            isPublic: Value(isPublic),
            nextDueAt: const Value(null),
            createdAt: now,
            updatedAt: now,
            version: const Value(1),
            isDeleted: const Value(false),
          ),
        );

    await _database.into(_database.syncQueueItems).insert(
          db.SyncQueueItemsCompanion.insert(
            operationId: deckId,
            type: 'create',
            entity: 'deck',
            payload: 
              jsonEncode({
                'id': deckId,
                'title': title.trim(),
                'description': normalizedDescription,
                'is_public': isPublic,
                'updated_at': now.toIso8601String(),
                'version': 1,
                'is_deleted': false,
              }),
            
            createdAt: now,
            synced: const Value(false),
          ),
        );

    return deckId;
  }

  Future<String> createCardOffline({
    required String deckId,
    required String front,
    required String back,
  }) async {
    final now = DateTime.now().toUtc();
    final cardId = _generateId();

    final deck = await (_database.select(_database.decks)
          ..where((tbl) => tbl.id.equals(deckId) & tbl.isDeleted.equals(false)))
        .getSingleOrNull();

    if (deck == null) {
      throw StateError('Deck not found.');
    }

    await _database.into(_database.cards).insert(
          db.CardsCompanion.insert(
            id: cardId,
            deckId: deckId,
            front: front.trim(),
            back: back.trim(),
            state: const Value('new'),
            interval: const Value(0),
            easeFactor: const Value(2.5),
            repetitionCount: const Value(0),
            dueTimestamp: Value(now),
            lastReviewedAt: const Value(null),
            createdAt: now,
            updatedAt: now,
            version: const Value(1),
            isDeleted: const Value(false),
          ),
        );

    await (_database.update(_database.decks)..where((tbl) => tbl.id.equals(deckId))).write(
      db.DecksCompanion(
        totalCards: Value(deck.totalCards + 1),
        dueCards: Value(deck.dueCards + 1),
        nextDueAt: Value(now),
        updatedAt: Value(now),
        version: Value(deck.version + 1),
      ),
    );

    await _database.into(_database.syncQueueItems).insert(
          db.SyncQueueItemsCompanion.insert(
            operationId: cardId,
            type: 'create',
            entity: 'card',
            payload: 
              jsonEncode({
                'id': cardId,
                'deck_id': deckId,
                'front': front.trim(),
                'back': back.trim(),
                'state': 'new',
                'interval': 0,
                'ease_factor': 2.5,
                'repetition_count': 0,
                'due_timestamp': now.toIso8601String(),
                'updated_at': now.toIso8601String(),
                'version': 1,
                'is_deleted': false,
              }),
            
            createdAt: now,
            synced: const Value(false),
          ),
        );

    return cardId;
  }

  Stream<List<db.Deck>> watchDecks() {
    return (_database.select(_database.decks)
          ..where((tbl) => tbl.isDeleted.equals(false))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.updatedAt)]))
        .watch();
  }

  Stream<db.Deck?> watchDeckById(String deckId) {
    return (_database.select(_database.decks)
          ..where((tbl) => tbl.id.equals(deckId) & tbl.isDeleted.equals(false)))
        .watchSingleOrNull();
  }

  Stream<List<db.Card>> watchCardsByDeck(String deckId) {
    return (_database.select(_database.cards)
          ..where((tbl) => tbl.deckId.equals(deckId) & tbl.isDeleted.equals(false))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)]))
        .watch();
  }
}