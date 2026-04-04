import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/storage/app_database.dart' as db;
import '../../../core/storage/database_provider.dart';
import '../../../core/storage/session_storage.dart';
import 'review_scheduler.dart';

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  return ReviewRepository(
    database: ref.watch(appDatabaseProvider),
    storage: const SessionStorage(),
  );
});

class ReviewDeckSummary {
  final String deckId;
  final String title;
  final int dueCount;

  const ReviewDeckSummary({
    required this.deckId,
    required this.title,
    required this.dueCount,
  });
}

class ReviewRepository {
  final db.AppDatabase _database;
  final SessionStorage _storage;
  static const _uuid = Uuid();

  ReviewRepository({
    required db.AppDatabase database,
    required SessionStorage storage,
  })  : _database = database,
        _storage = storage;

  String _newId() => _uuid.v4();

  Future<List<ReviewDeckSummary>> getReviewableDecks() async {
    final now = DateTime.now().toUtc();
    final currentUserId = await _storage.readUserId();
    if (currentUserId == null || currentUserId.isEmpty) {
      return [];
    }

    final decks = await (_database.select(_database.decks)
          ..where((tbl) =>
              tbl.userId.equals(currentUserId) &
              tbl.isDeleted.equals(false))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.updatedAt, mode: OrderingMode.desc)]))
        .get();

    final summaries = <ReviewDeckSummary>[];

    for (final deck in decks) {
      final dueCards = await (_database.select(_database.cards)
            ..where((tbl) =>
                tbl.deckId.equals(deck.id) &
                tbl.isDeleted.equals(false) &
                (tbl.dueTimestamp.isNull() | tbl.dueTimestamp.isSmallerOrEqualValue(now)))
            ..orderBy([
              (tbl) => OrderingTerm(expression: tbl.dueTimestamp, mode: OrderingMode.asc),
              (tbl) => OrderingTerm(expression: tbl.updatedAt, mode: OrderingMode.asc),
            ]))
          .get();

      if (dueCards.isEmpty) continue;

      summaries.add(
        ReviewDeckSummary(
          deckId: deck.id,
          title: deck.title,
          dueCount: dueCards.length,
        ),
      );
    }

    return summaries;
  }

  Future<List<db.Card>> getDueCardsForDeck(String deckId) async {
    final now = DateTime.now().toUtc();
    return (_database.select(_database.cards)
          ..where((tbl) =>
              tbl.deckId.equals(deckId) &
              tbl.isDeleted.equals(false) &
              (tbl.dueTimestamp.isNull() | tbl.dueTimestamp.isSmallerOrEqualValue(now)))
          ..orderBy([
            (tbl) => OrderingTerm(expression: tbl.dueTimestamp, mode: OrderingMode.asc),
            (tbl) => OrderingTerm(expression: tbl.updatedAt, mode: OrderingMode.asc),
          ]))
        .get();
  }

  Future<void> applyReview({
    required db.Card card,
    required String rating,
  }) async {
    final now = DateTime.now().toUtc();
    final userId = await _storage.readUserId();
    if (userId == null || userId.isEmpty) {
      throw StateError('No signed-in user found for review logging.');
    }

    String? storedDeviceId = await _storage.readDeviceId();
    if (storedDeviceId == null || storedDeviceId.isEmpty) {
      storedDeviceId = _newId();
      await _storage.writeDeviceId(storedDeviceId);
    }
    final String deviceId = storedDeviceId;


    final reviewLogId = _newId();
    final cardOperationId = _newId();
    final reviewOperationId = _newId();

    final outcome = ReviewScheduler.apply(
      currentState: card.state,
      previousInterval: card.interval,
      previousEaseFactor: card.easeFactor,
      previousRepetitionCount: card.repetitionCount,
      rating: rating,
      now: now,
    );

    await _database.transaction(() async {
      await (_database.update(_database.cards)..where((tbl) => tbl.id.equals(card.id))).write(
        db.CardsCompanion(
          state: Value(outcome.nextState),
          interval: Value(outcome.interval),
          easeFactor: Value(outcome.easeFactor),
          repetitionCount: Value(outcome.repetitionCount),
          dueTimestamp: Value(outcome.dueTimestamp),
          lastReviewedAt: Value(now),
          updatedAt: Value(now),
          version: Value(card.version + 1),
        ),
      );

      await _database.into(_database.reviewLogs).insert(
            db.ReviewLogsCompanion.insert(
              id: reviewLogId,
              userId: userId,
              cardId: card.id,
              rating: rating,
              previousInterval: card.interval,
              newInterval: outcome.interval,
              reviewedAt: now,
              deviceId: deviceId,
              syncStatus: 'pending',
            ),
          );

      await _database.into(_database.syncQueueItems).insert(
            db.SyncQueueItemsCompanion.insert(
              operationId: cardOperationId,
              type: 'update',
              entity: 'card',
              payload: jsonEncode({
                'id': card.id,
                'deck_id': card.deckId,
                'front': card.front,
                'back': card.back,
                'state': outcome.nextState,
                'interval': outcome.interval,
                'ease_factor': outcome.easeFactor,
                'repetition_count': outcome.repetitionCount,
                'due_timestamp': outcome.dueTimestamp.toIso8601String(),
                'last_reviewed_at': now.toIso8601String(),
                'created_at': card.createdAt.toIso8601String(),
                'updated_at': now.toIso8601String(),
                'version': card.version + 1,
                'is_deleted': false,
              }),
              createdAt: now,
              synced: const Value(false),
            ),
          );

      await _database.into(_database.syncQueueItems).insert(
            db.SyncQueueItemsCompanion.insert(
              operationId: reviewOperationId,
              type: 'review',
              entity: 'review_log',
              payload: jsonEncode({
                'id': reviewLogId,
                'user_id': userId,
                'card_id': card.id,
                'rating': rating,
                'previous_interval': card.interval,
                'new_interval': outcome.interval,
                'reviewed_at': now.toIso8601String(),
                'device_id': deviceId,
                'created_at': now.toIso8601String(),
              }),
              createdAt: now,
              synced: const Value(false),
            ),
          );

      // await (_database.update(_database.reviewLogs)..where((tbl) => tbl.id.equals(reviewLogId))).write(
      //   const db.ReviewLogsCompanion(syncStatus: Value('pending')),
      // );
    });
  }
}