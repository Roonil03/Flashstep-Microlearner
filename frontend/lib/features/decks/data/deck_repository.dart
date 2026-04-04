import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../../core/config/api_config.dart';
import '../../../core/storage/app_database.dart' as db;
import '../../../core/storage/database_provider.dart';
import '../../../core/storage/session_storage.dart';

final _uuid = Uuid();

final deckRepositoryProvider = Provider<DeckRepository>((ref) {
  return DeckRepository(
    database: ref.watch(appDatabaseProvider),
    storage: const SessionStorage(),
  );
});

class PublicDeckSummary {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final String ownerUsername;
  final int cardCount;
  final DateTime updatedAt;
  final int version;

  const PublicDeckSummary({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.ownerUsername,
    required this.cardCount,
    required this.updatedAt,
    required this.version,
  });

  factory PublicDeckSummary.fromJson(Map<String, dynamic> json) {
    return PublicDeckSummary(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      ownerUsername: json['owner_username']?.toString() ?? 'Unknown',
      cardCount: (json['card_count'] as num?)?.toInt() ?? 0,
      updatedAt:
          DateTime.tryParse(json['updated_at']?.toString() ?? '')?.toUtc() ??
              DateTime.now().toUtc(),
      version: (json['version'] as num?)?.toInt() ?? 1,
    );
  }
}

class PendingCardDeletion {
  final String operationId;
  final db.Card snapshot;

  const PendingCardDeletion({
    required this.operationId,
    required this.snapshot,
  });
}

class PendingDeckDeletion {
  final String operationId;
  final List<String> cardDeleteOperationIds;
  final db.Deck snapshot;
  final List<db.Card> cardSnapshots;

  const PendingDeckDeletion({
    required this.operationId,
    required this.cardDeleteOperationIds,
    required this.snapshot,
    required this.cardSnapshots,
  });
}

class DeckRepository {
  static const int maxCardsPerDeck = 50;

  final db.AppDatabase _database;
  final SessionStorage _storage;

  DeckRepository({
    required db.AppDatabase database,
    required SessionStorage storage,
  })  : _database = database,
        _storage = storage;

  String _generateId() => _uuid.v4();

  String _newOperationId() => _uuid.v4();

  Future<String> _requireUserId() async {
    final userId = await _storage.readUserId();
    if (userId == null || userId.isEmpty) {
      throw StateError('No signed-in user found.');
    }
    return userId;
  }

  String? _normalizeDescription(String? description) {
    if (description == null) return null;
    final trimmed = description.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Map<String, dynamic> _deckPayload({
    required String id,
    required String userId,
    required String title,
    required String? description,
    required bool isPublic,
    required DateTime createdAt,
    required DateTime updatedAt,
    required int version,
    required bool isDeleted,
  }) {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'description': description,
      'is_public': isPublic,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'version': version,
      'is_deleted': isDeleted,
    };
  }

  Map<String, dynamic> _cardPayload({
    required String id,
    required String deckId,
    required String front,
    required String back,
    required String state,
    required double interval,
    required double easeFactor,
    required int repetitionCount,
    required DateTime? dueTimestamp,
    required DateTime? lastReviewedAt,
    required DateTime createdAt,
    required DateTime updatedAt,
    required int version,
    required bool isDeleted,
  }) {
    return {
      'id': id,
      'deck_id': deckId,
      'front': front,
      'back': back,
      'state': state,
      'interval': interval,
      'ease_factor': easeFactor,
      'repetition_count': repetitionCount,
      'due_timestamp': dueTimestamp?.toUtc().toIso8601String(),
      'last_reviewed_at': lastReviewedAt?.toUtc().toIso8601String(),
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'version': version,
      'is_deleted': isDeleted,
    };
  }

  Future<void> _enqueueSyncOperation({
    required String operationId,
    required String type,
    required String entity,
    required Map<String, dynamic> payload,
    required DateTime createdAt,
  }) async {
    await _database.into(_database.syncQueueItems).insert(
          db.SyncQueueItemsCompanion.insert(
            operationId: operationId,
            type: type,
            entity: entity,
            payload: jsonEncode(payload),
            createdAt: createdAt,
            synced: const Value(false),
          ),
        );
  }

  Future<void> _deleteSyncOperations(List<String> operationIds) async {
    if (operationIds.isEmpty) return;
    await (_database.delete(_database.syncQueueItems)
          ..where((tbl) => tbl.operationId.isIn(operationIds)))
        .go();
  }

  Future<String> createDeckOffline({
    required String title,
    String? description,
    required bool isPublic,
  }) async {
    final userId = await _requireUserId();
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      throw StateError('Deck title cannot be empty.');
    }

    final now = DateTime.now().toUtc();
    final deckId = _generateId();
    final normalizedDescription = _normalizeDescription(description);

    await _database.transaction(() async {
      await _database.into(_database.decks).insert(
            db.DecksCompanion.insert(
              id: deckId,
              userId: userId,
              title: trimmedTitle,
              description: Value(normalizedDescription),
              isPublic: Value(isPublic),
              createdAt: now,
              updatedAt: now,
              version: const Value(1),
              isDeleted: const Value(false),
            ),
          );

      await _enqueueSyncOperation(
        operationId: deckId,
        type: 'create',
        entity: 'deck',
        payload: _deckPayload(
          id: deckId,
          userId: userId,
          title: trimmedTitle,
          description: normalizedDescription,
          isPublic: isPublic,
          createdAt: now,
          updatedAt: now,
          version: 1,
          isDeleted: false,
        ),
        createdAt: now,
      );
    });

    return deckId;
  }

  Future<int> getCardCountForDeck(String deckId) async {
    final cards = await (_database.select(_database.cards)
          ..where(
            (tbl) =>
                tbl.deckId.equals(deckId) & tbl.isDeleted.equals(false),
          ))
        .get();
    return cards.length;
  }

  Future<String> createCardOffline({
    required String deckId,
    required String front,
    required String back,
  }) async {
    final trimmedFront = front.trim();
    final trimmedBack = back.trim();

    if (trimmedFront.isEmpty || trimmedBack.isEmpty) {
      throw StateError('Card front and back are required.');
    }

    final currentUserId = await _requireUserId();

    final deck = await (_database.select(_database.decks)
          ..where(
            (tbl) =>
                tbl.id.equals(deckId) &
                tbl.userId.equals(currentUserId) &
                tbl.isDeleted.equals(false),
          ))
        .getSingleOrNull();

    if (deck == null) {
      throw StateError('Deck not found.');
    }

    final existingCount = await getCardCountForDeck(deckId);
    if (existingCount >= maxCardsPerDeck) {
      throw StateError('A deck can contain at most $maxCardsPerDeck cards.');
    }

    final now = DateTime.now().toUtc();
    final cardId = _generateId();

    await _database.transaction(() async {
      await _database.into(_database.cards).insert(
            db.CardsCompanion.insert(
              id: cardId,
              deckId: deckId,
              front: trimmedFront,
              back: trimmedBack,
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

      await (_database.update(_database.decks)
            ..where((tbl) => tbl.id.equals(deckId)))
          .write(
        db.DecksCompanion(
          updatedAt: Value(now),
          version: Value(deck.version + 1),
        ),
      );

      await _enqueueSyncOperation(
        operationId: cardId,
        type: 'create',
        entity: 'card',
        payload: _cardPayload(
          id: cardId,
          deckId: deckId,
          front: trimmedFront,
          back: trimmedBack,
          state: 'new',
          interval: 0,
          easeFactor: 2.5,
          repetitionCount: 0,
          dueTimestamp: now,
          lastReviewedAt: null,
          createdAt: now,
          updatedAt: now,
          version: 1,
          isDeleted: false,
        ),
        createdAt: now,
      );
    });

    return cardId;
  }

  Future<void> updateDeckOffline({
    required String deckId,
    required String title,
    String? description,
    required bool isPublic,
  }) async {
    final currentUserId = await _requireUserId();
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      throw StateError('Deck title cannot be empty.');
    }

    final deck = await (_database.select(_database.decks)
          ..where(
            (tbl) =>
                tbl.id.equals(deckId) &
                tbl.userId.equals(currentUserId) &
                tbl.isDeleted.equals(false),
          ))
        .getSingleOrNull();
    if (deck == null) {
      throw StateError('Deck not found.');
    }

    final now = DateTime.now().toUtc();
    final nextVersion = deck.version + 1;
    final normalizedDescription = _normalizeDescription(description);

    await _database.transaction(() async {
      await (_database.update(_database.decks)
            ..where((tbl) => tbl.id.equals(deckId)))
          .write(
        db.DecksCompanion(
          title: Value(trimmedTitle),
          description: Value(normalizedDescription),
          isPublic: Value(isPublic),
          updatedAt: Value(now),
          version: Value(nextVersion),
        ),
      );

      await _enqueueSyncOperation(
        operationId: _newOperationId(),
        type: 'update',
        entity: 'deck',
        payload: _deckPayload(
          id: deck.id,
          userId: deck.userId,
          title: trimmedTitle,
          description: normalizedDescription,
          isPublic: isPublic,
          createdAt: deck.createdAt,
          updatedAt: now,
          version: nextVersion,
          isDeleted: false,
        ),
        createdAt: now,
      );
    });
  }

  Future<void> updateCardOffline({
    required String cardId,
    required String front,
    required String back,
  }) async {
    final currentUserId = await _requireUserId();
    final trimmedFront = front.trim();
    final trimmedBack = back.trim();
    if (trimmedFront.isEmpty || trimmedBack.isEmpty) {
      throw StateError('Card front and back are required.');
    }

    final card = await (_database.select(_database.cards)
          ..where(
            (tbl) => tbl.id.equals(cardId) & tbl.isDeleted.equals(false),
          ))
        .getSingleOrNull();
    if (card == null) {
      throw StateError('Card not found.');
    }

    final deck = await (_database.select(_database.decks)
          ..where(
            (tbl) =>
                tbl.id.equals(card.deckId) &
                tbl.userId.equals(currentUserId) &
                tbl.isDeleted.equals(false),
          ))
        .getSingleOrNull();
    if (deck == null) {
      throw StateError('Deck not found.');
    }

    final now = DateTime.now().toUtc();
    final nextVersion = card.version + 1;

    await _database.transaction(() async {
      await (_database.update(_database.cards)
            ..where((tbl) => tbl.id.equals(cardId)))
          .write(
        db.CardsCompanion(
          front: Value(trimmedFront),
          back: Value(trimmedBack),
          updatedAt: Value(now),
          version: Value(nextVersion),
        ),
      );

      await _enqueueSyncOperation(
        operationId: _newOperationId(),
        type: 'update',
        entity: 'card',
        payload: _cardPayload(
          id: card.id,
          deckId: card.deckId,
          front: trimmedFront,
          back: trimmedBack,
          state: card.state,
          interval: card.interval,
          easeFactor: card.easeFactor,
          repetitionCount: card.repetitionCount,
          dueTimestamp: card.dueTimestamp,
          lastReviewedAt: card.lastReviewedAt,
          createdAt: card.createdAt,
          updatedAt: now,
          version: nextVersion,
          isDeleted: false,
        ),
        createdAt: now,
      );
    });
  }

  Future<PendingCardDeletion> markCardDeletedOffline(String cardId) async {
    final currentUserId = await _requireUserId();
    final card = await (_database.select(_database.cards)
          ..where(
            (tbl) => tbl.id.equals(cardId) & tbl.isDeleted.equals(false),
          ))
        .getSingleOrNull();
    if (card == null) {
      throw StateError('Card not found.');
    }

    final deck = await (_database.select(_database.decks)
          ..where(
            (tbl) =>
                tbl.id.equals(card.deckId) &
                tbl.userId.equals(currentUserId) &
                tbl.isDeleted.equals(false),
          ))
        .getSingleOrNull();
    if (deck == null) {
      throw StateError('Deck not found.');
    }

    final now = DateTime.now().toUtc();
    final nextVersion = card.version + 1;
    final operationId = _newOperationId();

    await _database.transaction(() async {
      await (_database.update(_database.cards)
            ..where((tbl) => tbl.id.equals(card.id)))
          .write(
        db.CardsCompanion(
          isDeleted: const Value(true),
          updatedAt: Value(now),
          version: Value(nextVersion),
        ),
      );

      await _enqueueSyncOperation(
        operationId: operationId,
        type: 'delete',
        entity: 'card',
        payload: _cardPayload(
          id: card.id,
          deckId: card.deckId,
          front: card.front,
          back: card.back,
          state: card.state,
          interval: card.interval,
          easeFactor: card.easeFactor,
          repetitionCount: card.repetitionCount,
          dueTimestamp: card.dueTimestamp,
          lastReviewedAt: card.lastReviewedAt,
          createdAt: card.createdAt,
          updatedAt: now,
          version: nextVersion,
          isDeleted: true,
        ),
        createdAt: now,
      );
    });

    return PendingCardDeletion(
      operationId: operationId,
      snapshot: card,
    );
  }

  Future<void> undoCardDeletion(PendingCardDeletion deletion) async {
    final currentUserId = await _requireUserId();
    final deck = await (_database.select(_database.decks)
          ..where(
            (tbl) =>
                tbl.id.equals(deletion.snapshot.deckId) &
                tbl.userId.equals(currentUserId),
          ))
        .getSingleOrNull();
    if (deck == null) {
      throw StateError('Deck not found.');
    }

    final current = await (_database.select(_database.cards)
          ..where((tbl) => tbl.id.equals(deletion.snapshot.id)))
        .getSingleOrNull();

    final now = DateTime.now().toUtc();
    final nextVersion = (current?.version ?? deletion.snapshot.version) + 1;

    await _database.transaction(() async {
      await _deleteSyncOperations([deletion.operationId]);

      await _database.into(_database.cards).insertOnConflictUpdate(
            db.CardsCompanion.insert(
              id: deletion.snapshot.id,
              deckId: deletion.snapshot.deckId,
              front: deletion.snapshot.front,
              back: deletion.snapshot.back,
              state: Value(deletion.snapshot.state),
              interval: Value(deletion.snapshot.interval),
              easeFactor: Value(deletion.snapshot.easeFactor),
              repetitionCount: Value(deletion.snapshot.repetitionCount),
              dueTimestamp: Value(deletion.snapshot.dueTimestamp),
              lastReviewedAt: Value(deletion.snapshot.lastReviewedAt),
              createdAt: deletion.snapshot.createdAt,
              updatedAt: now,
              version: Value(nextVersion),
              isDeleted: const Value(false),
            ),
          );

      await _enqueueSyncOperation(
        operationId: _newOperationId(),
        type: 'update',
        entity: 'card',
        payload: _cardPayload(
          id: deletion.snapshot.id,
          deckId: deletion.snapshot.deckId,
          front: deletion.snapshot.front,
          back: deletion.snapshot.back,
          state: deletion.snapshot.state,
          interval: deletion.snapshot.interval,
          easeFactor: deletion.snapshot.easeFactor,
          repetitionCount: deletion.snapshot.repetitionCount,
          dueTimestamp: deletion.snapshot.dueTimestamp,
          lastReviewedAt: deletion.snapshot.lastReviewedAt,
          createdAt: deletion.snapshot.createdAt,
          updatedAt: now,
          version: nextVersion,
          isDeleted: false,
        ),
        createdAt: now,
      );
    });
  }

  Future<void> finalizeCardDeletion(PendingCardDeletion deletion) async {
    final existing = await (_database.select(_database.cards)
          ..where((tbl) => tbl.id.equals(deletion.snapshot.id)))
        .getSingleOrNull();
    if (existing == null || !existing.isDeleted) {
      return;
    }

    await (_database.delete(_database.cards)
          ..where((tbl) => tbl.id.equals(deletion.snapshot.id)))
        .go();
  }

  Future<PendingDeckDeletion> markDeckDeletedOffline(String deckId) async {
    final currentUserId = await _requireUserId();
    final deck = await (_database.select(_database.decks)
          ..where(
            (tbl) =>
                tbl.id.equals(deckId) &
                tbl.userId.equals(currentUserId) &
                tbl.isDeleted.equals(false),
          ))
        .getSingleOrNull();
    if (deck == null) {
      throw StateError('Deck not found.');
    }

    final activeCards = await (_database.select(_database.cards)
          ..where(
            (tbl) =>
                tbl.deckId.equals(deckId) & tbl.isDeleted.equals(false),
          )
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.createdAt)]))
        .get();

    final now = DateTime.now().toUtc();
    final deckNextVersion = deck.version + 1;
    final deckOperationId = _newOperationId();
    final cardDeleteOperationIds = <String>[];

    await _database.transaction(() async {
      await (_database.update(_database.decks)
            ..where((tbl) => tbl.id.equals(deck.id)))
          .write(
        db.DecksCompanion(
          isDeleted: const Value(true),
          updatedAt: Value(now),
          version: Value(deckNextVersion),
        ),
      );

      await _enqueueSyncOperation(
        operationId: deckOperationId,
        type: 'delete',
        entity: 'deck',
        payload: _deckPayload(
          id: deck.id,
          userId: deck.userId,
          title: deck.title,
          description: deck.description,
          isPublic: deck.isPublic,
          createdAt: deck.createdAt,
          updatedAt: now,
          version: deckNextVersion,
          isDeleted: true,
        ),
        createdAt: now,
      );

      for (final card in activeCards) {
        final nextVersion = card.version + 1;
        final operationId = _newOperationId();
        cardDeleteOperationIds.add(operationId);

        await (_database.update(_database.cards)
              ..where((tbl) => tbl.id.equals(card.id)))
            .write(
          db.CardsCompanion(
            isDeleted: const Value(true),
            updatedAt: Value(now),
            version: Value(nextVersion),
          ),
        );

        await _enqueueSyncOperation(
          operationId: operationId,
          type: 'delete',
          entity: 'card',
          payload: _cardPayload(
            id: card.id,
            deckId: card.deckId,
            front: card.front,
            back: card.back,
            state: card.state,
            interval: card.interval,
            easeFactor: card.easeFactor,
            repetitionCount: card.repetitionCount,
            dueTimestamp: card.dueTimestamp,
            lastReviewedAt: card.lastReviewedAt,
            createdAt: card.createdAt,
            updatedAt: now,
            version: nextVersion,
            isDeleted: true,
          ),
          createdAt: now,
        );
      }
    });

    return PendingDeckDeletion(
      operationId: deckOperationId,
      cardDeleteOperationIds: cardDeleteOperationIds,
      snapshot: deck,
      cardSnapshots: activeCards,
    );
  }

  Future<void> undoDeckDeletion(PendingDeckDeletion deletion) async {
    await _requireUserId();
    final currentDeck = await (_database.select(_database.decks)
          ..where((tbl) => tbl.id.equals(deletion.snapshot.id)))
        .getSingleOrNull();

    final now = DateTime.now().toUtc();
    final deckNextVersion =
        (currentDeck?.version ?? deletion.snapshot.version) + 1;

    await _database.transaction(() async {
      await _deleteSyncOperations([
        deletion.operationId,
        ...deletion.cardDeleteOperationIds,
      ]);

      await _database.into(_database.decks).insertOnConflictUpdate(
            db.DecksCompanion.insert(
              id: deletion.snapshot.id,
              userId: deletion.snapshot.userId,
              title: deletion.snapshot.title,
              description: Value(deletion.snapshot.description),
              isPublic: Value(deletion.snapshot.isPublic),
              createdAt: deletion.snapshot.createdAt,
              updatedAt: now,
              version: Value(deckNextVersion),
              isDeleted: const Value(false),
            ),
          );

      await _enqueueSyncOperation(
        operationId: _newOperationId(),
        type: 'update',
        entity: 'deck',
        payload: _deckPayload(
          id: deletion.snapshot.id,
          userId: deletion.snapshot.userId,
          title: deletion.snapshot.title,
          description: deletion.snapshot.description,
          isPublic: deletion.snapshot.isPublic,
          createdAt: deletion.snapshot.createdAt,
          updatedAt: now,
          version: deckNextVersion,
          isDeleted: false,
        ),
        createdAt: now,
      );

      for (final card in deletion.cardSnapshots) {
        final currentCard = await (_database.select(_database.cards)
              ..where((tbl) => tbl.id.equals(card.id)))
            .getSingleOrNull();
        final nextVersion = (currentCard?.version ?? card.version) + 1;

        await _database.into(_database.cards).insertOnConflictUpdate(
              db.CardsCompanion.insert(
                id: card.id,
                deckId: card.deckId,
                front: card.front,
                back: card.back,
                state: Value(card.state),
                interval: Value(card.interval),
                easeFactor: Value(card.easeFactor),
                repetitionCount: Value(card.repetitionCount),
                dueTimestamp: Value(card.dueTimestamp),
                lastReviewedAt: Value(card.lastReviewedAt),
                createdAt: card.createdAt,
                updatedAt: now,
                version: Value(nextVersion),
                isDeleted: const Value(false),
              ),
            );

        await _enqueueSyncOperation(
          operationId: _newOperationId(),
          type: 'update',
          entity: 'card',
          payload: _cardPayload(
            id: card.id,
            deckId: card.deckId,
            front: card.front,
            back: card.back,
            state: card.state,
            interval: card.interval,
            easeFactor: card.easeFactor,
            repetitionCount: card.repetitionCount,
            dueTimestamp: card.dueTimestamp,
            lastReviewedAt: card.lastReviewedAt,
            createdAt: card.createdAt,
            updatedAt: now,
            version: nextVersion,
            isDeleted: false,
          ),
          createdAt: now,
        );
      }
    });
  }

  Future<void> finalizeDeckDeletion(PendingDeckDeletion deletion) async {
    final existing = await (_database.select(_database.decks)
          ..where((tbl) => tbl.id.equals(deletion.snapshot.id)))
        .getSingleOrNull();
    if (existing == null || !existing.isDeleted) {
      return;
    }

    await _database.transaction(() async {
      await (_database.delete(_database.cards)
            ..where((tbl) => tbl.deckId.equals(deletion.snapshot.id)))
          .go();
      await (_database.delete(_database.decks)
            ..where((tbl) => tbl.id.equals(deletion.snapshot.id)))
          .go();
    });
  }

  Future<List<PublicDeckSummary>> fetchPublicDecks() async {
    final token = await _storage.readToken();
    if (token == null || token.isEmpty) {
      throw StateError('You must be signed in to browse public decks.');
    }

    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/decks/public'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Failed to load public decks (${response.statusCode}): ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      return const [];
    }

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(PublicDeckSummary.fromJson)
        .toList(growable: false);
  }

  Future<String> downloadPublicDeck(String sourceDeckId) async {
    final token = await _storage.readToken();
    if (token == null || token.isEmpty) {
      throw StateError('You must be signed in to download a public deck.');
    }

    final localUserId = await _requireUserId();

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/decks/$sourceDeckId/download'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Failed to download deck (${response.statusCode}): ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('Unexpected server response while downloading deck.');
    }

    final rawDeck = decoded['deck'];
    if (rawDeck is! Map<String, dynamic>) {
      throw StateError('Downloaded deck payload is missing deck details.');
    }

    final rawCards = decoded['cards'];
    if (rawCards is! List) {
      throw StateError('Downloaded deck payload is missing card details.');
    }

    final deckId = rawDeck['id']?.toString();
    if (deckId == null || deckId.isEmpty) {
      throw StateError('Downloaded deck payload is missing deck id.');
    }

    final deckCreatedAt =
        DateTime.tryParse(rawDeck['created_at']?.toString() ?? '')?.toUtc() ??
            DateTime.now().toUtc();
    final deckUpdatedAt =
        DateTime.tryParse(rawDeck['updated_at']?.toString() ?? '')?.toUtc() ??
            deckCreatedAt;

    await _database.transaction(() async {
      await _database.into(_database.decks).insertOnConflictUpdate(
            db.DecksCompanion.insert(
              id: deckId,
              userId: rawDeck['user_id']?.toString() ?? localUserId,
              title: rawDeck['title']?.toString() ?? '',
              description: Value(rawDeck['description']?.toString()),
              isPublic: Value(rawDeck['is_public'] as bool? ?? false),
              createdAt: deckCreatedAt,
              updatedAt: deckUpdatedAt,
              version: Value((rawDeck['version'] as num?)?.toInt() ?? 1),
              isDeleted: Value(rawDeck['is_deleted'] as bool? ?? false),
            ),
          );

      for (final rawCard in rawCards.whereType<Map<String, dynamic>>()) {
        final cardId = rawCard['id']?.toString();
        if (cardId == null || cardId.isEmpty) {
          continue;
        }

        final cardCreatedAt =
            DateTime.tryParse(rawCard['created_at']?.toString() ?? '')
                    ?.toUtc() ??
                deckCreatedAt;
        final cardUpdatedAt =
            DateTime.tryParse(rawCard['updated_at']?.toString() ?? '')
                    ?.toUtc() ??
                cardCreatedAt;
        final dueTimestamp = rawCard['due_timestamp'] != null
            ? DateTime.tryParse(rawCard['due_timestamp'].toString())?.toUtc()
            : null;
        final lastReviewedAt = rawCard['last_reviewed_at'] != null
            ? DateTime.tryParse(rawCard['last_reviewed_at'].toString())
                ?.toUtc()
            : null;

        await _database.into(_database.cards).insertOnConflictUpdate(
              db.CardsCompanion.insert(
                id: cardId,
                deckId: rawCard['deck_id']?.toString() ?? deckId,
                front: rawCard['front']?.toString() ?? '',
                back: rawCard['back']?.toString() ?? '',
                state: Value(rawCard['state']?.toString() ?? 'new'),
                interval: Value((rawCard['interval'] as num?)?.toDouble() ?? 0),
                easeFactor:
                    Value((rawCard['ease_factor'] as num?)?.toDouble() ?? 2.5),
                repetitionCount:
                    Value((rawCard['repetition_count'] as num?)?.toInt() ?? 0),
                dueTimestamp: Value(dueTimestamp),
                lastReviewedAt: Value(lastReviewedAt),
                createdAt: cardCreatedAt,
                updatedAt: cardUpdatedAt,
                version: Value((rawCard['version'] as num?)?.toInt() ?? 1),
                isDeleted: Value(rawCard['is_deleted'] as bool? ?? false),
              ),
            );
      }
    });

    return deckId;
  }

  Stream<List<db.Deck>> watchDecks() async* {
    final currentUserId = await _storage.readUserId();
    if (currentUserId == null || currentUserId.isEmpty) {
      yield const <db.Deck>[];
      return;
    }

    yield* (_database.select(_database.decks)
          ..where(
            (tbl) =>
                tbl.userId.equals(currentUserId) &
                tbl.isDeleted.equals(false),
          )
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.updatedAt)]))
        .watch();
  }

  Stream<db.Deck?> watchDeckById(String deckId) async* {
    final currentUserId = await _storage.readUserId();
    if (currentUserId == null || currentUserId.isEmpty) {
      yield null;
      return;
    }

    yield* (_database.select(_database.decks)
          ..where(
            (tbl) =>
                tbl.id.equals(deckId) &
                tbl.userId.equals(currentUserId) &
                tbl.isDeleted.equals(false),
          ))
        .watchSingleOrNull();
  }

  Stream<List<db.Card>> watchCardsByDeck(String deckId) async* {
    final currentUserId = await _storage.readUserId();
    if (currentUserId == null || currentUserId.isEmpty) {
      yield const <db.Card>[];
      return;
    }

    final deck = await (_database.select(_database.decks)
          ..where(
            (tbl) =>
                tbl.id.equals(deckId) &
                tbl.userId.equals(currentUserId) &
                tbl.isDeleted.equals(false),
          ))
        .getSingleOrNull();

    if (deck == null) {
      yield const <db.Card>[];
      return;
    }

    yield* (_database.select(_database.cards)
          ..where(
            (tbl) =>
                tbl.deckId.equals(deckId) & tbl.isDeleted.equals(false),
          )
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)]))
        .watch();
  }
}
