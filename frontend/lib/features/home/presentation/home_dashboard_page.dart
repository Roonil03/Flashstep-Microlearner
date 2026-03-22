import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router.dart';
import '../domain/home_dashboard_models.dart';

final homeDashboardProvider = FutureProvider<HomeDashboardData>((ref) async {
  await Future<void>.delayed(const Duration(milliseconds: 450));

  final decks = <DeckSummary>[
    DeckSummary(
      id: 'd1',
      title: 'Frontend System Design',
      description: 'Flutter architecture, state management, UI patterns, and app flow.',
      totalCards: 184,
      dueCards: 24,
      progress: 0.72,
      isPublic: false,
      nextDueAt: DateTime.now().add(const Duration(hours: 2)),
      updatedAt: DateTime.now().subtract(const Duration(minutes: 12)),
    ),
    DeckSummary(
      id: 'd2',
      title: 'Go Backend APIs',
      description: 'JWT auth, REST endpoints, sync, and database integration.',
      totalCards: 96,
      dueCards: 10,
      progress: 0.48,
      isPublic: false,
      nextDueAt: DateTime.now().add(const Duration(hours: 5)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 1)),
    ),
    DeckSummary(
      id: 'd3',
      title: 'Spaced Repetition Core',
      description: 'SM-2, FSRS concepts, review rules, and scheduling logic.',
      totalCards: 128,
      dueCards: 33,
      progress: 0.81,
      isPublic: true,
      nextDueAt: DateTime.now().add(const Duration(minutes: 35)),
      updatedAt: DateTime.now().subtract(const Duration(minutes: 28)),
    ),
    DeckSummary(
      id: 'd4',
      title: 'Database & Sync',
      description: 'Isar, Drift, sync queue, conflict handling, and offline-first flow.',
      totalCards: 112,
      dueCards: 8,
      progress: 0.62,
      isPublic: false,
      nextDueAt: DateTime.now().add(const Duration(hours: 8)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
  ];

  return HomeDashboardData(
    displayName: 'Ru',
    decksCount: decks.length,
    dueToday: decks.fold<int>(0, (sum, deck) => sum + deck.dueCards),
    reviewedToday: 38,
    streak: 12,
    retentionRate: 86.4,
    isOffline: false,
    isSyncing: false,
    lastSyncedAt: DateTime.now().subtract(const Duration(minutes: 6)),
    deckOfTheDay: decks[2],
    decks: decks,
  );
});

class HomeDashboardPage extends ConsumerStatefulWidget {
  const HomeDashboardPage({super.key});

  @override
  ConsumerState<HomeDashboardPage> createState() => _HomeDashboardPageState();
}

class _HomeDashboardPageState extends ConsumerState<HomeDashboardPage> {
  Future<void> _refreshDashboard() async {
    ref.invalidate(homeDashboardProvider);
    await ref.read(homeDashboardProvider.future);
  }

  String _timeLabel(DateTime? time) {
    if (time == null) return 'Not scheduled';
    final diff = time.difference(DateTime.now());
    if (diff.inMinutes <= 0) return 'Due now';
    if (diff.inHours == 0) return 'In ${diff.inMinutes} min';
    return 'In ${diff.inHours} h ${diff.inMinutes.remainder(60)} min';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshDashboard,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverAppBar(
                pinned: true,
                floating: false,
                elevation: 0,
                backgroundColor: theme.scaffoldBackgroundColor,
                title: const Text(
                  'Home',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                actions: [
                  IconButton(
                    tooltip: 'Analytics',
                    icon: const Icon(Icons.insights_outlined),
                    onPressed: () => Navigator.of(context).pushNamed(AppRoutes.analytics),
                  ),
                  IconButton(
                    tooltip: 'Settings',
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: () => Navigator.of(context).pushNamed(AppRoutes.settings),
                  ),
                  const SizedBox(width: 6),
                ],
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                sliver: Consumer(
                  builder: (context, ref, _) {
                    final dashboardAsync = ref.watch(homeDashboardProvider);

                    return dashboardAsync.when(
                      loading: () => SliverList(
                        delegate: SliverChildListDelegate(
                          [
                            _LoadingCard(isDark: isDark),
                            const SizedBox(height: 16),
                            _LoadingCard(isDark: isDark, short: true),
                            const SizedBox(height: 16),
                            _LoadingCard(isDark: isDark, short: true),
                          ],
                        ),
                      ),
                      error: (error, stack) => SliverFillRemaining(
                        hasScrollBody: false,
                        child: _ErrorState(
                          message: error.toString(),
                          onRetry: _refreshDashboard,
                        ),
                      ),
                      data: (data) {
                        return SliverList(
                          delegate: SliverChildListDelegate(
                            [
                              _TopGreetingCard(
                                displayName: data.displayName,
                                isOffline: data.isOffline,
                                isSyncing: data.isSyncing,
                                lastSyncedAt: data.lastSyncedAt,
                                dueToday: data.dueToday,
                                decksCount: data.decksCount,
                                reviewedToday: data.reviewedToday,
                                streak: data.streak,
                              ),
                              const SizedBox(height: 16),
                              _DeckOfTheDayCard(
                                deck: data.deckOfTheDay,
                                timeLabel: _timeLabel(data.deckOfTheDay.nextDueAt),
                                onStartReview: () => Navigator.of(context).pushNamed(
                                  AppRoutes.review,
                                  arguments: data.deckOfTheDay.id,
                                ),
                                onOpenDeck: () => Navigator.of(context).pushNamed(
                                  AppRoutes.browseDecks,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _QuickActionsGrid(
                                onCreateDeck: () => Navigator.of(context).pushNamed(AppRoutes.createDeck),
                                onStartReview: () => Navigator.of(context).pushNamed(AppRoutes.review),
                                onBrowseDecks: () => Navigator.of(context).pushNamed(AppRoutes.browseDecks),
                                onAnalytics: () => Navigator.of(context).pushNamed(AppRoutes.analytics),
                              ),
                              const SizedBox(height: 16),
                              _MiniStatsRow(
                                dueToday: data.dueToday,
                                reviewedToday: data.reviewedToday,
                                retentionRate: data.retentionRate,
                              ),
                              const SizedBox(height: 18),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Your decks',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pushNamed(AppRoutes.browseDecks),
                                    child: const Text('Browse all'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ...data.decks.map(
                                (deck) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _DeckCard(
                                    deck: deck,
                                    onTap: () => Navigator.of(context).pushNamed(
                                      AppRoutes.review,
                                      arguments: deck.id,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              _SyncFooterCard(
                                isOffline: data.isOffline,
                                isSyncing: data.isSyncing,
                                lastSyncedAt: data.lastSyncedAt,
                                onForceSync: _refreshDashboard,
                              ),
                              const SizedBox(height: 18),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).pushNamed(AppRoutes.createDeck),
        icon: const Icon(Icons.add),
        label: const Text('New deck'),
      ),
    );
  }
}

class _TopGreetingCard extends StatelessWidget {
  final String displayName;
  final bool isOffline;
  final bool isSyncing;
  final DateTime? lastSyncedAt;
  final int dueToday;
  final int decksCount;
  final int reviewedToday;
  final int streak;

  const _TopGreetingCard({
    required this.displayName,
    required this.isOffline,
    required this.isSyncing,
    required this.lastSyncedAt,
    required this.dueToday,
    required this.decksCount,
    required this.reviewedToday,
    required this.streak,
  });

  String _syncText() {
    if (isOffline) return 'Offline mode';
    if (isSyncing) return 'Syncing now';
    if (lastSyncedAt == null) return 'Not synced yet';
    return 'Synced recently';
  }

  String _lastSyncTime() {
    if (lastSyncedAt == null) return 'No sync time';
    final diff = DateTime.now().difference(lastSyncedAt!);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes} min ago';
    return '${diff.inHours} h ago';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF132238), const Color(0xFF1C2F4A)]
              : [const Color(0xFFEAF6FF), const Color(0xFFF4ECFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 24,
            offset: const Offset(0, 10),
            color: Colors.black.withOpacity(isDark ? 0.28 : 0.08),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: isDark ? Colors.white12 : Colors.white,
                child: Icon(
                  Icons.school_rounded,
                  color: isDark ? Colors.white : const Color(0xFF003153),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back, $displayName',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _syncText(),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
              _SyncChip(
                label: _syncText(),
                value: isOffline ? 'No internet' : _lastSyncTime(),
                icon: isOffline ? Icons.wifi_off_rounded : Icons.sync_rounded,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'Due today',
                  value: '$dueToday',
                  icon: Icons.today_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTile(
                  label: 'Decks',
                  value: '$decksCount',
                  icon: Icons.layers_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'Reviewed',
                  value: '$reviewedToday',
                  icon: Icons.fact_check_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTile(
                  label: 'Streak',
                  value: '$streak days',
                  icon: Icons.local_fire_department_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeckOfTheDayCard extends StatelessWidget {
  final DeckSummary deck;
  final String timeLabel;
  final VoidCallback onStartReview;
  final VoidCallback onOpenDeck;

  const _DeckOfTheDayCard({
    required this.deck,
    required this.timeLabel,
    required this.onStartReview,
    required this.onOpenDeck,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE7E7E7),
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            offset: const Offset(0, 8),
            color: Colors.black.withOpacity(isDark ? 0.28 : 0.06),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: const Color(0xFF003153).withOpacity(isDark ? 0.32 : 0.08),
                ),
                child: Text(
                  'Deck of the day',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF003153),
                  ),
                ),
              ),
              const Spacer(),
              Text(
                timeLabel,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            deck.title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            deck.description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withOpacity(0.85),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LinearProgressIndicator(
              value: deck.progress,
              minHeight: 10,
              backgroundColor: isDark ? Colors.white10 : const Color(0xFFEDEDED),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                '${(deck.progress * 100).round()}% complete',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '${deck.dueCards} cards due',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: onStartReview,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Start review'),
              ),
              OutlinedButton.icon(
                onPressed: onOpenDeck,
                icon: const Icon(Icons.folder_open_outlined),
                label: const Text('Open deck'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  final VoidCallback onCreateDeck;
  final VoidCallback onStartReview;
  final VoidCallback onBrowseDecks;
  final VoidCallback onAnalytics;

  const _QuickActionsGrid({
    required this.onCreateDeck,
    required this.onStartReview,
    required this.onBrowseDecks,
    required this.onAnalytics,
  });

  @override
  Widget build(BuildContext context) {
    final actions = <_QuickAction>[
      _QuickAction(
        icon: Icons.add_circle_outline,
        title: 'Create deck',
        subtitle: 'Build new study material',
        onTap: onCreateDeck,
      ),
      _QuickAction(
        icon: Icons.play_circle_outline,
        title: 'Start review',
        subtitle: 'Continue your session',
        onTap: onStartReview,
      ),
      _QuickAction(
        icon: Icons.search_rounded,
        title: 'Browse decks',
        subtitle: 'Find public decks',
        onTap: onBrowseDecks,
      ),
      _QuickAction(
        icon: Icons.insights_outlined,
        title: 'Analytics',
        subtitle: 'Track retention and streaks',
        onTap: onAnalytics,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 500 ? 4 : 2;
        return GridView.builder(
          itemCount: actions.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.2,
          ),
          itemBuilder: (context, index) {
            final action = actions[index];
            return InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: action.onTap,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(action.icon, size: 28),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          action.title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          action.subtitle,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _MiniStatsRow extends StatelessWidget {
  final int dueToday;
  final int reviewedToday;
  final double retentionRate;

  const _MiniStatsRow({
    required this.dueToday,
    required this.reviewedToday,
    required this.retentionRate,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            title: 'Due today',
            value: '$dueToday',
            subtitle: 'Cards waiting',
            icon: Icons.schedule_outlined,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            title: 'Reviewed',
            value: '$reviewedToday',
            subtitle: 'Today',
            icon: Icons.check_circle_outline,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            title: 'Retention',
            value: '${retentionRate.toStringAsFixed(1)}%',
            subtitle: 'Average',
            icon: Icons.verified_outlined,
          ),
        ),
      ],
    );
  }
}

class _DeckCard extends StatelessWidget {
  final DeckSummary deck;
  final VoidCallback onTap;

  const _DeckCard({
    required this.deck,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: theme.dividerColor.withOpacity(0.45)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    deck.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (deck.isPublic)
                  const Icon(Icons.public, size: 18)
                else
                  const Icon(Icons.lock_outline, size: 18),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              deck.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: deck.progress,
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _SmallPill(text: '${deck.totalCards} cards'),
                const SizedBox(width: 8),
                _SmallPill(text: '${deck.dueCards} due'),
                const SizedBox(width: 8),
                _SmallPill(text: deck.nextDueAt == null ? 'No due time' : 'Next: ${_formatTime(deck.nextDueAt!)}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _SyncFooterCard extends StatelessWidget {
  final bool isOffline;
  final bool isSyncing;
  final DateTime? lastSyncedAt;
  final VoidCallback onForceSync;

  const _SyncFooterCard({
    required this.isOffline,
    required this.isSyncing,
    required this.lastSyncedAt,
    required this.onForceSync,
  });

  String _label() {
    if (isOffline) return 'You are offline. Local DB is the source of truth.';
    if (isSyncing) return 'Syncing changes with the server...';
    if (lastSyncedAt == null) return 'No sync history yet.';
    final diff = DateTime.now().difference(lastSyncedAt!);
    if (diff.inMinutes < 1) return 'Last synced just now.';
    if (diff.inHours < 1) return 'Last synced ${diff.inMinutes} min ago.';
    return 'Last synced ${diff.inHours} h ago.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: theme.cardColor,
        border: Border.all(color: theme.dividerColor.withOpacity(0.45)),
      ),
      child: Row(
        children: [
          Icon(
            isOffline
                ? Icons.wifi_off_rounded
                : isSyncing
                    ? Icons.sync_rounded
                    : Icons.cloud_done_outlined,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _label(),
              style: theme.textTheme.bodyMedium,
            ),
          ),
          TextButton(
            onPressed: onForceSync,
            child: const Text('Sync now'),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: theme.textTheme.labelMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18),
          const SizedBox(height: 10),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _SmallPill extends StatelessWidget {
  final String text;

  const _SmallPill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Theme.of(context).dividerColor.withOpacity(0.10),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _SyncChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _SyncChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 130),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.20),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

class _QuickAction {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  _QuickAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
}

class _LoadingCard extends StatelessWidget {
  final bool isDark;
  final bool short;

  const _LoadingCard({
    required this.isDark,
    this.short = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: short ? 120 : 220,
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.black12,
        borderRadius: BorderRadius.circular(24),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 52),
            const SizedBox(height: 14),
            Text(
              'Could not load your dashboard',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}