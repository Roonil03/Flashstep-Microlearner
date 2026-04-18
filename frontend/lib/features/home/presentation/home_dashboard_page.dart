import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;

import '../../../app/router.dart';
import '../../../core/storage/database_provider.dart';
import '../../../core/storage/session_storage.dart';
import '../data/home_repository.dart';
import '../../decks/data/data_sync_service.dart';
import '../domain/home_dashboard_models.dart';

final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  return HomeRepository(ref.watch(appDatabaseProvider), const SessionStorage());
});

final usernameProvider = FutureProvider<String>((ref) async {
  final repository = ref.watch(homeRepositoryProvider);
  final username = await repository.getUsername();
  return username?.isNotEmpty == true ? username! : 'User';
});

final userDecksProvider = FutureProvider<List<DeckSummary>>((ref) async {
  final repository = ref.watch(homeRepositoryProvider);
  return repository.getDecks();
});

final homeDashboardProvider = FutureProvider<HomeDashboardData>((ref) async {
  final repository = ref.watch(homeRepositoryProvider);
  final username = await ref.watch(usernameProvider.future);
  final decks = await ref.watch(userDecksProvider.future);
  final sessionStorage = const SessionStorage();
  final dashboardStats = await repository.getDashboardStats();

  final dailyReviewLimit = await sessionStorage.readDailyReviewLimit();
  final rawDueToday = decks.fold<int>(0, (sum, deck) => sum + deck.dueCards);
  final dueToday = math.min(rawDueToday, dailyReviewLimit);
  final lastSyncedAt = await sessionStorage.readLastSyncAt();

  DeckSummary? deckOfTheDay;
  for (final deck in decks) {
    if (deck.dueCards > 0) {
      deckOfTheDay = deck;
      break;
    }
  }
  deckOfTheDay ??= decks.isNotEmpty ? decks.first : null;

  return HomeDashboardData(
    displayName: username,
    decksCount: decks.length,
    dueToday: dueToday,
    reviewedToday: dashboardStats.reviewedToday,
    streak: dashboardStats.streak,
    retentionRate: dashboardStats.retentionRate,
    isOffline: false,
    isSyncing: false,
    lastSyncedAt: lastSyncedAt,
    deckOfTheDay: deckOfTheDay,
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
    await ref.read(deckSyncServiceProvider).syncNow();
    ref.invalidate(usernameProvider);
    ref.invalidate(userDecksProvider);
    ref.invalidate(homeDashboardProvider);
    await ref.read(homeDashboardProvider.future);
  }

  Future<void> _openCreateDeck() async {
    await Navigator.of(context).pushNamed(AppRoutes.createDeck);
    if (!mounted) return;
    await _refreshDashboard();
  }

  Future<void> _openDeckDetail(String deckId) async {
    await Navigator.of(context).pushNamed(
      AppRoutes.deckDetail,
      arguments: deckId,
    );
    if (!mounted) return;
    await _refreshDashboard();
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).pushNamed(AppRoutes.settings);
    if (!mounted) return;

    ref.invalidate(homeDashboardProvider);
    await ref.read(homeDashboardProvider.future);
  }

  String _timeLabel(DateTime? time, {required int dueCards}) {
    if (time == null) {
      return dueCards > 0 ? 'Due now' : 'Not scheduled';
    }
    final diff = time.difference(DateTime.now());
    if (diff.inMinutes <= 0){
      return 'Due now';
    }
    if (diff.inHours == 0){
      return 'In ${diff.inMinutes} min';
    }
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
                    onPressed: _openSettings,
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
                          message: 'Error loading dashboard: $error',
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
                              if (data.deckOfTheDay != null)
                                Column(
                                  children: [
                                    _DeckOfTheDayCard(
                                      deck: data.deckOfTheDay!,
                                      timeLabel: _timeLabel(
                                        data.deckOfTheDay!.nextDueAt,
                                        dueCards: data.deckOfTheDay!.dueCards,
                                      ),
                                      onStartReview: () => Navigator.of(context).pushNamed(
                                        AppRoutes.review,
                                        arguments: data.deckOfTheDay!.id,
                                      ),
                                      onOpenDeck: () => _openDeckDetail(data.deckOfTheDay!.id),
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                ),
                              _QuickActionsGrid(
                                onCreateDeck: _openCreateDeck,
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
                              if (data.decks.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 24),
                                  child: Center(
                                    child: Text(
                                      'Damn, this place looks empty. Where are the cards?',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        fontStyle: FontStyle.italic,
                                        color: theme.textTheme.bodySmall?.color,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                )
                              else
                                ...data.decks.map(
                                  (deck) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _DeckCard(
                                      deck: deck,
                                      onTap: () => _openDeckDetail(deck.id),
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
    final localSyncTime = lastSyncedAt!.toLocal();
    final now = DateTime.now();
    final diff = now.difference(localSyncTime);
    if (diff.inSeconds < 0) return 'just now';
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes} min ago';
    if (diff.inDays < 1) {
      return '${diff.inHours} h ${diff.inMinutes.remainder(60)} min ago';
    }
    if (diff.inDays == 1) return 'Yesterday';
    return '${localSyncTime.day.toString().padLeft(2, '0')}/'
        '${localSyncTime.month.toString().padLeft(2, '0')}/'
        '${localSyncTime.year}';
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back,',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color:
                            theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      displayName,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: isDark
                      ? const Color(0xFF1A3A52)
                      : const Color(0xFFD5EEFF),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSyncing ? Icons.sync : Icons.check_circle,
                      size: 14,
                      color: isOffline
                          ? Colors.orange
                          : isSyncing
                              ? Colors.blue
                              : Colors.green,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _syncText(),
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _lastSyncTime(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.calendar_today,
                  label: 'Due Today',
                  value: '$dueToday cards',
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatTile(
                  icon: Icons.layers,
                  label: 'Your Decks',
                  value: '$decksCount total',
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.done_all,
                  label: 'Reviewed',
                  value: '$reviewedToday today',
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatTile(
                  icon: Icons.local_fire_department,
                  label: 'Streak',
                  value: '$streak days',
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isDark ? const Color(0xFF1F3D54) : Colors.white.withOpacity(0.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: Colors.blue),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style:
                theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isDark ? const Color(0xFF1C2E3F) : const Color(0xFFEFF8FF),
        border: Border.all(
          color: isDark ? const Color(0xFF2A4060) : const Color(0xFFB8E0FF),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Deck of the day',
                  style: theme.textTheme.labelLarge,
                ),
              ),
              const Icon(Icons.star, size: 18, color: Colors.amber),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            deck.title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            deck.description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Text(
            '${deck.dueCards} due — $timeLabel',
            style: theme.textTheme.labelSmall,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: onStartReview,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(40),
                  ),
                  child: const Text('Start review'),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: onOpenDeck,
                child: const Text('Open'),
              ),
            ],
          ),
        ],
      ),
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
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isDark ? const Color(0xFF1A2D3D) : const Color(0xFFF5F5F5),
          border: Border.all(
            color: isDark ? const Color(0xFF2E4556) : const Color(0xFFE0E0E0),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    deck.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (deck.isPublic)
                  const Icon(Icons.public, size: 16, color: Colors.blue),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${deck.totalCards} cards • ${deck.dueCards} due',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: deck.progress.clamp(0.0, 1.0),
                minHeight: 6,
              ),
            ),
          ],
        ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _QuickActionButton(
          icon: Icons.add_circle_outline,
          label: 'New Deck',
          onTap: onCreateDeck,
          isDark: isDark,
        ),
        _QuickActionButton(
          icon: Icons.play_circle_outline,
          label: 'Start Review',
          onTap: onStartReview,
          isDark: isDark,
        ),
        _QuickActionButton(
          icon: Icons.explore_outlined,
          label: 'Browse',
          onTap: onBrowseDecks,
          isDark: isDark,
        ),
        _QuickActionButton(
          icon: Icons.bar_chart_outlined,
          label: 'Analytics',
          onTap: onAnalytics,
          isDark: isDark,
        ),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDark;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isDark ? const Color(0xFF1A2D3D) : const Color(0xFFF5F5F5),
          border: Border.all(
            color: isDark ? const Color(0xFF2E4556) : const Color(0xFFE0E0E0),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.circle, size: 0), // keeps layout stable
            Icon(icon, size: 32, color: Colors.blue),
            const SizedBox(height: 8),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Widget tile(String label, String value) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isDark ? const Color(0xFF1A2D3D) : const Color(0xFFF5F5F5),
          ),
          child: Column(
            children: [
              Text(label, style: theme.textTheme.labelSmall),
              const SizedBox(height: 4),
              Text(
                value,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        tile('Due Today', '$dueToday'),
        const SizedBox(width: 12),
        tile('Reviewed', '$reviewedToday'),
        const SizedBox(width: 12),
        tile('Retention', '${retentionRate.toStringAsFixed(1)}%'),
      ],
    );
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final localSyncTime = lastSyncedAt?.toLocal();
    final hour = localSyncTime?.hour.toString().padLeft(2, '0') ?? '00';
    final minute = localSyncTime?.minute.toString().padLeft(2, '0') ?? '00';
    final day = localSyncTime?.day.toString().padLeft(2, '0') ?? '00';
    final month = localSyncTime?.month.toString().padLeft(2, '0') ?? '00';
    final year = localSyncTime?.year.toString() ?? '0000';
    final now = DateTime.now();
    final isToday = localSyncTime != null &&
        localSyncTime.year == now.year &&
        localSyncTime.month == now.month &&
        localSyncTime.day == now.day;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isDark ? const Color(0xFF1A2D3D) : const Color(0xFFF5F5F5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isOffline ? 'Offline mode' : isSyncing ? 'Syncing...' : 'All synced',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                lastSyncedAt == null
                    ? 'Not synced yet'
                    : isToday
                        ? 'Last sync: $hour:$minute'
                        : 'Last sync: $day/$month/$year $hour:$minute',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: onForceSync,
          ),
        ],
      ),
    );
  }
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
      height: short ? 60 : 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isDark ? const Color(0xFF1A2D3D) : const Color(0xFFF5F5F5),
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
    final theme = Theme.of(context);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline, size: 48, color: Colors.red),
        const SizedBox(height: 16),
        Text(
          'Error loading dashboard',
          style: theme.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          message,
          style: theme.textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ],
    );
  }
}