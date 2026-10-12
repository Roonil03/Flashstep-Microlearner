import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../../core/storage/app_database.dart' as db;
import '../../../core/storage/database_provider.dart';
import '../../../core/storage/session_storage.dart';
import 'sync_metadata_store.dart';

final deckSyncServiceProvider = Provider<DeckSyncService>((ref) {
  final service = DeckSyncService(
    database: ref.watch(appDatabaseProvider),
    storage: const SessionStorage(),
  );
  ref.onDispose(service.dispose);
  return service;
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

class _SyncSession {
  final String userId, token;
  const _SyncSession(this.userId, this.token);
}

class _PendingGroup {
  final String entity, id;
  final List<String> operations = [];
  String chosen, deckId;
  DateTime updated;
  int version;
  _PendingGroup(
    this.entity,
    this.id,
    this.chosen,
    this.deckId,
    this.updated,
    this.version,
  );
}

class _ProtectedChanges {
  final Set<String> decks = {}, cards = {}, affectedDecks = {};
}

class DeckSyncService {
  final db.AppDatabase _database;
  final SessionStorage _storage;
  final http.Client _client;
  final bool _ownsClient;
  final SyncMetadataStore _metadata;
  final String _baseUrl;
  final Map<String, Future<SyncResult>> _inFlight = {};
  bool _disposed = false;
  DeckSyncService({
    required db.AppDatabase database,
    required SessionStorage storage,
    http.Client? client,
    SyncMetadataStore metadata = const SyncMetadataStore(),
    String? baseUrl,
  }) : _database = database,
       _storage = storage,
       _client = client ?? http.Client(),
       _ownsClient = client == null,
       _metadata = metadata,
       _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  void dispose() {
    _disposed = true;
    if (_ownsClient) _client.close();
  }

  Future<SyncResult> syncNow() async {
    final user = await _storage.readUserId();
    final token = await _storage.readToken();
    if (user == null || user.isEmpty || token == null || token.isEmpty) {
      return const SyncResult.warning(
        'You are not signed in, so sync was skipped.',
      );
    }
    final existing = _inFlight[user];
    if (existing != null) return existing;
    final work = _sync(_SyncSession(user, token));
    _inFlight[user] = work;
    try {
      return await work;
    } finally {
      if (identical(_inFlight[user], work)) _inFlight.remove(user);
    }
  }

  Future<void> _assertActive(_SyncSession session) async {
    if (_disposed ||
        await _storage.readUserId() != session.userId ||
        await _storage.readToken() != session.token) {
      throw StateError('The active account changed; sync was stopped.');
    }
  }

  Future<http.Response> _request(
    _SyncSession session,
    String path, {
    Map<String, dynamic>? payload,
  }) async {
    await _assertActive(session);
    final headers = {
      'Authorization': 'Bearer ${session.token}',
      'Content-Type': 'application/json',
    };
    final uri = Uri.parse('$_baseUrl/$path');
    final response = await (payload == null
            ? _client.get(uri, headers: headers)
            : _client.post(uri, headers: headers, body: jsonEncode(payload)))
        .timeout(const Duration(seconds: 120));
    await _assertActive(session);
    return response;
  }

  void _requireSuccess(http.Response response, String action) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _SyncHttpException(
        statusCode: response.statusCode,
        message:
            '$action failed with status ${response.statusCode}. Your pending changes are retained.',
      );
    }
  }

  Future<SyncResult> _sync(_SyncSession session) async {
    try {
      await _assertActive(session);
      final fingerprints = await _metadata.read(session.userId);
      await _uploadPendingChanges(session, fingerprints);
      await _reconcile(session, fingerprints);
      await _assertActive(session);
      await _storage.writeLastSyncAt(
        DateTime.now().toUtc(),
        userId: session.userId,
      );
      return const SyncResult.success('Sync completed successfully.');
    } on http.ClientException {
      return const SyncResult.warning(
        'Could not reach the server. Pending changes are retained.',
      );
    } on TimeoutException {
      return const SyncResult.warning(
        'Sync timed out. Pending changes are retained; try again when connected.',
      );
    } on _SyncHttpException catch (e) {
      return SyncResult.warning(e.message, statusCode: e.statusCode);
    } catch (e) {
      return SyncResult.warning('Sync failed: $e');
    }
  }

  // Snapshot IDs first, then read payloads in bounded groups. Compact redundant
  // deck/card edits to the newest queued state; every distinct review is kept.
  Future<void> _uploadPendingChanges(
    _SyncSession session,
    Map<String, String> fingerprints,
  ) async {
    final snapshot =
        await _database
            .customSelect(
              'SELECT operation_id FROM sync_queue_items WHERE synced=0 ORDER BY created_at, operation_id',
            )
            .get();
    final groups = <String, _PendingGroup>{};
    for (var offset = 0; offset < snapshot.length; offset += 200) {
      await _assertActive(session);
      final ids =
          snapshot
              .skip(offset)
              .take(200)
              .map((r) => r.read<String>('operation_id'))
              .toList();
      final items =
          await (_database.select(_database.syncQueueItems)
            ..where((t) => t.operationId.isIn(ids))).get();
      for (final item in items) {
        final raw = jsonDecode(item.payload);
        if (raw is! Map<String, dynamic> ||
            !['deck', 'card', 'review_log'].contains(item.entity) ||
            raw['id'] is! String) {
          throw const FormatException(
            'Invalid pending sync operation; no operation was discarded.',
          );
        }
        final id = raw['id'] as String;
        final key = '${item.entity}:$id';
        final updated =
            DateTime.tryParse(
              (raw['updated_at'] ?? raw['created_at'] ?? '').toString(),
            )?.toUtc() ??
            item.createdAt;
        final version = (raw['version'] as num?)?.toInt() ?? 0;
        final deckId =
            item.entity == 'deck' ? id : (raw['deck_id']?.toString() ?? '');
        final group = groups.putIfAbsent(
          key,
          () => _PendingGroup(
            item.entity,
            id,
            item.operationId,
            deckId,
            updated,
            version,
          ),
        );
        group.operations.add(item.operationId);
        if (updated.isAfter(group.updated) ||
            (updated.isAtSameMomentAs(group.updated) &&
                version > group.version)) {
          group.chosen = item.operationId;
          group.updated = updated;
          group.version = version;
          group.deckId = deckId;
        }
      }
    }
    for (final entity in ['deck', 'card', 'review_log']) {
      final ordered =
          groups.values.where((g) => g.entity == entity).toList()..sort((a, b) {
            final time = a.updated.compareTo(b.updated);
            return time != 0 ? time : a.id.compareTo(b.id);
          });
      for (var offset = 0; offset < ordered.length; offset += 200) {
        await _assertActive(session);
        final slice = ordered.skip(offset).take(200).toList();
        final rows =
            await (_database.select(_database.syncQueueItems)..where(
              (t) => t.operationId.isIn(slice.map((g) => g.chosen).toList()),
            )).get();
        final byId = {for (final row in rows) row.operationId: row};
        var batch = <_PendingGroup>[];
        var payloads = <Map<String, dynamic>>[];
        var bytes = 0;
        for (final group in slice) {
          final row = byId[group.chosen];
          if (row == null) continue; // Undo may have removed it.
          final size = utf8.encode(row.payload).length;
          if (batch.isNotEmpty && bytes + size > (1 << 20)) {
            await _sendBatch(session, entity, batch, payloads, fingerprints);
            batch = [];
            payloads = [];
            bytes = 0;
          }
          batch.add(group);
          payloads.add(jsonDecode(row.payload) as Map<String, dynamic>);
          bytes += size;
        }
        if (batch.isNotEmpty)
          await _sendBatch(session, entity, batch, payloads, fingerprints);
      }
    }
  }

  Future<void> _sendBatch(
    _SyncSession session,
    String entity,
    List<_PendingGroup> groups,
    List<Map<String, dynamic>> payloads,
    Map<String, String> fingerprints,
  ) async {
    await _assertActive(session);
    final affected =
        groups.map((g) => g.deckId).where((id) => id.isNotEmpty).toSet();
    if (entity == 'review_log') {
      final cardIds = payloads.map((r) => r['card_id'].toString()).toList();
      final cards =
          await (_database.select(_database.cards)
            ..where((t) => t.id.isIn(cardIds))).get();
      affected.addAll(cards.map((c) => c.deckId));
    }
    for (final id in affected) {
      fingerprints.remove(id);
    }
    // Persist invalidation before acknowledging queue rows, even if a later
    // batch fails or an unchanged server revision rejects a stale local edit.
    await _metadata.write(session.userId, fingerprints);
    final key =
        {
          'deck': 'decks',
          'card': 'cards',
          'review_log': 'review_logs',
        }[entity]!;
    final response = await _request(
      session,
      'sync/upload',
      payload: {'decks': [], 'cards': [], 'review_logs': [], key: payloads},
    );
    _requireSuccess(response, 'Upload');
    await _database.transaction(() async {
      await _assertActive(session);
      final ids = groups.expand((g) => g.operations).toList();
      for (var i = 0; i < ids.length; i += 400) {
        await (_database.delete(_database.syncQueueItems)..where(
          (t) => t.operationId.isIn(ids.skip(i).take(400).toList()),
        )).go();
      }
      if (entity == 'review_log') {
        await (_database.update(_database.reviewLogs)..where(
          (t) => t.id.isIn(groups.map((g) => g.id).toList()),
        )).write(const db.ReviewLogsCompanion(syncStatus: Value('synced')));
      }
      await _assertActive(session);
    });
  }

  Future<_ProtectedChanges> _protectedChanges() async {
    final result = _ProtectedChanges();
    final rows =
        await (_database.select(_database.syncQueueItems)
          ..where((t) => t.synced.equals(false))).get();
    for (final row in rows) {
      final raw = jsonDecode(row.payload) as Map<String, dynamic>;
      final id = raw['id'].toString();
      if (row.entity == 'deck') {
        result.decks.add(id);
        result.affectedDecks.add(id);
      }
      if (row.entity == 'card') {
        result.cards.add(id);
        result.affectedDecks.add(raw['deck_id'].toString());
      }
    }
    return result;
  }

  Future<void> _reconcile(
    _SyncSession session,
    Map<String, String> fingerprints,
  ) async {
    String? cursor;
    final visited = <String>{};
    final seen = <String>{};
    do {
      final suffix =
          cursor == null ? '' : '&cursor=${Uri.encodeComponent(cursor)}';
      final response = await _request(
        session,
        'sync/manifest?limit=500$suffix',
      );
      if (cursor == null &&
          (response.statusCode == 404 || response.statusCode == 405)) {
        await _legacyReconcile(session);
        return;
      }
      _requireSuccess(response, 'Reconciliation');
      final page = jsonDecode(response.body) as Map<String, dynamic>;
      final entries = (page['decks'] as List).cast<Map<String, dynamic>>();
      final ids = entries.map((e) => e['id'] as String).toList();
      final local =
          await (_database.select(_database.decks)
            ..where((t) => t.id.isIn(ids))).get();
      final localIds = local.map((d) => d.id).toSet();
      final changed =
          entries
              .where(
                (e) =>
                    fingerprints[e['id']] != e['fingerprint'] ||
                    !localIds.contains(e['id']),
              )
              .toList();
      seen.addAll(ids);
      for (var offset = 0; offset < changed.length; offset += 25) {
        final group = changed.skip(offset).take(25).toList();
        final deckIds = group.map((e) => e['id'] as String).toList();
        String? cardCursor;
        final cardVisited = <String>{};
        do {
          final fetched = await _request(
            session,
            'sync/fetch',
            payload: {
              'deck_ids': deckIds,
              'limit': 500,
              if (cardCursor != null) 'cursor': cardCursor,
            },
          );
          _requireSuccess(fetched, 'Download');
          final value = jsonDecode(fetched.body) as Map<String, dynamic>;
          final returnedDecks =
              (value['decks'] as List).map((e) => (e as Map)['id']).toSet();
          if (returnedDecks.length != deckIds.length ||
              !returnedDecks.containsAll(deckIds))
            throw const FormatException('Incomplete deck fetch');
          await _mergeDownloadedData(fetched.body, session);
          cardCursor = value['next_cursor'] as String?;
          if (cardCursor != null && !cardVisited.add(cardCursor)) {
            throw const FormatException('Repeated card cursor');
          }
        } while (cardCursor != null);
        final pending = await _protectedChanges();
        for (final entry in group) {
          final id = entry['id'] as String;
          if (pending.affectedDecks.contains(id)) {
            fingerprints.remove(id);
          } else {
            fingerprints[id] = entry['fingerprint'] as String;
          }
        }
        await _assertActive(session);
        await _metadata.write(session.userId, fingerprints);
      }
      cursor = page['next_cursor'] as String?;
      if (cursor != null && !visited.add(cursor)) {
        throw const FormatException('Repeated manifest cursor');
      }
    } while (cursor != null);
    fingerprints.removeWhere((id, _) => !seen.contains(id));
    await _assertActive(session);
    await _metadata.write(session.userId, fingerprints);
  }

  Future<void> _legacyReconcile(_SyncSession session) async {
    final response = await _request(session, 'sync/download');
    _requireSuccess(response, 'Download');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    for (final entity in ['decks', 'cards']) {
      final rows = data[entity] as List;
      for (var offset = 0; offset < rows.length; offset += 500) {
        await _mergeDownloadedData(
          jsonEncode({
            'decks': [],
            'cards': [],
            entity: rows.skip(offset).take(500).toList(),
          }),
          session,
        );
      }
    }
  }

  Future<void> _mergeDownloadedData(String body, _SyncSession session) async {
    final localUserId = session.userId;
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>)
      throw const FormatException('Invalid sync response');

    if (decoded['decks'] is! List || decoded['cards'] is! List)
      throw const FormatException('Missing sync records');
    final remoteDecks = decoded['decks'] as List<dynamic>;
    final remoteCards = decoded['cards'] as List<dynamic>;

    final deckIds =
        remoteDecks.map((e) => (e as Map)['id'].toString()).toList();
    final cardIds =
        remoteCards.map((e) => (e as Map)['id'].toString()).toList();
    await _database.transaction(() async {
      await _assertActive(session);
      final protected = await _protectedChanges();
      final deckWrites = <db.DecksCompanion>[];
      final cardWrites = <db.CardsCompanion>[];
      final localDecks = {
        for (final deck
            in await (_database.select(_database.decks)
              ..where((tbl) => tbl.id.isIn(deckIds))).get())
          deck.id: deck,
      };
      final localCards = {
        for (final card
            in await (_database.select(_database.cards)
              ..where((tbl) => tbl.id.isIn(cardIds))).get())
          card.id: card,
      };
      for (final rawDeck in remoteDecks) {
        if (rawDeck is! Map<String, dynamic>)
          throw const FormatException('Invalid deck');
        final deckId = rawDeck['id']?.toString();
        if (deckId == null || deckId.isEmpty)
          throw const FormatException('Missing deck id');

        final remoteUpdatedAt =
            DateTime.tryParse(
              rawDeck['updated_at']?.toString() ?? '',
            )?.toUtc() ??
            DateTime.now().toUtc();
        final remoteCreatedAt =
            DateTime.tryParse(
              rawDeck['created_at']?.toString() ?? '',
            )?.toUtc() ??
            remoteUpdatedAt;

        if (rawDeck['user_id']?.toString() != localUserId)
          throw const FormatException('Invalid deck owner');
        if (protected.decks.contains(deckId)) continue;
        final localDeck = localDecks[deckId];

        deckWrites.add(
          db.DecksCompanion.insert(
            id: deckId,
            userId: rawDeck['user_id']?.toString() ?? localUserId,
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
        if (rawCard is! Map<String, dynamic>)
          throw const FormatException('Invalid card');
        final cardId = rawCard['id']?.toString();
        if (cardId == null || cardId.isEmpty)
          throw const FormatException('Missing card id');

        final remoteUpdatedAt =
            DateTime.tryParse(
              rawCard['updated_at']?.toString() ?? '',
            )?.toUtc() ??
            DateTime.now().toUtc();
        final remoteCreatedAt =
            DateTime.tryParse(
              rawCard['created_at']?.toString() ?? '',
            )?.toUtc() ??
            remoteUpdatedAt;
        final dueTimestamp =
            rawCard['due_timestamp'] != null
                ? DateTime.tryParse(
                  rawCard['due_timestamp'].toString(),
                )?.toUtc()
                : null;
        final lastReviewedAt =
            rawCard['last_reviewed_at'] != null
                ? DateTime.tryParse(
                  rawCard['last_reviewed_at'].toString(),
                )?.toUtc()
                : null;

        if (protected.cards.contains(cardId) ||
            protected.decks.contains(rawCard['deck_id']?.toString()))
          continue;
        final localCard = localCards[cardId];

        cardWrites.add(
          db.CardsCompanion.insert(
            id: cardId,
            deckId: rawCard['deck_id']?.toString() ?? '',
            front: rawCard['front']?.toString() ?? '',
            back: rawCard['back']?.toString() ?? '',
            state: Value(rawCard['state']?.toString() ?? 'new'),
            interval: Value((rawCard['interval'] as num?)?.toDouble() ?? 0),
            easeFactor: Value(
              (rawCard['ease_factor'] as num?)?.toDouble() ?? 2.5,
            ),
            repetitionCount: Value(
              (rawCard['repetition_count'] as num?)?.toInt() ?? 0,
            ),
            dueTimestamp: Value(dueTimestamp),
            lastReviewedAt: Value(lastReviewedAt),
            createdAt: localCard?.createdAt ?? remoteCreatedAt,
            updatedAt: remoteUpdatedAt,
            version: Value((rawCard['version'] as num?)?.toInt() ?? 1),
            isDeleted: Value(rawCard['is_deleted'] as bool? ?? false),
          ),
        );
      }
      await _database.batch((batch) {
        batch.insertAllOnConflictUpdate(_database.decks, deckWrites);
        batch.insertAllOnConflictUpdate(_database.cards, cardWrites);
      });
      await _assertActive(session);
    });
  }
}

class _SyncHttpException implements Exception {
  final int statusCode;
  final String message;
  const _SyncHttpException({required this.statusCode, required this.message});
  @override
  String toString() => message;
}
