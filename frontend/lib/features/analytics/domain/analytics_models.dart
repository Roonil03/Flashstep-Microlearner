class DailyCountPoint {
  final DateTime date;
  final int count;

  const DailyCountPoint({
    required this.date,
    required this.count,
  });

  factory DailyCountPoint.fromJson(Map<String, dynamic> json) {
    return DailyCountPoint(
      date: DateTime.parse(json['date'].toString()).toUtc(),
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }
}

class AccuracyPoint {
  final DateTime date;
  final int reviewed;
  final int correct;
  final double accuracy;

  const AccuracyPoint({
    required this.date,
    required this.reviewed,
    required this.correct,
    required this.accuracy,
  });

  factory AccuracyPoint.fromJson(Map<String, dynamic> json) {
    return AccuracyPoint(
      date: DateTime.parse(json['date'].toString()).toUtc(),
      reviewed: (json['reviewed'] as num?)?.toInt() ?? 0,
      correct: (json['correct'] as num?)?.toInt() ?? 0,
      accuracy: (json['accuracy'] as num?)?.toDouble() ?? 0,
    );
  }
}

class RatingBreakdown {
  final int again;
  final int hard;
  final int good;
  final int easy;

  const RatingBreakdown({
    required this.again,
    required this.hard,
    required this.good,
    required this.easy,
  });

  factory RatingBreakdown.fromJson(Map<String, dynamic> json) {
    return RatingBreakdown(
      again: (json['again'] as num?)?.toInt() ?? 0,
      hard: (json['hard'] as num?)?.toInt() ?? 0,
      good: (json['good'] as num?)?.toInt() ?? 0,
      easy: (json['easy'] as num?)?.toInt() ?? 0,
    );
  }

  int get total => again + hard + good + easy;
}

class DeckAnalyticsInsight {
  final String deckId;
  final String title;
  final int totalCards;
  final int dueCards;
  final int reviewedCount;
  final int correctCount;
  final int matureCards;
  final double accuracy;

  const DeckAnalyticsInsight({
    required this.deckId,
    required this.title,
    required this.totalCards,
    required this.dueCards,
    required this.reviewedCount,
    required this.correctCount,
    required this.matureCards,
    required this.accuracy,
  });

  factory DeckAnalyticsInsight.fromJson(Map<String, dynamic> json) {
    return DeckAnalyticsInsight(
      deckId: json['deck_id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Untitled deck',
      totalCards: (json['total_cards'] as num?)?.toInt() ?? 0,
      dueCards: (json['due_cards'] as num?)?.toInt() ?? 0,
      reviewedCount: (json['reviewed_count'] as num?)?.toInt() ?? 0,
      correctCount: (json['correct_count'] as num?)?.toInt() ?? 0,
      matureCards: (json['mature_cards'] as num?)?.toInt() ?? 0,
      accuracy: (json['accuracy'] as num?)?.toDouble() ?? 0,
    );
  }
}

class AnalyticsDashboardData {
  final String username;
  final int rangeDays;
  final DateTime generatedAt;
  final int totalDecks;
  final int totalCards;
  final int learnedCards;
  final int matureCards;
  final int newCards;
  final int learningCards;
  final int reviewCards;
  final int dueNow;
  final int dueNext24Hours;
  final int reviewsToday;
  final int reviewsInRange;
  final int activeDaysInRange;
  final double averageStudyLoad;
  final double retentionRate;
  final int currentStreak;
  final int bestDayCount;
  final double longestIntervalDays;
  final RatingBreakdown ratingBreakdown;
  final List<DailyCountPoint> reviewActivity;
  final List<AccuracyPoint> accuracyTrend;
  final List<DeckAnalyticsInsight> deckInsights;

  const AnalyticsDashboardData({
    required this.username,
    required this.rangeDays,
    required this.generatedAt,
    required this.totalDecks,
    required this.totalCards,
    required this.learnedCards,
    required this.matureCards,
    required this.newCards,
    required this.learningCards,
    required this.reviewCards,
    required this.dueNow,
    required this.dueNext24Hours,
    required this.reviewsToday,
    required this.reviewsInRange,
    required this.activeDaysInRange,
    required this.averageStudyLoad,
    required this.retentionRate,
    required this.currentStreak,
    required this.bestDayCount,
    required this.longestIntervalDays,
    required this.ratingBreakdown,
    required this.reviewActivity,
    required this.accuracyTrend,
    required this.deckInsights,
  });

  factory AnalyticsDashboardData.fromJson(Map<String, dynamic> json) {
    final reviewActivityJson = (json['review_activity'] as List?) ?? const [];
    final accuracyTrendJson = (json['accuracy_trend'] as List?) ?? const [];
    final deckInsightsJson = (json['deck_insights'] as List?) ?? const [];

    return AnalyticsDashboardData(
      username: json['username']?.toString() ?? 'Learner',
      rangeDays: (json['range_days'] as num?)?.toInt() ?? 30,
      generatedAt: DateTime.tryParse(json['generated_at']?.toString() ?? '')?.toUtc() ?? DateTime.now().toUtc(),
      totalDecks: (json['total_decks'] as num?)?.toInt() ?? 0,
      totalCards: (json['total_cards'] as num?)?.toInt() ?? 0,
      learnedCards: (json['learned_cards'] as num?)?.toInt() ?? 0,
      matureCards: (json['mature_cards'] as num?)?.toInt() ?? 0,
      newCards: (json['new_cards'] as num?)?.toInt() ?? 0,
      learningCards: (json['learning_cards'] as num?)?.toInt() ?? 0,
      reviewCards: (json['review_cards'] as num?)?.toInt() ?? 0,
      dueNow: (json['due_now'] as num?)?.toInt() ?? 0,
      dueNext24Hours: (json['due_next_24_hours'] as num?)?.toInt() ?? 0,
      reviewsToday: (json['reviews_today'] as num?)?.toInt() ?? 0,
      reviewsInRange: (json['reviews_in_range'] as num?)?.toInt() ?? 0,
      activeDaysInRange: (json['active_days_in_range'] as num?)?.toInt() ?? 0,
      averageStudyLoad: (json['average_study_load'] as num?)?.toDouble() ?? 0,
      retentionRate: (json['retention_rate'] as num?)?.toDouble() ?? 0,
      currentStreak: (json['current_streak'] as num?)?.toInt() ?? 0,
      bestDayCount: (json['best_day_count'] as num?)?.toInt() ?? 0,
      longestIntervalDays: (json['longest_interval_days'] as num?)?.toDouble() ?? 0,
      ratingBreakdown: RatingBreakdown.fromJson(
        Map<String, dynamic>.from((json['rating_breakdown'] as Map?) ?? const {}),
      ),
      reviewActivity: reviewActivityJson
          .whereType<Map>()
          .map((item) => DailyCountPoint.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false),
      accuracyTrend: accuracyTrendJson
          .whereType<Map>()
          .map((item) => AccuracyPoint.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false),
      deckInsights: deckInsightsJson
          .whereType<Map>()
          .map((item) => DeckAnalyticsInsight.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false),
    );
  }

  bool get hasCards => totalCards > 0;
  bool get hasReviewHistory => reviewsInRange > 0 || reviewsToday > 0;
}
