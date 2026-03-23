class ReviewOutcome {
  final String nextState;
  final double interval;
  final double easeFactor;
  final int repetitionCount;
  final DateTime dueTimestamp;

  const ReviewOutcome({
    required this.nextState,
    required this.interval,
    required this.easeFactor,
    required this.repetitionCount,
    required this.dueTimestamp,
  });
}

class ReviewScheduler {
  static const double _minEaseFactor = 1.3;
  static const double _initialEaseFactor = 2.5;

  static ReviewOutcome apply({
    required String currentState,
    required double previousInterval,
    required double previousEaseFactor,
    required int previousRepetitionCount,
    required String rating,
    DateTime? now,
  }) {
    final reviewTime = (now ?? DateTime.now()).toUtc();
    final safeEf = previousEaseFactor <= 0 ? _initialEaseFactor : previousEaseFactor;

    final quality = _qualityFromRating(rating);
    final updatedEf = _nextEaseFactor(safeEf, quality);

    if (rating == 'again') {
      return ReviewOutcome(
        nextState: 'learning',
        interval: 1,
        easeFactor: updatedEf,
        repetitionCount: 0,
        dueTimestamp: reviewTime.add(const Duration(days: 1)),
      );
    }

    final int nextRepetitions = previousRepetitionCount + 1;
    final double baseInterval = previousInterval <= 0 ? 1 : previousInterval;

    double nextInterval;
    switch (rating) {
      case 'hard':
        nextInterval = baseInterval * 1.2;
        break;
      case 'easy':
        nextInterval = baseInterval * updatedEf * 1.3;
        break;
      case 'good':
      default:
        nextInterval = baseInterval * updatedEf;
        break;
    }

    if (previousRepetitionCount == 0) {
      if (rating == 'hard') {
        nextInterval = 1;
      } else if (rating == 'good') {
        nextInterval = 3;
      } else if (rating == 'easy') {
        nextInterval = 4;
      }
    }

    final normalizedInterval = nextInterval < 1 ? 1 : double.parse(nextInterval.toStringAsFixed(2));

    return ReviewOutcome(
      nextState: nextRepetitions < 2 ? 'learning' : 'review',
      interval: normalizedInterval.toDouble(),
      easeFactor: updatedEf,
      repetitionCount: nextRepetitions,
      dueTimestamp: reviewTime.add(Duration(hours: (normalizedInterval * 24).round())),
    );
  }

  static int _qualityFromRating(String rating) {
    switch (rating) {
      case 'again':
        return 0;
      case 'hard':
        return 3;
      case 'easy':
        return 5;
      case 'good':
      default:
        return 4;
    }
  }

  static double _nextEaseFactor(double currentEf, int quality) {
    final updated = currentEf + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
    return updated < _minEaseFactor ? _minEaseFactor : double.parse(updated.toStringAsFixed(2));
  }
}