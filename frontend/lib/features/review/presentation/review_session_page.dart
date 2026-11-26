import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/app_database.dart' as db;
import '../../../app/router.dart';
import '../../../app/theme/study_colors.dart';
import 'notebook_card.dart';
import '../../../core/widgets/ln_study_cards_illustration.dart';
import 'start_review_page.dart';
import '../data/review_repository.dart';
import 'review_rating_row.dart';

class ReviewSessionPage extends ConsumerStatefulWidget {
  final String deckId;
  final String deckTitle;

  const ReviewSessionPage({
    super.key,
    required this.deckId,
    required this.deckTitle,
  });

  @override
  ConsumerState<ReviewSessionPage> createState() => _ReviewSessionPageState();
}

/// A single finite water ring follows an explicit reveal, without moving content.
class _AnswerReveal extends StatefulWidget {
  const _AnswerReveal({super.key, required this.child});
  final Widget child;
  @override
  State<_AnswerReveal> createState() => _AnswerRevealState();
}

class _AnswerRevealState extends State<_AnswerReveal>
    with SingleTickerProviderStateMixin {
  late final _ripple = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _ripple.stop();
      _ripple.value = 1;
    } else if (!_started) {
      _started = true;
      _ripple.forward();
    }
  }

  @override
  void dispose() {
    _ripple.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: CustomPaint(
      foregroundPainter: _WaterRingPainter(
        _ripple,
        context.studyTone(StudyArea.study).accent,
      ),
      child: widget.child,
    ),
  );
}

class _WaterRingPainter extends CustomPainter {
  _WaterRingPainter(this.progress, this.color) : super(repaint: progress);
  final Animation<double> progress;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value;
    if (t <= 0 || t >= 1) return;
    final paint =
        Paint()
          ..color = color.withValues(alpha: (1 - t) * .24)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
    canvas.drawCircle(Offset(size.width / 2, 0), size.longestSide * t, paint);
  }

  @override
  bool shouldRepaint(_WaterRingPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.progress != progress;
}

class _ReviewSessionPageState extends ConsumerState<ReviewSessionPage> {
  bool _loading = true;
  bool _loadFailed = false;
  bool _revealed = false;
  bool _saving = false;
  int _countdown = 3;
  int _index = 0;
  String? _failedRating;
  String? _feedback;
  Timer? _startupTimer;
  List<db.Card> _cards = const [];
  final _scrollController = ScrollController(keepScrollOffset: false);
  int _questionRevision = 0;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _startupTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final cards = await ref
          .read(reviewRepositoryProvider)
          .getDueCardsForDeck(widget.deckId);
      if (!mounted) return;
      setState(() {
        _cards = cards.toList();
        _loading = false;
      });
      if (_cards.isEmpty) return;
      _startupTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
        } else if (_countdown <= 1) {
          _finishCountdown();
        } else {
          setState(() => _countdown -= 1);
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  void _finishCountdown() {
    _startupTimer?.cancel();
    setState(() => _countdown = 0);
    _scrollToQuestion();
  }

  // A popped route remains mounted throughout its exit animation.
  bool get _isCurrentRoute =>
      mounted && (ModalRoute.of(context)?.isCurrent ?? true);

  void _scrollToQuestion() {
    final revision = _questionRevision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isCurrentRoute || revision != _questionRevision || _revealed) {
        return;
      }
      // A new question starts at the top even when both cards are long.
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
    });
  }

  void _revealAnswer() {
    setState(() => _revealed = true);
  }

  Future<void> _rateCard(String rating) async {
    if (_saving || !_revealed || _index >= _cards.length) return;
    setState(() {
      _saving = true;
      _failedRating = null;
      _feedback = null;
    });
    final current = _cards[_index];
    try {
      await ref
          .read(reviewRepositoryProvider)
          .applyReview(card: current, rating: rating);
      if (!mounted) return;
      setState(() {
        _revealed = false;
        _index += 1;
        _questionRevision += 1;
        _feedback = '${_ratingLabel(rating)} saved on your device.';
      });
      _scrollToQuestion();
      ref.invalidate(reviewDecksProvider);
    } catch (_) {
      if (!mounted) return;
      setState(() => _failedRating = rating);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _shuffleRemaining() {
    if (_saving || _cards.isEmpty || _index >= _cards.length - 1) return;
    setState(() {
      final remaining = _cards.sublist(_index)..shuffle();
      _cards.replaceRange(_index, _cards.length, remaining);
      _revealed = false;
      _questionRevision += 1;
      _failedRating = null;
      _feedback = 'Remaining cards shuffled. Showing the question.';
    });
    _scrollToQuestion();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = context.studyTone(StudyArea.study);
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.deckTitle)),
        body: const Center(
          child: CircularProgressIndicator(
            semanticsLabel: 'Loading review cards',
          ),
        ),
      );
    }
    if (_loadFailed) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.deckTitle)),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Could not load these cards',
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Try again to start this review. No reviews have been changed.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _bootstrap,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try again'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed:
                      () => Navigator.of(
                        context,
                      ).pushNamed(AppRoutes.browseDecks),
                  icon: const Icon(Icons.menu_book_outlined),
                  label: const Text('View decks'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (_cards.isEmpty || _index >= _cards.length) return _completion(theme);
    if (_countdown > 0) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.deckTitle)),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: tone.fill,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    Icons.auto_stories_rounded,
                    size: 64,
                    color: tone.ink,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Get ready to recall',
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Starting in $_countdown…',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                const Text(
                  'One question at a time. You set the pace.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _finishCountdown,
                  child: const Text('Start now'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final card = _cards[_index];
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.deckTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.shuffle),
            tooltip: 'Shuffle remaining cards',
            onPressed:
                _saving || _index >= _cards.length - 1
                    ? null
                    : _shuffleRemaining,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'RECALL / CHECK / REFLECT',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: tone.accent,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      Text(
                        'Card ${_index + 1} of ${_cards.length}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text('$_index reviewed · ${_cards.length - _index} left'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    minHeight: 8,
                    color: tone.accent,
                    backgroundColor: tone.fill,
                    borderRadius: BorderRadius.circular(2),
                    value: _index / _cards.length,
                    semanticsLabel: 'Session progress',
                    semanticsValue:
                        '$_index of ${_cards.length} cards reviewed',
                  ),
                  const SizedBox(height: 24),
                  NotebookCard(heading: 'Question', text: card.front),
                  const SizedBox(height: 16),
                  if (_revealed)
                    _AnswerReveal(
                      key: ValueKey(_index),
                      child: NotebookCard(
                        heading: 'Answer',
                        text: card.back,
                        answer: true,
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: tone.fill,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.psychology_outlined, color: tone.ink),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Recall the answer before revealing it.',
                              style: TextStyle(color: tone.ink),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),
                  if (!_revealed)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(48, 56),
                        splashFactory: NoSplash.splashFactory,
                        animationDuration: Duration.zero,
                      ),
                      onPressed: _revealAnswer,
                      icon: const Icon(Icons.visibility_outlined),
                      label: const Text('Show answer'),
                    )
                  else ...[
                    Text(
                      'How well did you recall it?',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final rating in const [
                      ('again', 'Again', 'Not yet'),
                      ('hard', 'Hard', 'With effort'),
                      ('good', 'Good', 'Recalled it'),
                      ('easy', 'Easy', 'Without effort'),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: ReviewRatingRow(
                          label: rating.$2,
                          description: rating.$3,
                          onPressed:
                              _saving ? null : () => _rateCard(rating.$1),
                        ),
                      ),
                  ],
                  if (_saving) ...[
                    const SizedBox(height: 16),
                    const LinearProgressIndicator(
                      semanticsLabel: 'Saving review',
                    ),
                    const SizedBox(height: 8),
                    const Text('Saving your review…'),
                  ],
                  if (_failedRating != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Could not save this review. Your answer is still here. Try again or choose a rating.',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => _rateCard(_failedRating!),
                      icon: const Icon(Icons.refresh),
                      label: Text('Retry ${_ratingLabel(_failedRating!)}'),
                    ),
                  ],
                  if (_feedback != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _feedback!,
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _ratingLabel(String rating) => switch (rating) {
    'again' => 'Again',
    'hard' => 'Hard',
    'good' => 'Good',
    'easy' => 'Easy',
    _ => rating,
  };

  Widget _completion(ThemeData theme) {
    final empty = _cards.isEmpty;
    return Scaffold(
      appBar: AppBar(title: Text(widget.deckTitle)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (empty)
                Icon(
                  Icons.check_circle_outline,
                  size: 60,
                  color: theme.colorScheme.primary,
                )
              else
                const LnStudyCardsIllustration(),
              const SizedBox(height: 16),
              Text(
                empty ? 'No cards available' : 'Review complete',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                empty
                    ? 'This deck has no cards available for this session.'
                    : '$_index card${_index == 1 ? '' : 's'} reviewed. Your ratings are saved on your device.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              if (!empty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: context.studyTone(StudyArea.library).fill,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '$_index / ${_cards.length} complete · Every recall counts.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: context.studyTone(StudyArea.library).ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: () {
                      ref.invalidate(reviewDecksProvider);
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        AppRoutes.review,
                        (route) => route.settings.name == AppRoutes.home,
                      );
                    },
                    icon: const Icon(Icons.school_outlined),
                    label: const Text('Choose another deck'),
                  ),
                  OutlinedButton.icon(
                    onPressed:
                        () => Navigator.of(
                          context,
                        ).pushNamedAndRemoveUntil(AppRoutes.home, (_) => false),
                    icon: const Icon(Icons.home_outlined),
                    label: const Text('Back to Home'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
