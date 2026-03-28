import 'package:drift/drift.dart';
import 'package:frontend/core/storage/app_database.dart';
import 'package:frontend/core/storage/session_storage.dart';
import 'package:frontend/features/home/domain/home_dashboard_models.dart';

class HomeRepository {
  final AppDatabase _database;
  final SessionStorage _sessionStorage;

  HomeRepository(this._database, this._sessionStorage);

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
    await _database.into(_database.decks).insert(
          DecksCompanion.insert(
            id: deck.id,
            userId: '',
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