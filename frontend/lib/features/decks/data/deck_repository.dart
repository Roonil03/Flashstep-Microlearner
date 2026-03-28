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
    database: ref.read(appDatabaseProvider),
    storage: SessionStorage(),
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

class DeckRepository {
  static const int maxCardsPerDeck = 50;

  final db.AppDatabase _database;
  final SessionStorage _storage;

  DeckRepository({
    required db.AppDatabase database,
    required SessionStorage storage,
  })  : _database = database,
        _storage = storage;

  String _generateId() {
    return _uuid.v4();
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

    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      throw StateError('Deck title cannot be empty.');
    }

    final now = DateTime.now().toUtc();
    final deckId = _generateId();
    final normalizedDescription =
        (description == null || description.trim().isEmpty)
            ? null
            : description.trim();

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

      await _database.into(_database.syncQueueItems).insert(
            db.SyncQueueItemsCompanion.insert(
              operationId: deckId,
              type: 'create',
              entity: 'deck',
              payload: jsonEncode({
                'id': deckId,
                'user_id': userId,
                'title': trimmedTitle,
                'description': normalizedDescription,
                'is_public': isPublic,
                'created_at': now.toIso8601String(),
                'updated_at': now.toIso8601String(),
                'version': 1,
                'is_deleted': false,
              }),
              createdAt: now,
              synced: const Value(false),
            ),
          );
    });

    return deckId;
  }

  Future<int> getCardCountForDeck(String deckId) async {
    final cards = await (_database.select(_database.cards)
          ..where((tbl) =>
              tbl.deckId.equals(deckId) & tbl.isDeleted.equals(false)))
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

    final deck = await (_database.select(_database.decks)
          ..where((tbl) =>
              tbl.id.equals(deckId) & tbl.isDeleted.equals(false)))
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

      await _database.into(_database.syncQueueItems).insert(
            db.SyncQueueItemsCompanion.insert(
              operationId: cardId,
              type: 'create',
              entity: 'card',
              payload: jsonEncode({
                'id': cardId,
                'deck_id': deckId,
                'front': trimmedFront,
                'back': trimmedBack,
                'state': 'new',
                'interval': 0,
                'ease_factor': 2.5,
                'repetition_count': 0,
                'due_timestamp': now.toIso8601String(),
                'last_reviewed_at': null,
                'created_at': now.toIso8601String(),
                'updated_at': now.toIso8601String(),
                'version': 1,
                'is_deleted': false,
              }),
              createdAt: now,
              synced: const Value(false),
            ),
          );
    });

    return cardId;
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

    final localUserId = await _storage.readUserId();
    if (localUserId == null || localUserId.isEmpty) {
      throw StateError('No signed-in user found.');
    }

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

  Stream<List<db.Deck>> watchDecks() {
    return (_database.select(_database.decks)
          ..where((tbl) => tbl.isDeleted.equals(false))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.updatedAt)]))
        .watch();
  }

  Stream<db.Deck?> watchDeckById(String deckId) {
    return (_database.select(_database.decks)
          ..where((tbl) =>
              tbl.id.equals(deckId) & tbl.isDeleted.equals(false)))
        .watchSingleOrNull();
  }

  Stream<List<db.Card>> watchCardsByDeck(String deckId) {
    return (_database.select(_database.cards)
          ..where((tbl) =>
              tbl.deckId.equals(deckId) & tbl.isDeleted.equals(false))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)]))
        .watch();
  }
}
