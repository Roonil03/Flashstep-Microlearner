import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router.dart';
import '../../../app/theme/study_colors.dart';
import '../data/review_repository.dart';
import 'review_session_page.dart';

final reviewDecksProvider = FutureProvider.autoDispose<List<ReviewDeckSummary>>(
  (ref) async => ref.read(reviewRepositoryProvider).getReviewableDecks(),
);

class StartReviewPage extends ConsumerWidget {
  const StartReviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tone = context.studyTone(StudyArea.study);
    final decks = ref.watch(reviewDecksProvider);
    void refresh() => ref.invalidate(reviewDecksProvider);
    Future<void> openAndRefresh(String route) async {
      await Navigator.of(context).pushNamed(route);
      if (context.mounted) refresh();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Start review'),
        actions: [
          IconButton(
            tooltip: 'Refresh available cards',
            onPressed: decks.isLoading ? null : refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: decks.when(
              loading:
                  () => const Center(
                    child: CircularProgressIndicator(
                      semanticsLabel: 'Loading review decks',
                    ),
                  ),
              error:
                  (error, _) => ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      Icon(
                        Icons.cloud_off_outlined,
                        size: 48,
                        color: tone.accent,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Could not load review decks',
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Your saved decks live on this device. Try loading them again, or open your library.',
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: refresh,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Try again'),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => openAndRefresh(AppRoutes.browseDecks),
                        icon: const Icon(Icons.menu_book_outlined),
                        label: const Text('View decks'),
                      ),
                    ],
                  ),
              data: (availableDecks) {
                final count = availableDecks.fold<int>(
                  0,
                  (total, deck) => total + deck.dueCount,
                );
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: tone.fill,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.auto_stories_rounded,
                            color: tone.ink,
                            size: 40,
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'YOUR STUDY NOTEBOOK',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: tone.ink,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'A little practice.\nA stronger memory.',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              color: tone.ink,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '$count card${count == 1 ? '' : 's'} ready for your next session.',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: tone.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.offline_pin_outlined,
                          size: 22,
                          color: tone.accent,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Study saved cards online or offline. Ratings save on this device.',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Text(
                      availableDecks.isEmpty
                          ? 'No cards available for review'
                          : 'Choose a deck',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (availableDecks.isEmpty) ...[
                      const Text(
                        'You may be caught up or have reached your daily limit. You can manage your decks or check settings.',
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: () => openAndRefresh(AppRoutes.browseDecks),
                        icon: const Icon(Icons.menu_book_outlined),
                        label: const Text('View decks'),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => openAndRefresh(AppRoutes.settings),
                        icon: const Icon(Icons.settings_outlined),
                        label: const Text('Settings'),
                      ),
                    ],
                    for (
                      var index = 0;
                      index < availableDecks.length;
                      index++
                    ) ...[
                      _DeckSheet(
                        deck: availableDecks[index],
                        number: index + 1,
                        onPressed: () async {
                          final deck = availableDecks[index];
                          await Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder:
                                  (_) => ReviewSessionPage(
                                    deckId: deck.deckId,
                                    deckTitle: deck.title,
                                  ),
                            ),
                          );
                          if (context.mounted) refresh();
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _DeckSheet extends StatelessWidget {
  const _DeckSheet({
    required this.deck,
    required this.number,
    required this.onPressed,
  });
  final ReviewDeckSummary deck;
  final int number;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tone = context.studyTone(StudyArea.study);
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tone.accent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              color: tone.fill,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(15),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Text(
              'NOTEBOOK ${number.toString().padLeft(2, '0')}  /  ${deck.dueCount} ready',
              style: theme.textTheme.labelLarge?.copyWith(
                color: tone.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  deck.title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 18),
                Semantics(
                  label: 'Start review for ${deck.title}',
                  excludeSemantics: true,
                  button: true,
                  onTap: onPressed,
                  child: FilledButton.icon(
                    onPressed: onPressed,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Start review'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(48, 56),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
