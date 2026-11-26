import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../../core/network/api_errors.dart';
import '../../../core/storage/app_database.dart' as db;
import '../../../core/storage/database_provider.dart';
import '../../../core/storage/session_storage.dart';
import 'sync_metadata_store.dart';
import 'sync_status.dart';

final deckSyncServiceProvider = Provider<DeckSyncService>((ref) {
  final service = DeckSyncService(
    database: ref.watch(appDatabaseProvider),
    storage: const SessionStorage(),
    status: ref.read(syncStatusProvider.notifier),
  );
  ref.onDispose(service.dispose);
  return service;
});

class SyncResult {
  final bool success;
  final bool warning;
  final int? statusCode;
  final String message;
  final bool offline;
  const SyncResult.success(this.message)
    : success = true,
      warning = false,
      offline = false,
      statusCode = 200;
  const SyncResult.warning(
    this.message, {
    this.statusCode,
    this.offline = false,
  }) : success = false,
       warning = true;
}

class _SyncSession {
  final String userId, token;
  final int metadataRevision;
  const _SyncSession(this.userId, this.token, this.metadataRevision);
}

class _PendingGroup {
  final String entity, id;
  final List<String> operations = [];
  String chosen, deckId;
  DateTime updated;
  int version;
  bool allowCreate = false;
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
  final Set<String> decks = {},
      cards = {},
      affectedDecks = {},
      newCardDecks = {};
}

class DeckSyncService {
  final db.AppDatabase _database;
  final SessionStorage _storage;
  final http.Client _client;
  final bool _ownsClient;
  final SyncMetadataStore _metadata;
  final String _baseUrl;
  final SyncStatusNotifier? _status;
  static final _databaseSyncs = Expando<Map<String, Future<SyncResult>>>();
  Map<String, Future<SyncResult>> get _inFlight =>
      _databaseSyncs[_database] ??= {};
  bool _disposed = false;
  DeckSyncService({
    required db.AppDatabase database,
    required SessionStorage storage,
    http.Client? client,
    SyncMetadataStore metadata = const SyncMetadataStore(),
    String? baseUrl,
    SyncStatusNotifier? status,
  }) : _database = database,
       _storage = storage,
       _client = client ?? http.Client(),
       _ownsClient = client == null,
       _metadata = metadata,
       _status = status,
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
    return _syncNow(_SyncSession(user, token, _metadata.revision(user)));
  }

  /// Include a completed local mutation even when an older sync has already
  /// snapshotted its queue or skipped an operation held for Undo.
  Future<SyncResult> syncAfterLocalChange() async {
    final user = await _storage.readUserId();
    final token = await _storage.readToken();
    if (user == null || user.isEmpty || token == null || token.isEmpty) {
      return const SyncResult.warning(
        'You are not signed in, so sync was skipped.',
      );
    }
    final session = _SyncSession(user, token, _metadata.revision(user));
    try {
      final older = _inFlight[user];
      if (older != null) {
        await older;
        if (identical(_inFlight[user], older)) _inFlight.remove(user);
      }
      await _assertActive(session);
      return _syncNow(session);
    } catch (_) {
      return const SyncResult.warning(
        'Sync could not finish. Pending changes are retained; please retry.',
      );
    }
  }

  Future<SyncResult> _syncNow(_SyncSession session) async {
    final user = session.userId;
    final existing = _inFlight[user];
    if (existing != null) return existing;
    _status?.start(user);
    final work = _sync(session);
    _inFlight[user] = work;
    try {
      final result = await work;
      _status?.finish(
        user,
        success: result.success,
        offline: result.offline,
        message: result.message,
        statusCode: result.statusCode,
      );
      return result;
    } finally {
      if (identical(_inFlight[user], work)) _inFlight.remove(user);
    }
  }

  Future<void> reportNoNetwork() async {
    final user = await _storage.readUserId();
    if (user != null && user.isNotEmpty) _status?.offline(user);
  }

  Future<void> _assertActive(_SyncSession session) async {
    if (_disposed ||
        (_database.databaseFileName != ':memory:' &&
            _database.databaseFileName !=
                db.AppDatabase.fileNameForUser(session.userId)) ||
        _metadata.revision(session.userId) != session.metadataRevision ||
        await _storage.readUserId() != session.userId ||
        await _storage.readToken() != session.token) {
      throw StateError('The active account changed; sync was stopped.');
    }
  }

  Future<http.Response> _request(
    _SyncSession session,
    String path, {
    Map<String, dynamic>? payload,
    void Function()? beforeSend,
  }) async {
    await _assertActive(session);
    beforeSend?.call();
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
            '$action could not finish. ${apiErrorMessage(response)} '
            'Your pending changes are retained.',
      );
    }
  }

  Future<SyncResult> _sync(_SyncSession session) async {
    try {
      await _assertActive(session);
      final fingerprints = await _metadata.read(session.userId);
      final rejected = await _uploadPendingChanges(session, fingerprints);
      await _reconcile(session, fingerprints);
      await _assertActive(session);
      final pending =
          await (_database.select(_database.syncQueueItems)
            ..where((t) => t.synced.equals(false))).get();
      if (rejected > 0 ||
          pending.isNotEmpty ||
          _database.heldDeckDeletions.isNotEmpty ||
          _database.heldCardDeletions.isNotEmpty) {
        return SyncResult.warning(
          'Some changes remain on this device. Finish any Undo action and retry sync. Content or reviews whose parent no longer exists need attention.',
        );
      }
      await _storage.writeLastSyncAt(
        DateTime.now().toUtc(),
        userId: session.userId,
      );
      return const SyncResult.success('Sync completed successfully.');
    } on SocketException {
      return const SyncResult.warning(
        'Could not reach the server. Pending changes are retained.',
        offline: true,
      );
    } on http.ClientException {
      return const SyncResult.warning(
        'Could not reach the server. Pending changes are retained.',
        offline: true,
      );
    } on TimeoutException {
      return const SyncResult.warning(
        'Sync timed out. Pending changes are retained; try again when connected.',
      );
    } on _SyncHttpException catch (e) {
      return SyncResult.warning(e.message, statusCode: e.statusCode);
    } catch (_) {
      return const SyncResult.warning(
        'Sync could not finish. Pending changes are retained; please retry.',
      );
    }
  }

  // Snapshot IDs first, then read payloads in bounded groups. Compact redundant
  // deck/card edits to the newest queued state; every distinct review is kept.
  Future<int> _uploadPendingChanges(
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
    var rejected = 0;
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
        final raw = _pendingPayload(item.payload);
        if (raw == null ||
            !['deck', 'card', 'review_log'].contains(item.entity) ||
            raw['id'] is! String) {
          rejected++;
          continue;
        }
        final id = raw['id'] as String;
        final key = '${item.entity}:$id';
        final updated =
            DateTime.tryParse(
              (raw['updated_at'] ?? raw['created_at'] ?? '').toString(),
            )?.toUtc() ??
            item.createdAt;
        final version =
            raw['version'] is num ? (raw['version'] as num).toInt() : 0;
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
        group.allowCreate |= item.type == 'create';
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
            rejected += await _sendBatch(
              session,
              entity,
              batch,
              payloads,
              fingerprints,
            );
            batch = [];
            payloads = [];
            bytes = 0;
          }
          batch.add(group);
          payloads.add(jsonDecode(row.payload) as Map<String, dynamic>);
          bytes += size;
        }
        if (batch.isNotEmpty) {
          rejected += await _sendBatch(
            session,
            entity,
            batch,
            payloads,
            fingerprints,
          );
        }
      }
    }
    return rejected;
  }

  Future<int> _sendBatch(
    _SyncSession session,
    String entity,
    List<_PendingGroup> groups,
    List<Map<String, dynamic>> payloads,
    Map<String, String> fingerprints,
  ) async {
    await _assertActive(session);
    final operations = groups.expand((g) => g.operations).toList();
    final liveRows = <db.SyncQueueItem>[];
    for (var offset = 0; offset < operations.length; offset += 400) {
      liveRows.addAll(
        await (_database.select(_database.syncQueueItems)..where(
          (t) => t.operationId.isIn(operations.skip(offset).take(400).toList()),
        )).get(),
      );
    }
    final liveOperations = liveRows.map((r) => r.operationId).toSet();
    for (final group in groups) {
      group.allowCreate = liveRows.any(
        (r) => group.operations.contains(r.operationId) && r.type == 'create',
      );
    }
    final holds = _deletionHolds();
    final reviewParents = <String, String>{};
    if (entity == 'review_log') {
      final cards =
          await (_database.select(_database.cards)..where(
            (t) => t.id.isIn(
              payloads.map((p) => p['card_id'].toString()).toList(),
            ),
          )).get();
      reviewParents.addAll({for (final card in cards) card.id: card.deckId});
    }
    bool held(int index) {
      final group = groups[index];
      final cardId =
          entity == 'review_log'
              ? payloads[index]['card_id']?.toString()
              : group.id;
      final deckId =
          entity == 'review_log' ? reviewParents[cardId] : group.deckId;
      return holds.decks.contains(deckId) ||
          _database.heldDeckDeletions.contains(deckId) ||
          ((entity == 'card' || entity == 'review_log') &&
              (holds.cards.contains(cardId) ||
                  _database.heldCardDeletions.contains(cardId)));
    }

    void filterHeld() {
      final keep = <int>[
        for (var i = 0; i < groups.length; i++)
          if (liveOperations.contains(groups[i].chosen) && !held(i)) i,
      ];
      payloads =
          keep
              .map(
                (i) => <String, dynamic>{
                  ...payloads[i],
                  if (entity != 'review_log')
                    'allow_create': groups[i].allowCreate,
                },
              )
              .toList();
      groups = keep.map((i) => groups[i]).toList();
    }

    filterHeld();
    if (groups.isEmpty) return 0;
    if (groups.length == 1 &&
        utf8.encode(jsonEncode(payloads.single)).length > (4 << 20) - 128) {
      return 1;
    }
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
    await _metadata.write(
      session.userId,
      fingerprints,
      expectedRevision: session.metadataRevision,
    );
    final key =
        {
          'deck': 'decks',
          'card': 'cards',
          'review_log': 'review_logs',
        }[entity]!;
    final upload = <String, dynamic>{
      'reconciliation_version': 1,
      'decks': [],
      'cards': [],
      'review_logs': [],
      key: payloads,
    };
    late http.Response response;
    try {
      response = await _request(
        session,
        'sync/upload',
        payload: upload,
        beforeSend: () {
          // A deletion can finish during account/storage awaits above.
          // Check live Undo holds immediately before the HTTP call.
          filterHeld();
          if (groups.isEmpty) throw const _DeferredSyncChanges();
          upload[key] = payloads;
        },
      );
    } on _DeferredSyncChanges {
      return 0;
    }
    // Validation is atomic server-side. Bisect only input/size failures so one
    // historical or malformed operation cannot hold unrelated changes hostage.
    if ([400, 413, 422].contains(response.statusCode)) {
      if (groups.length == 1) return 1;
      final middle = groups.length ~/ 2;
      return await _sendBatch(
            session,
            entity,
            groups.sublist(0, middle),
            payloads.sublist(0, middle),
            fingerprints,
          ) +
          await _sendBatch(
            session,
            entity,
            groups.sublist(middle),
            payloads.sublist(middle),
            fingerprints,
          );
    }
    _requireSuccess(response, 'Upload');
    final result = jsonDecode(response.body) as Map<String, dynamic>;
    final missingDecks = _responseIds(result, 'missing_deck_ids');
    final missingCards = _responseIds(result, 'missing_card_ids');
    final missingReviews = _responseIds(result, 'missing_review_log_ids');
    final retained = <String>{};
    for (final group in groups) {
      final missing =
          entity == 'deck'
              ? missingDecks.contains(group.id)
              : entity == 'card'
              ? missingCards.contains(group.id) ||
                  missingDecks.contains(group.deckId)
              : missingReviews.contains(group.id);
      if (missing && (group.allowCreate || entity == 'review_log')) {
        retained.add(group.id);
      }
    }
    await _database.transaction(() async {
      await _assertActive(session);
      final acknowledged =
          groups.where((g) => !retained.contains(g.id)).toList();
      final ids = acknowledged.expand((g) => g.operations).toList();
      for (var i = 0; i < ids.length; i += 400) {
        await (_database.delete(_database.syncQueueItems)..where(
          (t) => t.operationId.isIn(ids.skip(i).take(400).toList()),
        )).go();
      }
      if (entity == 'review_log') {
        await (_database.update(_database.reviewLogs)..where(
          (t) => t.id.isIn(acknowledged.map((g) => g.id).toList()),
        )).write(const db.ReviewLogsCompanion(syncStatus: Value('synced')));
      }
      await _markAbsent(session, deckIds: missingDecks, cardIds: missingCards);
      await _assertActive(session);
    });
    return retained.length;
  }

  Set<String> _responseIds(Map<String, dynamic> value, String key) {
    final ids = value[key];
    if (ids == null) return {};
    if (ids is! List || ids.any((id) => id is! String)) {
      throw FormatException('Invalid missing record IDs');
    }
    return ids.cast<String>().toSet();
  }

  // Only a visible Undo action delays upload. Once finalized or restarted,
  // the server starts its retention window when it accepts the tombstone.
  _ProtectedChanges _deletionHolds() {
    final holds = _ProtectedChanges();
    holds.decks.addAll(_database.heldDeckDeletions);
    holds.cards.addAll(_database.heldCardDeletions);
    return holds;
  }

  Map<String, dynamic>? _pendingPayload(String payload) {
    try {
      final raw = jsonDecode(payload);
      return raw is Map<String, dynamic> ? raw : null;
    } on FormatException {
      return null;
    }
  }

  Future<_ProtectedChanges> _protectedChanges() async {
    final result = _deletionHolds();
    result.affectedDecks.addAll(result.decks);
    final newCardIds = <String>{};
    final rows =
        await (_database.select(_database.syncQueueItems)
          ..where((t) => t.synced.equals(false))).get();
    for (final row in rows) {
      final raw = _pendingPayload(row.payload);
      if (raw == null) continue;
      final id = raw['id'].toString();
      if (row.entity == 'deck') {
        result.decks.add(id);
        result.affectedDecks.add(id);
      }
      if (row.entity == 'card') {
        result.cards.add(id);
        result.affectedDecks.add(raw['deck_id'].toString());
        if (row.type == 'create') newCardIds.add(id);
      }
    }
    // Keep unacknowledged new content reachable when its existing parent was
    // deleted elsewhere. A later local deletion must still hide that content.
    final ids = newCardIds.toList();
    for (var offset = 0; offset < ids.length; offset += 400) {
      final cards =
          await (_database.select(_database.cards)..where(
            (t) =>
                t.id.isIn(ids.skip(offset).take(400).toList()) &
                t.isDeleted.equals(false),
          )).get();
      result.newCardDecks.addAll(cards.map((card) => card.deckId));
    }
    return result;
  }

  Future<void> _markAbsent(
    _SyncSession session, {
    Set<String> deckIds = const {},
    Set<String> cardIds = const {},
  }) async {
    final pending = await _protectedChanges();
    final absentDecks = deckIds
        .difference(pending.affectedDecks)
        .difference(pending.decks);
    final cards =
        await (_database.select(_database.cards)..where(
          (t) =>
              t.id.isIn(cardIds.toList()) | t.deckId.isIn(absentDecks.toList()),
        )).get();
    final absentCards =
        cards
            .where(
              (c) =>
                  !pending.cards.contains(c.id) &&
                  !pending.decks.contains(c.deckId),
            )
            .map((c) => c.id)
            .toList();
    await _assertActive(session);
    for (var offset = 0; offset < absentCards.length; offset += 400) {
      await (_database.update(_database.cards)..where(
        (t) => t.id.isIn(absentCards.skip(offset).take(400).toList()),
      )).write(const db.CardsCompanion(isDeleted: Value(true)));
    }
    for (final id in absentDecks) {
      await (_database.update(_database.decks)..where(
        (t) => t.id.equals(id) & t.userId.equals(session.userId),
      )).write(const db.DecksCompanion(isDeleted: Value(true)));
    }
    await _assertActive(session);
  }

  Future<void> _reconcile(
    _SyncSession session,
    Map<String, String> fingerprints,
  ) async {
    String? cursor;
    String? reviewsFingerprint;
    var authoritative = true;
    final visited = <String>{};
    final seen = <String>{};
    final disappeared = <String>{};
    final absentCards = <String>{};
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
      authoritative &= page['reconciliation_version'] == 1;
      if (cursor == null) {
        reviewsFingerprint = page['reviews_fingerprint'] as String?;
      }
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
                    e['is_purged'] != true &&
                    (fingerprints[e['id']] != e['fingerprint'] ||
                        !localIds.contains(e['id'])),
              )
              .toList();
      seen.addAll(ids);
      for (var offset = 0; offset < changed.length; offset += 25) {
        final group = changed.skip(offset).take(25).toList();
        final deckIds = group.map((e) => e['id'] as String).toList();
        String? cardCursor;
        var completeCards = authoritative;
        final cardVisited = <String>{};
        final seenCards = <String>{};
        final missingDecks = <String>{};
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
          completeCards &= value['reconciliation_version'] == 1;
          final returnedDecks =
              (value['decks'] as List).map((e) => (e as Map)['id']).toSet();
          final missing =
              completeCards
                  ? _responseIds(value, 'missing_deck_ids')
                  : <String>{};
          if (!returnedDecks.containsAll(
                deckIds.where((id) => !missing.contains(id)),
              ) ||
              returnedDecks.any((id) => !deckIds.contains(id)) ||
              missing.any((id) => !deckIds.contains(id))) {
            throw const FormatException('Incomplete deck fetch');
          }
          missingDecks.addAll(missing);
          final fetchedCards = value['cards'];
          if (fetchedCards is! List) {
            throw const FormatException('Missing cards');
          }
          for (final card in fetchedCards) {
            if (card is! Map ||
                card['id'] is! String ||
                !deckIds.contains(card['deck_id'])) {
              throw const FormatException('Invalid card fetch');
            }
            final cardId = card['id'] as String;
            seenCards.add(cardId);
            // A card missing from an earlier group may have moved into this
            // one. Its downloaded state must survive the final cleanup.
            absentCards.remove(cardId);
          }
          await _mergeDownloadedData(fetched.body, session);
          cardCursor = value['next_cursor'] as String?;
          if (cardCursor != null && !cardVisited.add(cardCursor)) {
            throw const FormatException('Repeated card cursor');
          }
        } while (cardCursor != null);
        // A partial page cannot prove that an omitted local card is gone.
        if (completeCards) {
          final localCards =
              await (_database.select(_database.cards)
                ..where((t) => t.deckId.isIn(deckIds))).get();
          absentCards.addAll(
            localCards.map((c) => c.id).toSet().difference(seenCards),
          );
          disappeared.addAll(missingDecks);
        }
        final pending = await _protectedChanges();
        for (final entry in group) {
          final id = entry['id'] as String;
          if (!completeCards ||
              pending.affectedDecks.contains(id) ||
              missingDecks.contains(id)) {
            fingerprints.remove(id);
          } else {
            fingerprints[id] = entry['fingerprint'] as String;
          }
        }
      }
      cursor = page['next_cursor'] as String?;
      if (cursor != null && !visited.add(cursor)) {
        throw const FormatException('Repeated manifest cursor');
      }
    } while (cursor != null);
    if (authoritative) {
      final localDecks =
          await (_database.select(_database.decks)
            ..where((t) => t.userId.equals(session.userId))).get();
      await _database.transaction(() async {
        await _markAbsent(
          session,
          deckIds: {
            ...localDecks.map((d) => d.id).toSet().difference(seen),
            ...disappeared,
          },
          cardIds: absentCards,
        );
      });
    }
    if (reviewsFingerprint != null &&
        fingerprints['__reviews'] != reviewsFingerprint) {
      await _reconcileReviews(session, authoritative: authoritative);
      final pendingReviews =
          await (_database.select(_database.syncQueueItems)
                ..where(
                  (t) => t.entity.equals('review_log') & t.synced.equals(false),
                )
                ..limit(1))
              .get();
      if (authoritative && pendingReviews.isEmpty) {
        fingerprints['__reviews'] = reviewsFingerprint;
      } else {
        fingerprints.remove('__reviews');
      }
    }
    // Capability must hold across every manifest page. Otherwise cleanup was
    // deferred, and caching any page could prevent a later compatible refetch.
    if (!authoritative) fingerprints.clear();
    fingerprints.removeWhere(
      (id, _) => id != '__reviews' && !seen.contains(id),
    );
    await _assertActive(session);
    await _metadata.write(
      session.userId,
      fingerprints,
      expectedRevision: session.metadataRevision,
    );
  }

  Future<void> _reconcileReviews(
    _SyncSession session, {
    required bool authoritative,
  }) async {
    String? cursor;
    final visited = <String>{};
    final seen = <String>{};
    do {
      final suffix =
          cursor == null ? '' : '&cursor=${Uri.encodeComponent(cursor)}';
      final response = await _request(session, 'sync/reviews?limit=500$suffix');
      _requireSuccess(response, 'Review history download');
      final page = jsonDecode(response.body) as Map<String, dynamic>;
      final records = page['review_logs'];
      if (records is! List) {
        throw const FormatException('Missing review history');
      }
      await _mergeDownloadedReviews(records, session);
      seen.addAll(records.map((r) => (r as Map)['id'] as String));
      cursor = page['next_cursor'] as String?;
      if (cursor != null && !visited.add(cursor)) {
        throw const FormatException('Repeated review cursor');
      }
    } while (cursor != null);
    if (authoritative) {
      await _database.transaction(() async {
        await _assertActive(session);
        final pending =
            await (_database.select(_database.syncQueueItems)..where(
              (t) => t.entity.equals('review_log') & t.synced.equals(false),
            )).get();
        final protected =
            pending.map((r) => _pendingPayload(r.payload)?['id']).toSet();
        final local =
            await (_database.select(_database.reviewLogs)..where(
              (t) =>
                  t.userId.equals(session.userId) &
                  t.syncStatus.equals('synced'),
            )).get();
        final absent =
            local
                .where((r) => !seen.contains(r.id) && !protected.contains(r.id))
                .map((r) => r.id)
                .toList();
        for (var offset = 0; offset < absent.length; offset += 400) {
          await (_database.delete(_database.reviewLogs)..where(
            (t) => t.id.isIn(absent.skip(offset).take(400).toList()),
          )).go();
        }
        await _assertActive(session);
      });
    }
  }

  Future<void> _mergeDownloadedReviews(
    List<dynamic> records,
    _SyncSession session,
  ) async {
    final writes = <db.ReviewLogsCompanion>[];
    for (final raw in records) {
      if (raw is! Map<String, dynamic> ||
          raw['user_id']?.toString() != session.userId) {
        throw const FormatException('Invalid review owner');
      }
      final reviewedAt =
          DateTime.tryParse(raw['reviewed_at']?.toString() ?? '')?.toUtc();
      if (reviewedAt == null || raw['id'] == null || raw['card_id'] == null) {
        throw const FormatException('Invalid review history record');
      }
      writes.add(
        db.ReviewLogsCompanion.insert(
          id: raw['id'].toString(),
          userId: session.userId,
          cardId: raw['card_id'].toString(),
          rating: raw['rating']?.toString() ?? '',
          previousInterval: (raw['previous_interval'] as num?)?.toDouble() ?? 0,
          newInterval: (raw['new_interval'] as num?)?.toDouble() ?? 0,
          reviewedAt: reviewedAt,
          deviceId: raw['device_id']?.toString() ?? '',
          syncStatus: 'synced',
        ),
      );
    }
    await _database.transaction(() async {
      await _assertActive(session);
      await _database.batch((batch) {
        batch.insertAll(
          _database.reviewLogs,
          writes,
          mode: InsertMode.insertOrIgnore,
        );
      });
      await _assertActive(session);
    });
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
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid sync response');
    }

    if (decoded['decks'] is! List || decoded['cards'] is! List) {
      throw const FormatException('Missing sync records');
    }
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
        if (rawDeck is! Map<String, dynamic>) {
          throw const FormatException('Invalid deck');
        }
        final deckId = rawDeck['id']?.toString();
        if (deckId == null || deckId.isEmpty) {
          throw const FormatException('Missing deck id');
        }

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

        if (rawDeck['user_id']?.toString() != localUserId) {
          throw const FormatException('Invalid deck owner');
        }
        if (protected.decks.contains(deckId) ||
            (rawDeck['is_deleted'] == true &&
                protected.newCardDecks.contains(deckId))) {
          continue;
        }
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
        if (rawCard is! Map<String, dynamic>) {
          throw const FormatException('Invalid card');
        }
        final cardId = rawCard['id']?.toString();
        if (cardId == null || cardId.isEmpty) {
          throw const FormatException('Missing card id');
        }

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
            protected.decks.contains(rawCard['deck_id']?.toString())) {
          continue;
        }
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

class _DeferredSyncChanges implements Exception {
  const _DeferredSyncChanges();
}
