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
    final safeEaseFactor = previousEaseFactor <= 0 ? _initialEaseFactor : previousEaseFactor;
    final quality = _qualityFromRating(rating);
    final nextEaseFactor = _nextEaseFactor(safeEaseFactor, quality);

    late final int nextRepetitionCount;
    late final double nextInterval;

    if (quality < 3) {
      nextRepetitionCount = 0;
      nextInterval = 1;
    } else {
      final previousSuccessfulRepetitions = previousRepetitionCount < 0 ? 0 : previousRepetitionCount;
      if (previousSuccessfulRepetitions == 0) {
        nextInterval = 1;
      } else if (previousSuccessfulRepetitions == 1) {
        nextInterval = 6;
      } else {
        final baseInterval = previousInterval <= 0 ? 1 : previousInterval;
        final multiplier = rating == 'easy' ? (nextEaseFactor + 0.15) : nextEaseFactor;
        final interval = (baseInterval * multiplier).roundToDouble();
        nextInterval = interval < 1 ? 1 : interval;
      }
      nextRepetitionCount = previousSuccessfulRepetitions + 1;
    }

    final normalizedInterval = double.parse(nextInterval.toStringAsFixed(2));
    final nextState = nextRepetitionCount < 2 ? 'learning' : 'review';

    return ReviewOutcome(
      nextState: nextState,
      interval: normalizedInterval,
      easeFactor: nextEaseFactor,
      repetitionCount: nextRepetitionCount,
      dueTimestamp: reviewTime.add(Duration(days: normalizedInterval.round())),
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

  static double _nextEaseFactor(double currentEaseFactor, int quality) {
    final next = currentEaseFactor + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
    if (next < _minEaseFactor) {
      return _minEaseFactor;
    }
    return double.parse(next.toStringAsFixed(2));
  }
}
