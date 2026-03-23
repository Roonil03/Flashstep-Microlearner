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

class DeckSyncService {
  final db.AppDatabase _database;
  final SessionStorage _storage;

  DeckSyncService({
    required db.AppDatabase database,
    required SessionStorage storage,
  })  : _database = database,
        _storage = storage;

  Future<void> syncNow() async {
    final token = await _storage.readToken();
    if (token == null || token.isEmpty) return;

    final since = await _storage.readLastSyncAt() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

    final downloadUri = Uri.parse(
      '${ApiConfig.baseUrl}/sync/download?since=${Uri.encodeComponent(since.toUtc().toIso8601String())}',
    );

    try {
      final downloadResponse = await http.get(
        downloadUri,
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (downloadResponse.statusCode >= 200 && downloadResponse.statusCode < 300) {
        await _mergeDownloadedData(downloadResponse.body);
      }

      final pending = await (_database.select(_database.syncQueueItems)
            ..where((tbl) => tbl.synced.equals(false)))
          .get();

      final decksPayload = <Map<String, dynamic>>[];
      final cardsPayload = <Map<String, dynamic>>[];

      for (final item in pending) {
        final decoded = jsonDecode(item.payload);
        if (decoded is! Map<String, dynamic>) continue;

        if (item.entity == 'deck') {
          decksPayload.add(decoded);
        } else if (item.entity == 'card') {
          cardsPayload.add(decoded);
        }
      }

      if (decksPayload.isNotEmpty || cardsPayload.isNotEmpty) {
        final uploadResponse = await http.post(
          Uri.parse('${ApiConfig.baseUrl}/sync/upload'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'decks': decksPayload,
            'cards': cardsPayload,
          }),
        );

        if (uploadResponse.statusCode >= 200 && uploadResponse.statusCode < 300) {
          final ids = pending.map((e) => e.operationId).toList();
          await (_database.delete(_database.syncQueueItems)
                ..where((tbl) => tbl.operationId.isIn(ids)))
              .go();
        }
      }

      await _storage.writeLastSyncAt(DateTime.now().toUtc());
    } catch (_) {
      return;
    }
  }

  Future<void> _mergeDownloadedData(String body) async {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) return;

    final userId = await _storage.readUserId() ?? '';
    final remoteDecks = (decoded['decks'] as List<dynamic>? ?? const []);
    final remoteCards = (decoded['cards'] as List<dynamic>? ?? const []);

    await _database.transaction(() async {
      for (final rawDeck in remoteDecks) {
        if (rawDeck is! Map<String, dynamic>) continue;

        final remoteId = rawDeck['id']?.toString();
        if (remoteId == null || remoteId.isEmpty) continue;

        final remoteUpdatedAt =
            DateTime.tryParse(rawDeck['updated_at']?.toString() ?? '') ??
                DateTime.now().toUtc();

        final remoteCreatedAt =
            DateTime.tryParse(rawDeck['created_at']?.toString() ?? '') ??
                remoteUpdatedAt;

        final local = await (_database.select(_database.decks)
              ..where((tbl) => tbl.id.equals(remoteId)))
            .getSingleOrNull();

        if (local != null && local.updatedAt.isAfter(remoteUpdatedAt)) {
          continue;
        }

        await _database.into(_database.decks).insertOnConflictUpdate(
              db.DecksCompanion.insert(
                id: remoteId,
                userId: rawDeck['user_id']?.toString() ?? local?.userId ?? userId,
                title: rawDeck['title']?.toString() ?? '',
                description: Value(rawDeck['description']?.toString()),
                isPublic: Value(rawDeck['is_public'] as bool? ?? false),
                createdAt: local?.createdAt ?? remoteCreatedAt,
                updatedAt: remoteUpdatedAt,
                version: Value((rawDeck['version'] as num?)?.toInt() ?? 1),
                isDeleted: Value(rawDeck['is_deleted'] as bool? ?? false),
              ),
            );
      }

      for (final rawCard in remoteCards) {
        if (rawCard is! Map<String, dynamic>) continue;

        final remoteId = rawCard['id']?.toString();
        if (remoteId == null || remoteId.isEmpty) continue;

        final remoteUpdatedAt =
            DateTime.tryParse(rawCard['updated_at']?.toString() ?? '') ??
                DateTime.now().toUtc();

        final remoteCreatedAt =
            DateTime.tryParse(rawCard['created_at']?.toString() ?? '') ??
                remoteUpdatedAt;

        final dueTimestamp = rawCard['due_timestamp'] != null
            ? DateTime.tryParse(rawCard['due_timestamp'].toString())
            : null;

        final lastReviewedAt = rawCard['last_reviewed_at'] != null
            ? DateTime.tryParse(rawCard['last_reviewed_at'].toString())
            : null;

        final local = await (_database.select(_database.cards)
              ..where((tbl) => tbl.id.equals(remoteId)))
            .getSingleOrNull();

        if (local != null && local.updatedAt.isAfter(remoteUpdatedAt)) {
          continue;
        }

        await _database.into(_database.cards).insertOnConflictUpdate(
              db.CardsCompanion.insert(
                id: remoteId,
                deckId: rawCard['deck_id']?.toString() ?? '',
                front: rawCard['front']?.toString() ?? '',
                back: rawCard['back']?.toString() ?? '',
                state: Value(rawCard['state']?.toString() ?? 'new'),
                interval: Value((rawCard['interval'] as num?)?.toDouble() ?? 0),
                easeFactor: Value((rawCard['ease_factor'] as num?)?.toDouble() ?? 2.5),
                repetitionCount: Value((rawCard['repetition_count'] as num?)?.toInt() ?? 0),
                dueTimestamp: Value(dueTimestamp),
                lastReviewedAt: Value(lastReviewedAt),
                createdAt: local?.createdAt ?? remoteCreatedAt,
                updatedAt: remoteUpdatedAt,
                version: Value((rawCard['version'] as num?)?.toInt() ?? 1),
                isDeleted: Value(rawCard['is_deleted'] as bool? ?? false),
              ),
            );
      }
    });
  }
}