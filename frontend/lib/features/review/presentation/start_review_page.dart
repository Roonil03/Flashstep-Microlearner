import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/review_repository.dart';
import 'review_session_page.dart';

final reviewDecksProvider = FutureProvider.autoDispose<List<ReviewDeckSummary>>((ref) async {
  return ref.read(reviewRepositoryProvider).getReviewableDecks();
});

class StartReviewPage extends ConsumerWidget {
  const StartReviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final asyncDecks = ref.watch(reviewDecksProvider);

    final bgColor = isDark ? const Color(0xFF2A1243) : const Color(0xFFF1E4FF);
    final accent = isDark ? const Color(0xFFD8B4FE) : const Color(0xFF6B46C1);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Start review'),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Opacity(
                  opacity: isDark ? 0.10 : 0.13,
                  child: Image.asset(
                    'assets/LogoWithText_WithoutBG.png',
                    width: 240,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.auto_stories_rounded,
                      size: 180,
                      color: accent,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: asyncDecks.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Failed to load review decks: $error')),
              data: (decks) {
                if (decks.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_outline, size: 56, color: accent),
                          const SizedBox(height: 12),
                          Text(
                            'No cards are due right now.',
                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'When cards become due, they will appear here automatically.',
                            style: theme.textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                  itemCount: decks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final deck = decks[index];
                    return Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF160B28).withOpacity(0.84) : Colors.white.withOpacity(0.88),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: accent.withOpacity(0.22)),
                        boxShadow: const [
                          BoxShadow(blurRadius: 18, offset: Offset(0, 8), color: Colors.black12),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        title: Text(deck.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text('${deck.dueCount} card${deck.dueCount == 1 ? '' : 's'} due'),
                        ),
                        trailing: FilledButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ReviewSessionPage(
                                  deckId: deck.deckId,
                                  deckTitle: deck.title,
                                ),
                              ),
                            );
                          },
                          child: const Text('Start'),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}