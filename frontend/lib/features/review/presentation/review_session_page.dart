import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/app_database.dart' as db;
import '../../../app/router.dart';
import 'start_review_page.dart';
import '../data/review_repository.dart';

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

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _startupTimer?.cancel();
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
        if (!mounted || _countdown <= 1) {
          timer.cancel();
          if (mounted) setState(() => _countdown = 0);
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

  void _startNow() {
    _startupTimer?.cancel();
    setState(() => _countdown = 0);
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
        _feedback = '${_ratingLabel(rating)} saved on your device.';
      });
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
      _failedRating = null;
      _feedback = 'Remaining cards shuffled. Showing the question.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                const Icon(Icons.school_outlined, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Get ready to recall',
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    'Starting in $_countdown…',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _startNow,
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
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      Text(
                        'Card ${_index + 1} of ${_cards.length}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text('$_index reviewed · ${_cards.length - _index} left'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: _index / _cards.length,
                    semanticsLabel: 'Session progress',
                    semanticsValue:
                        '$_index of ${_cards.length} cards reviewed',
                  ),
                  const SizedBox(height: 24),
                  Card.outlined(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Question',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            card.front,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              height: 1.35,
                            ),
                          ),
                          if (_revealed) ...[
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Divider(height: 1),
                            ),
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                'Answer',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              card.back,
                              style: theme.textTheme.titleLarge?.copyWith(
                                height: 1.4,
                              ),
                            ),
                          ] else ...[
                            const SizedBox(height: 24),
                            const Text(
                              'Recall the answer before revealing it.',
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (!_revealed)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(48, 52),
                      ),
                      onPressed: () => setState(() => _revealed = true),
                      icon: const Icon(Icons.visibility_outlined),
                      label: const Text('Show answer'),
                    )
                  else ...[
                    Text(
                      'How well did you recall it?',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final columns =
                            constraints.maxWidth >= 340 &&
                                    MediaQuery.textScalerOf(
                                          context,
                                        ).scale(16) <=
                                        22
                                ? 2
                                : 1;
                        final width =
                            (constraints.maxWidth - (columns - 1) * 12) /
                            columns;
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            for (final rating in const [
                              ('again', 'Again', 'Not yet'),
                              ('hard', 'Hard', 'With effort'),
                              ('good', 'Good', 'Recalled it'),
                              ('easy', 'Easy', 'Without effort'),
                            ])
                              SizedBox(
                                width: width,
                                child: _ratingButton(
                                  rating.$1,
                                  rating.$2,
                                  rating.$3,
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                  if (_saving) ...[
                    const SizedBox(height: 16),
                    const LinearProgressIndicator(
                      semanticsLabel: 'Saving review',
                    ),
                    const SizedBox(height: 8),
                    Semantics(
                      liveRegion: true,
                      child: const Text('Saving your review…'),
                    ),
                  ],
                  if (_failedRating != null) ...[
                    const SizedBox(height: 16),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        'Could not save this review. Your answer is still here. Try again or choose a rating.',
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
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
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _feedback!,
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
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

  Widget _ratingButton(String value, String label, String description) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 64),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      onPressed: _saving ? null : () => _rateCard(value),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(description, textAlign: TextAlign.center),
        ],
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
              Icon(
                empty ? Icons.check_circle_outline : Icons.celebration_outlined,
                size: 60,
                color: theme.colorScheme.primary,
              ),
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

