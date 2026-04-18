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

class HomeRepository {
  final AppDatabase _database;
  final SessionStorage _sessionStorage;

  HomeRepository(this._database, this._sessionStorage);

  Future<HomeDashboardStats> getDashboardStats() async {
    final currentUserId = await _sessionStorage.readUserId();

    if (currentUserId == null || currentUserId.isEmpty) {
      return const HomeDashboardStats(
        reviewedToday: 0,
        streak: 0,
        retentionRate: 0.0,
      );
    }

    final now = DateTime.now().toUtc();
    final startOfToday = DateTime.utc(now.year, now.month, now.day);
    final endOfToday = startOfToday.add(const Duration(days: 1));

    final reviewedTodayExpression =
        _database.reviewLogs.cardId.count(distinct: true);

    final reviewedTodayRow = await (_database.selectOnly(_database.reviewLogs)
          ..addColumns([reviewedTodayExpression])
          ..where(
            _database.reviewLogs.userId.equals(currentUserId) &
                _database.reviewLogs.reviewedAt
                    .isBiggerOrEqualValue(startOfToday) &
                _database.reviewLogs.reviewedAt.isSmallerThanValue(endOfToday),
          ))
        .getSingle();

    final reviewedToday = reviewedTodayRow.read(reviewedTodayExpression) ?? 0;

    final reviewedDateRows = await (_database.selectOnly(_database.reviewLogs)
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

    final retentionRows = await (_database.selectOnly(_database.reviewLogs)
          ..addColumns([_database.reviewLogs.rating])
          ..where(_database.reviewLogs.userId.equals(currentUserId)))
        .get();

    final totalReviews = retentionRows.length;
    final successfulReviews = retentionRows.where((row) {
      final rating = row.read(_database.reviewLogs.rating) ?? '';
      return rating != 'again';
    }).length;

    final retentionRate = totalReviews == 0
        ? 0.0
        : (successfulReviews / totalReviews) * 100.0;

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
    try {
      final currentUserId = await _sessionStorage.readUserId();
      if (currentUserId == null || currentUserId.isEmpty) {
        return [];
      }

      final decks = await (_database.select(_database.decks)
            ..where((tbl) =>
                tbl.userId.equals(currentUserId) &
                tbl.isDeleted.equals(false))
            ..orderBy([(tbl) => OrderingTerm.desc(tbl.updatedAt)]))
          .get();

      final now = DateTime.now().toUtc();
      final results = <DeckSummary>[];

      for (final deck in decks) {
        final cards = await (_database.select(_database.cards)
              ..where((tbl) => tbl.deckId.equals(deck.id) & tbl.isDeleted.equals(false)))
            .get();

        final totalCards = cards.length;
        final dueCards = cards.where((card) {
          final due = card.dueTimestamp;
          return due == null || !due.isAfter(now);
        }).length;

        DateTime? nextDueAt;
        for (final card in cards) {
          final due = card.dueTimestamp;
          if (due == null) continue;
          if (nextDueAt == null || due.isBefore(nextDueAt)) {
            nextDueAt = due;
          }
        }

        results.add(
          DeckSummary(
            id: deck.id,
            title: deck.title,
            description: deck.description ?? 'No description',
            totalCards: totalCards,
            dueCards: dueCards,
            progress: 0,
            isPublic: deck.isPublic,
            nextDueAt: nextDueAt,
            updatedAt: deck.updatedAt,
          ),
        );
      }

      return results;
    } catch (_) {
      return [];
    }
  }

  Future<void> addDeckToLocal(DeckSummary deck) async {
    final currentUserId = await _sessionStorage.readUserId() ?? '';
    await _database.into(_database.decks).insert(
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
  }
}
