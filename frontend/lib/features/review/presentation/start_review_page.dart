import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router.dart';
import '../data/review_repository.dart';
import 'review_session_page.dart';

final reviewDecksProvider = FutureProvider.autoDispose<List<ReviewDeckSummary>>(
  (ref) async {
    return ref.read(reviewRepositoryProvider).getReviewableDecks();
  },
);

class StartReviewPage extends ConsumerWidget {
  const StartReviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final asyncDecks = ref.watch(reviewDecksProvider);
    void refresh() => ref.invalidate(reviewDecksProvider);
    Future<void> openAndRefresh(String route) async {
      await Navigator.of(context).pushNamed(route);
      if (context.mounted) ref.invalidate(reviewDecksProvider);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Start review'),
        actions: [
          IconButton(
            tooltip: 'Refresh available cards',
            onPressed: asyncDecks.isLoading ? null : refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: asyncDecks.when(
          loading:
              () => const Center(
                child: CircularProgressIndicator(
                  semanticsLabel: 'Loading review decks',
                ),
              ),
          error:
              (error, _) => Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        'Could not load review decks',
                        style: theme.textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Try loading your available cards again.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: refresh,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              ),
          data: (decks) {
            if (decks.isEmpty) {
              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 56,
                        color: colors.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No cards available for review',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'You may be caught up or have reached your daily limit. You can manage your decks or check settings.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.center,
                        children: [
                          FilledButton.icon(
                            onPressed:
                                () => openAndRefresh(AppRoutes.browseDecks),
                            icon: const Icon(Icons.style_outlined),
                            label: const Text('View decks'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => openAndRefresh(AppRoutes.settings),
                            icon: const Icon(Icons.settings_outlined),
                            label: const Text('Settings'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }
            final available = decks.fold<int>(
              0,
              (total, deck) => total + deck.dueCount,
            );
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              itemCount: decks.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Choose a deck',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$available card${available == 1 ? '' : 's'} available across ${decks.length} deck${decks.length == 1 ? '' : 's'}.',
                      ),
                    ],
                  );
                }
                final deck = decks[index - 1];
                return Card.outlined(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          deck.title,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${deck.dueCount} card${deck.dueCount == 1 ? '' : 's'} available',
                        ),
                        const SizedBox(height: 20),
                        Semantics(
                          label: 'Start review for ${deck.title}',
                          excludeSemantics: true,
                          button: true,
                          onTap: () => _start(context, deck),
                          child: FilledButton.icon(
                            onPressed: () => _start(context, deck),
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: const Text('Start review'),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(48, 48),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _start(BuildContext context, ReviewDeckSummary deck) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) =>
                ReviewSessionPage(deckId: deck.deckId, deckTitle: deck.title),
      ),
    );
  }
}
