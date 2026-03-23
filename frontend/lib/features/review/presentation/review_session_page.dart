import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/app_database.dart' as db;
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
  bool _revealed = false;
  int _countdown = 3;
  int _index = 0;
  List<db.Card> _cards = const [];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final cards = await ref.read(reviewRepositoryProvider).getDueCardsForDeck(widget.deckId);
    if (!mounted) return;
    setState(() {
      _cards = cards;
      _loading = false;
    });

    if (_cards.isEmpty) return;

    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countdown == 1) {
        timer.cancel();
        setState(() => _countdown = 0);
      } else {
        setState(() => _countdown -= 1);
      }
    });
  }

  Future<void> _rateCard(String rating) async {
    if (_index >= _cards.length) return;
    final current = _cards[_index];
    await ref.read(reviewRepositoryProvider).applyReview(card: current, rating: rating);
    if (!mounted) return;
    setState(() {
      _revealed = false;
      _index += 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1A102A) : const Color(0xFFF8F2FF);

    if (_loading) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(title: Text(widget.deckTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_cards.isEmpty || _index >= _cards.length) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(title: Text(widget.deckTitle)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.celebration_outlined, size: 60),
                const SizedBox(height: 12),
                Text(
                  'Review complete',
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text('All due cards in this deck were reviewed and stored locally.'),
              ],
            ),
          ),
        ),
      );
    }

    final card = _cards[_index];
    final progressText = '${_index + 1} / ${_cards.length}';

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text(widget.deckTitle),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Chip(label: Text('Progress $progressText')),
                      Chip(label: Text('${_cards.length - _index} left')),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 260),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isDark
                              ? const [Color(0xFF2F1B4E), Color(0xFF1C0F31)]
                              : const [Colors.white, Color(0xFFF1E6FF)],
                        ),
                        boxShadow: const [
                          BoxShadow(blurRadius: 22, offset: Offset(0, 10), color: Colors.black12),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _revealed ? 'Answer' : 'Question',
                            style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 18),
                          Expanded(
                            child: Center(
                              child: SingleChildScrollView(
                                child: Text(
                                  _revealed ? card.back : card.front,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (!_revealed)
                            FilledButton(
                              onPressed: () => setState(() => _revealed = true),
                              child: const Text('Show answer'),
                            )
                          else
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              alignment: WrapAlignment.center,
                              children: [
                                _ratingButton(context, 'again', 'Again'),
                                _ratingButton(context, 'hard', 'Hard'),
                                _ratingButton(context, 'good', 'Good'),
                                _ratingButton(context, 'easy', 'Easy'),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_countdown > 0)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black54,
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Text(
                      '$_countdown',
                      key: ValueKey(_countdown),
                      style: theme.textTheme.displayLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _ratingButton(BuildContext context, String value, String label) {
    return ElevatedButton(
      onPressed: () => _rateCard(value),
      child: Text(label),
    );
  }
}