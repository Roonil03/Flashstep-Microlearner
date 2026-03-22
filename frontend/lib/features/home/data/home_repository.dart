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
      final decks = await _database.select(_database.decks).get();
      
      return decks.map((deck) {
        return DeckSummary(
          id: deck.id,
          title: deck.title,
          description: deck.description ?? 'No description',
          totalCards: deck.totalCards,
          dueCards: 0,
          progress: deck.progress,
          isPublic: deck.isPublic,
          nextDueAt: deck.nextDueAt,
          updatedAt: deck.updatedAt,
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> addDeckToLocal(DeckSummary deck) async {
    final decksCompanion = DecksCompanion(
      id: Value(deck.id),
      userId: Value(''),
      title: Value(deck.title),
      description: Value(deck.description),
      totalCards: Value(deck.totalCards),
      progress: Value(deck.progress),
      isPublic: Value(deck.isPublic),
      nextDueAt: Value(deck.nextDueAt),
      updatedAt: Value(deck.updatedAt),
    );
    await _database.into(_database.decks).insert(decksCompanion);
  }
}