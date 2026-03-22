class ApiEndpoints {
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String me = '/me';

  static const String createDeck = '/decks';
  static const String getDecks = '/decks';
  static const String updateDeck = '/decks';
  static const String deleteDeck = '/decks';

  static const String createCard = '/cards';
  static const String getDeckCards = '/decks';
  static const String updateCard = '/cards';
  static const String deleteCard = '/cards';

  static const String syncUpload = '/sync/upload';
  static const String syncDownload = '/sync/download';

  static const String dailyReviewCount = '/analytics/daily-review-count';
  static const String averageSessionLength = '/analytics/average-session-length';
  static const String accuracyTrends = '/analytics/accuracy-trends';
  static const String deckPerformance = '/analytics/deck-performance';
}
