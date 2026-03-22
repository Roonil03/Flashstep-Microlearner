class DeckSummary {
  final String id;
  final String title;
  final String description;
  final int totalCards;
  final int dueCards;
  final double progress; // 0.0 to 1.0
  final bool isPublic;
  final DateTime? nextDueAt;
  final DateTime updatedAt;

  const DeckSummary({
    required this.id,
    required this.title,
    required this.description,
    required this.totalCards,
    required this.dueCards,
    required this.progress,
    required this.isPublic,
    required this.nextDueAt,
    required this.updatedAt,
  });
}

class HomeDashboardData {
  final String displayName;
  final int decksCount;
  final int dueToday;
  final int reviewedToday;
  final int streak;
  final double retentionRate;
  final bool isOffline;
  final bool isSyncing;
  final DateTime? lastSyncedAt;
  final DeckSummary deckOfTheDay;
  final List<DeckSummary> decks;

  const HomeDashboardData({
    required this.displayName,
    required this.decksCount,
    required this.dueToday,
    required this.reviewedToday,
    required this.streak,
    required this.retentionRate,
    required this.isOffline,
    required this.isSyncing,
    required this.lastSyncedAt,
    required this.deckOfTheDay,
    required this.decks,
  });
}