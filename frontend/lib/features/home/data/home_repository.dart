import 'dart:async';

import 'package:drift/drift.dart';
import 'package:frontend/core/storage/app_database.dart';
import 'package:frontend/core/storage/session_storage.dart';
import 'package:frontend/features/home/domain/home_dashboard_models.dart';

class HomeDashboardStats {
  final int reviewedToday;
  final int streak;
  final double retentionRate;

  const HomeDashboardStats({
    required this.reviewedToday,
    required this.streak,
    required this.retentionRate,
  });
}

class _DeckCardStats {
  int total = 0;
  int due = 0;
  DateTime? nextDueAt;
}

class HomeRepository {
  final AppDatabase _database;
  final SessionStorage _sessionStorage;
  final void Function()? _onDataChanged;
  late final StreamSubscription<dynamic> _deckChanges;
  late final StreamSubscription<dynamic> _reviewChanges;
  Future<List<DeckSummary>>? _cachedDecks;
  Future<HomeDashboardStats>? _cachedStats;
  String? _deckUserId;
  String? _statsUserId;
  DateTime? _deckCachedAt;
  DateTime? _statsCachedAt;
  int _deckRevision = 0;
  int _reviewRevision = 0;
  bool _disposed = false;

  HomeRepository(
    this._database,
    this._sessionStorage, {
    void Function()? onDataChanged,
  }) : _onDataChanged = onDataChanged {
    // A cheap watched query invalidates the summaries for local edits and
    // downloaded sync changes without loading all cards into memory.
    _deckChanges = _database
        .customSelect('SELECT 1', readsFrom: {_database.decks, _database.cards})
        .watch()
        .listen((_) {
          if (_disposed) return;
          _deckRevision++;
          _reviewRevision++;
          _cachedDecks = null;
          _cachedStats = null;
          _onDataChanged?.call();
        });
    _reviewChanges = _database
        .customSelect('SELECT 1', readsFrom: {_database.reviewLogs})
        .watch()
        .listen((_) {
          if (_disposed) return;
          _reviewRevision++;
          _cachedStats = null;
          _onDataChanged?.call();
        });
  }

  Future<void> dispose() async {
    _disposed = true;
    await _deckChanges.cancel();
    await _reviewChanges.cancel();
  }

  bool _fresh(DateTime? cachedAt) =>
      cachedAt != null &&
      DateTime.now().difference(cachedAt) < const Duration(seconds: 30);

  Future<HomeDashboardStats> getDashboardStats() async {
    final currentUserId = await _sessionStorage.readUserId();

    if (currentUserId == null || currentUserId.isEmpty) {
      return const HomeDashboardStats(
        reviewedToday: 0,
        streak: 0,
        retentionRate: 0.0,
      );
    }

    if (_statsUserId == currentUserId && _fresh(_statsCachedAt)) {
      final cached = _cachedStats;
      if (cached != null) return cached;
    }
    final revision = _reviewRevision;
    _statsUserId = currentUserId;
    _statsCachedAt = DateTime.now();
    final load = _loadDashboardStats(currentUserId);
    _cachedStats = load;
    try {
      final result = await load;
      return revision == _reviewRevision ? result : getDashboardStats();
    } catch (_) {
      if (identical(_cachedStats, load)) _cachedStats = null;
      rethrow;
    }
  }

  Future<HomeDashboardStats> _loadDashboardStats(String currentUserId) async {
    final now = DateTime.now().toUtc();
    final startOfToday = DateTime.utc(now.year, now.month, now.day);
    final endOfToday = startOfToday.add(const Duration(days: 1));

    final reviewedTodayExpression = _database.reviewLogs.cardId.count(
      distinct: true,
    );

    final reviewedTodayRow =
        await (_database.selectOnly(_database.reviewLogs)
              ..addColumns([reviewedTodayExpression])
              ..where(
                _database.reviewLogs.userId.equals(currentUserId) &
                    _database.reviewLogs.reviewedAt.isBiggerOrEqualValue(
                      startOfToday,
                    ) &
                    _database.reviewLogs.reviewedAt.isSmallerThanValue(
                      endOfToday,
                    ),
              ))
            .getSingle();

    final reviewedToday = reviewedTodayRow.read(reviewedTodayExpression) ?? 0;

    final reviewedDateRows =
        await (_database.selectOnly(_database.reviewLogs)
              ..addColumns([_database.reviewLogs.reviewedAt])
              ..where(_database.reviewLogs.userId.equals(currentUserId)))
            .get();

    final reviewedDays = <DateTime>{};
    for (final row in reviewedDateRows) {
      final reviewedAt = row.read(_database.reviewLogs.reviewedAt);
      if (reviewedAt == null) continue;

      reviewedDays.add(
        DateTime.utc(reviewedAt.year, reviewedAt.month, reviewedAt.day),
      );
    }

    var streak = 0;
    var cursor = startOfToday;
    while (reviewedDays.contains(cursor)) {
      streak += 1;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    final retentionRows =
        await (_database.selectOnly(_database.reviewLogs)
              ..addColumns([_database.reviewLogs.rating])
              ..where(_database.reviewLogs.userId.equals(currentUserId)))
            .get();

    final totalReviews = retentionRows.length;
    final successfulReviews =
        retentionRows.where((row) {
          final rating = row.read(_database.reviewLogs.rating) ?? '';
          return rating != 'again';
        }).length;

    final retentionRate =
        totalReviews == 0 ? 0.0 : (successfulReviews / totalReviews) * 100.0;

    return HomeDashboardStats(
      reviewedToday: reviewedToday,
      streak: streak,
      retentionRate: double.parse(retentionRate.toStringAsFixed(1)),
    );
  }

  Future<String?> getUsername() async {
    return _sessionStorage.readUsername();
  }

  Future<List<DeckSummary>> getDecks() async {
    final currentUserId = await _sessionStorage.readUserId();
    if (currentUserId == null || currentUserId.isEmpty) return [];
    if (_deckUserId == currentUserId && _fresh(_deckCachedAt)) {
      final cached = _cachedDecks;
      if (cached != null) return cached;
    }
    final revision = _deckRevision;
    _deckUserId = currentUserId;
    _deckCachedAt = DateTime.now();
    final load = _loadDecks(currentUserId);
    _cachedDecks = load;
    try {
      final result = await load;
      return revision == _deckRevision ? result : getDecks();
    } catch (_) {
      if (identical(_cachedDecks, load)) _cachedDecks = null;
      rethrow;
    }
  }

  Future<List<DeckSummary>> _loadDecks(String currentUserId) async {
    final decks =
        await (_database.select(_database.decks)
              ..where(
                (tbl) =>
                    tbl.userId.equals(currentUserId) &
                    tbl.isDeleted.equals(false),
              )
              ..orderBy([(tbl) => OrderingTerm.desc(tbl.updatedAt)]))
            .get();

    final now = DateTime.now().toUtc();
    final stats = <String, _DeckCardStats>{};
    // Keep each IN clause below SQLite's bind-variable limit. Aggregate on
    // the device so Home never materializes every card in a large library.
    for (var offset = 0; offset < decks.length; offset += 400) {
      final ids = decks.skip(offset).take(400).map((deck) => deck.id).toList();
      final placeholders = List.filled(ids.length, '?').join(',');
      final rows =
          await _database
              .customSelect(
                'SELECT deck_id, COUNT(*) AS total_cards, '
                'SUM(CASE WHEN due_timestamp IS NULL OR due_timestamp <= ? '
                'THEN 1 ELSE 0 END) AS due_cards, '
                'MIN(due_timestamp) AS next_due_at FROM cards '
                'WHERE is_deleted = 0 AND deck_id IN ($placeholders) '
                'GROUP BY deck_id',
                variables: [
                  Variable.withDateTime(now),
                  ...ids.map(Variable.withString),
                ],
              )
              .get();
      for (final row in rows) {
        final summary = _DeckCardStats();
        summary.total = row.read<int>('total_cards');
        summary.due = row.read<int>('due_cards');
        final nextDueSeconds = row.readNullable<int>('next_due_at');
        if (nextDueSeconds != null) {
          summary.nextDueAt = DateTime.fromMillisecondsSinceEpoch(
            nextDueSeconds * 1000,
            isUtc: true,
          );
        }
        stats[row.read<String>('deck_id')] = summary;
      }
    }
    final results = <DeckSummary>[];

    for (final deck in decks) {
      final cardStats = stats[deck.id] ?? _DeckCardStats();

      results.add(
        DeckSummary(
          id: deck.id,
          title: deck.title,
          description: deck.description ?? 'No description',
          totalCards: cardStats.total,
          dueCards: cardStats.due,
          progress: 0,
          isPublic: deck.isPublic,
          nextDueAt: cardStats.nextDueAt,
          updatedAt: deck.updatedAt,
        ),
      );
    }

    return results;
  }

  Future<void> addDeckToLocal(DeckSummary deck) async {
    final currentUserId = await _sessionStorage.readUserId() ?? '';
    await _database
        .into(_database.decks)
        .insert(
          DecksCompanion.insert(
            id: deck.id,
            userId: currentUserId,
            title: deck.title,
            description: Value(deck.description),
            isPublic: Value(deck.isPublic),
            createdAt: deck.updatedAt,
            updatedAt: deck.updatedAt,
            version: const Value(1),
            isDeleted: const Value(false),
          ),
        );
    _deckRevision++;
    _cachedDecks = null;
    _onDataChanged?.call();
  }
}
