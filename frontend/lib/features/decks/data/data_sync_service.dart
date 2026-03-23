import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../../core/storage/app_database.dart' as db;
import '../../../core/storage/database_provider.dart';
import '../../../core/storage/session_storage.dart';

final deckSyncServiceProvider = Provider<DeckSyncService>((ref) {
  return DeckSyncService(
    database: ref.read(appDatabaseProvider),
    storage: const SessionStorage(),
  );
});

class SyncResult {
  final bool success;
  final bool warning;
  final int? statusCode;
  final String message;

  const SyncResult.success(this.message)
      : success = true,
        warning = false,
        statusCode = 200;

  const SyncResult.warning(this.message, {this.statusCode})
      : success = false,
        warning = true;
}

class DeckSyncService {
  final db.AppDatabase _database;
  final SessionStorage _storage;

  DeckSyncService({
    required db.AppDatabase database,
    required SessionStorage storage,
  })  : _database = database,
        _storage = storage;

  Future<SyncResult> syncNow() async {
    final token = await _storage.readToken();
    if (token == null || token.isEmpty) {
      return const SyncResult.warning('You are not signed in, so sync was skipped.');
    }

    try {
      await _uploadPendingChanges(token);
      await _downloadAndMergeChanges(token);
      await _storage.writeLastSyncAt(DateTime.now().toUtc());
      return const SyncResult.success('Sync completed successfully.');
    } on http.ClientException catch (e) {
      return SyncResult.warning('Could not reach the server: $e');
    } on _SyncHttpException catch (e) {
      return SyncResult.warning(e.message, statusCode: e.statusCode);
    } catch (e) {
      return SyncResult.warning('Sync failed: $e');
    }
  }

  Future<void> _uploadPendingChanges(String token) async {
    final pending = await (_database.select(_database.syncQueueItems)
          ..where((tbl) => tbl.synced.equals(false))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.createdAt, mode: OrderingMode.asc)]))
        .get();

    if (pending.isEmpty) return;

    final decksPayload = <Map<String, dynamic>>[];
    final cardsPayload = <Map<String, dynamic>>[];
    final reviewLogsPayload = <Map<String, dynamic>>[];
    final uploadedOperationIds = <String>[];

    for (final item in pending) {
      final decoded = jsonDecode(item.payload);
      if (decoded is! Map<String, dynamic>) continue;

      switch (item.entity) {
        case 'deck':
          decksPayload.add(decoded);
          uploadedOperationIds.add(item.operationId);
          break;
        case 'card':
          cardsPayload.add(decoded);
          uploadedOperationIds.add(item.operationId);
          break;
        case 'review_log':
          reviewLogsPayload.add(decoded);
          uploadedOperationIds.add(item.operationId);
          break;
      }
    }

    if (decksPayload.isEmpty && cardsPayload.isEmpty && reviewLogsPayload.isEmpty) {
      return;
    }

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/sync/upload'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'decks': decksPayload,
        'cards': cardsPayload,
        'review_logs': reviewLogsPayload,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _SyncHttpException(
        statusCode: response.statusCode,
        message: 'Upload failed with status ${response.statusCode}: ${response.body}',
      );
    }

    if (uploadedOperationIds.isNotEmpty) {
      await (_database.delete(_database.syncQueueItems)
            ..where((tbl) => tbl.operationId.isIn(uploadedOperationIds)))
          .go();
    }

    if (reviewLogsPayload.isNotEmpty) {
      final ids = reviewLogsPayload.map((e) => e['id']?.toString()).whereType<String>().toList();
      if (ids.isNotEmpty) {
        await (_database.update(_database.reviewLogs)..where((tbl) => tbl.id.isIn(ids))).write(
          const db.ReviewLogsCompanion(syncStatus: Value('synced')),
        );
      }
    }
  }

  Future<void> _downloadAndMergeChanges(String token) async {
    final since = await _storage.readLastSyncAt() ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/sync/download?since=${Uri.encodeComponent(since.toUtc().toIso8601String())}',
    );

    final response = await http.get(uri, headers: {'Authorization': 'Bearer $token'});

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _SyncHttpException(
        statusCode: response.statusCode,
        message: 'Download failed with status ${response.statusCode}: ${response.body}',
      );
    }

    await _mergeDownloadedData(response.body);
  }

  Future<void> _mergeDownloadedData(String body) async {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) return;

    final localUserId = await _storage.readUserId() ?? '';
    final remoteDecks = (decoded['decks'] as List<dynamic>? ?? const []);
    final remoteCards = (decoded['cards'] as List<dynamic>? ?? const []);

    await _database.transaction(() async {
      for (final rawDeck in remoteDecks) {
        if (rawDeck is! Map<String, dynamic>) continue;
        final deckId = rawDeck['id']?.toString();
        if (deckId == null || deckId.isEmpty) continue;

        final remoteUpdatedAt = DateTime.tryParse(rawDeck['updated_at']?.toString() ?? '')?.toUtc() ?? DateTime.now().toUtc();
        final remoteCreatedAt = DateTime.tryParse(rawDeck['created_at']?.toString() ?? '')?.toUtc() ?? remoteUpdatedAt;

        final localDeck = await (_database.select(_database.decks)..where((tbl) => tbl.id.equals(deckId))).getSingleOrNull();
        if (localDeck != null && localDeck.updatedAt.isAfter(remoteUpdatedAt)) continue;

        await _database.into(_database.decks).insertOnConflictUpdate(
              db.DecksCompanion.insert(
                id: deckId,
                userId: rawDeck['user_id']?.toString() ?? localDeck?.userId ?? localUserId,
                title: rawDeck['title']?.toString() ?? '',
                description: Value(rawDeck['description']?.toString()),
                isPublic: Value(rawDeck['is_public'] as bool? ?? false),
                createdAt: localDeck?.createdAt ?? remoteCreatedAt,
                updatedAt: remoteUpdatedAt,
                version: Value((rawDeck['version'] as num?)?.toInt() ?? 1),
                isDeleted: Value(rawDeck['is_deleted'] as bool? ?? false),
              ),
            );
      }

      for (final rawCard in remoteCards) {
        if (rawCard is! Map<String, dynamic>) continue;
        final cardId = rawCard['id']?.toString();
        if (cardId == null || cardId.isEmpty) continue;

        final remoteUpdatedAt = DateTime.tryParse(rawCard['updated_at']?.toString() ?? '')?.toUtc() ?? DateTime.now().toUtc();
        final remoteCreatedAt = DateTime.tryParse(rawCard['created_at']?.toString() ?? '')?.toUtc() ?? remoteUpdatedAt;
        final dueTimestamp = rawCard['due_timestamp'] != null ? DateTime.tryParse(rawCard['due_timestamp'].toString())?.toUtc() : null;
        final lastReviewedAt = rawCard['last_reviewed_at'] != null ? DateTime.tryParse(rawCard['last_reviewed_at'].toString())?.toUtc() : null;

        final localCard = await (_database.select(_database.cards)..where((tbl) => tbl.id.equals(cardId))).getSingleOrNull();
        if (localCard != null && localCard.updatedAt.isAfter(remoteUpdatedAt)) continue;

        await _database.into(_database.cards).insertOnConflictUpdate(
              db.CardsCompanion.insert(
                id: cardId,
                deckId: rawCard['deck_id']?.toString() ?? '',
                front: rawCard['front']?.toString() ?? '',
                back: rawCard['back']?.toString() ?? '',
                state: Value(rawCard['state']?.toString() ?? 'new'),
                interval: Value((rawCard['interval'] as num?)?.toDouble() ?? 0),
                easeFactor: Value((rawCard['ease_factor'] as num?)?.toDouble() ?? 2.5),
                repetitionCount: Value((rawCard['repetition_count'] as num?)?.toInt() ?? 0),
                dueTimestamp: Value(dueTimestamp),
                lastReviewedAt: Value(lastReviewedAt),
                createdAt: localCard?.createdAt ?? remoteCreatedAt,
                updatedAt: remoteUpdatedAt,
                version: Value((rawCard['version'] as num?)?.toInt() ?? 1),
                isDeleted: Value(rawCard['is_deleted'] as bool? ?? false),
              ),
            );
      }
    });
  }
}

class _SyncHttpException implements Exception {
  final int statusCode;
  final String message;

  _SyncHttpException({required this.statusCode, required this.message});

  @override
  String toString() => message;
}