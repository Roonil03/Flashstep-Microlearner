import '../../../core/network/providers.dart';
import '../../onboarding/presentation/navigation_tour_launcher.dart';
import '../../../core/widgets/learning_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;

import '../../../app/router.dart';
import '../../../core/storage/database_provider.dart';
import '../../../core/storage/session_storage.dart';
import '../data/home_repository.dart';
import '../../decks/data/data_sync_service.dart';
import '../../decks/data/sync_status.dart';
import '../domain/home_dashboard_models.dart';

// Local table changes also invalidate the rendered dashboard, including when
// another route saved a review while Home remained mounted in the navigator.
final homeDataRevisionProvider = StateProvider<int>((ref) => 0);

final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  final repository = HomeRepository(
    ref.watch(appDatabaseProvider),
    const SessionStorage(),
    onDataChanged: () {
      ref.read(homeDataRevisionProvider.notifier).state++;
    },
  );
  ref.onDispose(repository.dispose);
  return repository;
});

final homePendingSyncCountProvider = StreamProvider.autoDispose
    .family<int, String?>((ref, userId) {
      if (userId == null || userId.isEmpty) return Stream.value(0);
      return ref.watch(homeRepositoryProvider).watchPendingSyncCount(userId);
    });

final usernameProvider = FutureProvider<String>((ref) async {
  final repository = ref.watch(homeRepositoryProvider);
  final username = await repository.getUsername();
  return username?.isNotEmpty == true ? username! : 'User';
});

final userDecksProvider = FutureProvider<List<DeckSummary>>((ref) async {
  ref.watch(homeDataRevisionProvider);
  final repository = ref.watch(homeRepositoryProvider);
  return repository.getDecks();
});

final homeDashboardProvider = FutureProvider<HomeDashboardData>((ref) async {
  ref.watch(homeDataRevisionProvider);
  final repository = ref.watch(homeRepositoryProvider);
  final sessionStorage = const SessionStorage();
  final userId = await sessionStorage.readUserId();
  final username = await ref.watch(usernameProvider.future);
  final decks = await ref.watch(userDecksProvider.future);
  final dashboardStats = await repository.getDashboardStats();

  final dailyReviewLimit = await sessionStorage.readDailyReviewLimit();
  final rawDueToday = decks.fold<int>(0, (sum, deck) => sum + deck.dueCards);
  final bypass = await sessionStorage.readBypassSrs();
  final selective = await sessionStorage.readSelectiveReviewDecksOnly();
  final dueToday =
      bypass
          ? decks.fold<int>(0, (sum, deck) => sum + deck.totalCards)
          : selective
          ? math.min(
            rawDueToday,
            math.max(0, dailyReviewLimit - dashboardStats.reviewedToday),
          )
          : rawDueToday;
  final lastSyncedAt =
      userId == null || userId.isEmpty
          ? null
          : await sessionStorage.readLastSyncAt(userId: userId);

  DeckSummary? deckOfTheDay;
  for (final deck in decks) {
    if (deck.dueCards > 0) {
      deckOfTheDay = deck;
      break;
    }
  }
  deckOfTheDay ??= decks.isNotEmpty ? decks.first : null;

  return HomeDashboardData(
    userId: userId,
    displayName: username,
    decksCount: decks.length,
    dueToday: dueToday,
    reviewedToday: dashboardStats.reviewedToday,
    streak: dashboardStats.streak,
    retentionRate: dashboardStats.retentionRate,
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        launchNavigationTour(context, ref.read(sessionStorageProvider));
      }
    });
  }

  Future<void> _refreshDashboard() async {
    await ref.read(deckSyncServiceProvider).syncNow();
    if (!mounted) return;
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
    await Navigator.of(
      context,
    ).pushNamed(AppRoutes.deckDetail, arguments: deckId);
    if (!mounted) return;
    await _refreshDashboard();
  }

  Future<void> _openBrowseDecks() async {
    await Navigator.of(context).pushNamed(AppRoutes.browseDecks);
    if (!mounted) return;
    ref.invalidate(userDecksProvider);
    ref.invalidate(homeDashboardProvider);
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).pushNamed(AppRoutes.settings);
    if (!mounted) return;

    ref.invalidate(homeDashboardProvider);
    await ref.read(homeDashboardProvider.future);
  }

  Future<void> _openReview([String? deckId]) async {
    await Navigator.of(context).pushNamed(AppRoutes.review, arguments: deckId);
    if (!mounted) return;
    ref.invalidate(userDecksProvider);
    ref.invalidate(homeDashboardProvider);
  }

  String _timeLabel(DateTime? time, {required int dueCards}) {
    if (dueCards > 0) return 'Due now';
    if (time == null) {
      return 'Not scheduled';
    }
    final diff = time.difference(DateTime.now());
    if (diff.inMinutes <= 0) {
      return 'Due now';
    }
    if (diff.inHours == 0) {
      return 'In ${diff.inMinutes} min';
    }
    return 'In ${diff.inHours} h ${diff.inMinutes.remainder(60)} min';
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<SyncStatus>(syncStatusProvider, (previous, next) {
      if (next.phase == SyncPhase.success &&
          previous?.phase != SyncPhase.success) {
        ref.invalidate(userDecksProvider);
        ref.invalidate(homeDashboardProvider);
      }
    });
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
                    onPressed:
                        () => Navigator.of(
                          context,
                        ).pushNamed(AppRoutes.analytics),
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
                      loading:
                          () => SliverList(
                            delegate: SliverChildListDelegate([
                              _LoadingCard(isDark: isDark),
                              const SizedBox(height: 16),
                              _LoadingCard(isDark: isDark, short: true),
                              const SizedBox(height: 16),
                              _LoadingCard(isDark: isDark, short: true),
                            ]),
                          ),
                      error:
                          (error, stack) => SliverFillRemaining(
                            hasScrollBody: false,
                            child: _ErrorState(
                              message:
                                  'Could not load your dashboard. Reopen the page and try again.',
                              onRetry: _refreshDashboard,
                            ),
                          ),
                      data: (data) {
                        final pendingSyncCount =
                            ref
                                .watch(
                                  homePendingSyncCountProvider(data.userId),
                                )
                                .valueOrNull;
                        final currentStatus = ref.watch(syncStatusProvider);
                        final syncStatus =
                            currentStatus.userId == data.userId
                                ? currentStatus
                                : const SyncStatus();
                        final lastSuccessfulAt =
                            syncStatus.lastSuccessfulAt ?? data.lastSyncedAt;
                        return SliverList(
                          delegate: SliverChildListDelegate([
                            _StudyOverview(
                              data: data,
                              onReview: () => _openReview(),
                              onOpenDeck:
                                  data.deckOfTheDay == null
                                      ? null
                                      : () => _openDeckDetail(
                                        data.deckOfTheDay!.id,
                                      ),
                              timeLabel:
                                  data.deckOfTheDay == null
                                      ? null
                                      : _timeLabel(
                                        data.deckOfTheDay!.nextDueAt,
                                        dueCards: data.deckOfTheDay!.dueCards,
                                      ),
                            ),
                            const SizedBox(height: 20),
                            _LibraryActions(
                              onCreateDeck: _openCreateDeck,
                              onBrowseDecks: _openBrowseDecks,
                            ),
                            const SizedBox(height: 18),
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 16,
                              runSpacing: 8,
                              children: [
                                Text(
                                  'Your decks',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (data.decks.length > 5)
                                  TextButton(
                                    onPressed: _openBrowseDecks,
                                    child: const Text('Explore all'),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (data.decks.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 24,
                                ),
                                child: Center(
                                  child: Text(
                                    'Your library is ready. Create your first deck or browse public decks to get started.',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontStyle: FontStyle.italic,
                                      color: theme.textTheme.bodySmall?.color,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              )
                            else
                              ...data.decks
                                  .take(5)
                                  .map(
                                    (deck) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      child: _DeckCard(
                                        deck: deck,
                                        onTap: () => _openDeckDetail(deck.id),
                                      ),
                                    ),
                                  ),
                            const SizedBox(height: 24),
                            _SyncFooterCard(
                              syncStatus: syncStatus,
                              pendingSyncCount: pendingSyncCount,
                              lastSyncedAt: lastSuccessfulAt,
                              onForceSync: _refreshDashboard,
                            ),
                            const SizedBox(height: 18),
                          ]),
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

class _StudyOverview extends StatelessWidget {
  final HomeDashboardData data;
  final VoidCallback onReview;
  final VoidCallback? onOpenDeck;
  final String? timeLabel;
  const _StudyOverview({
    required this.data,
    required this.onReview,
    required this.onOpenDeck,
    required this.timeLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final deck = data.deckOfTheDay;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Welcome back, ${data.displayName}',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Semantics(
          header: true,
          child: Text(
            'Today',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: DefaultTextStyle.merge(
            style: TextStyle(color: colors.onPrimaryContainer),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${data.dueToday} ${data.dueToday == 1 ? 'card' : 'cards'} available',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: colors.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (deck == null || data.dueToday == 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    deck == null
                        ? 'Create a deck or browse public decks to begin.'
                        : 'You are caught up. Check your decks or review settings.',
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onReview,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Start review'),
                ),
                if (deck != null) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: onOpenDeck,
                    style: TextButton.styleFrom(
                      foregroundColor: colors.onPrimaryContainer,
                    ),
                    child: Column(
                      children: [
                        Text(deck.title, textAlign: TextAlign.center),
                        Text(
                          '${deck.dueCards} due — $timeLabel',
                          style: TextStyle(color: colors.onPrimaryContainer),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 20,
          runSpacing: 8,
          children: [
            Text('${data.reviewedToday} reviewed today'),
            Text('${data.streak} ${data.streak == 1 ? 'day' : 'days'} streak'),
            Text('${data.retentionRate.toStringAsFixed(1)}% retention'),
          ],
        ),
      ],
    );
  }
}

class _DeckCard extends StatelessWidget {
  final DeckSummary deck;
  final VoidCallback onTap;
  const _DeckCard({required this.deck, required this.onTap});
  @override
  Widget build(BuildContext context) => Column(
    children: [
      ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        leading: Icon(
          deck.isPublic ? Icons.public_outlined : Icons.style_outlined,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text(deck.title),
        subtitle: Text(
          '${deck.totalCards} ${deck.totalCards == 1 ? 'card' : 'cards'} · ${deck.dueCards} due',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
      const Divider(height: 1),
    ],
  );
}

class _LibraryActions extends StatelessWidget {
  final VoidCallback onCreateDeck;
  final VoidCallback onBrowseDecks;
  const _LibraryActions({
    required this.onCreateDeck,
    required this.onBrowseDecks,
  });
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final oneColumn =
          constraints.maxWidth < 340 ||
          MediaQuery.textScalerOf(context).scale(1) > 1.4;
      final width =
          oneColumn ? constraints.maxWidth : (constraints.maxWidth - 12) / 2;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          SizedBox(
            width: width,
            child: LearningAction(
              icon: Icons.add,
              label: 'Create deck',
              onPressed: onCreateDeck,
            ),
          ),
          SizedBox(
            width: width,
            child: LearningAction(
              icon: Icons.style_outlined,
              label: 'Browse decks',
              onPressed: onBrowseDecks,
            ),
          ),
        ],
      );
    },
  );
}

class _SyncFooterCard extends StatelessWidget {
  final SyncStatus syncStatus;
  final int? pendingSyncCount;
  final DateTime? lastSyncedAt;
  final VoidCallback onForceSync;

  const _SyncFooterCard({
    required this.syncStatus,
    required this.pendingSyncCount,
    required this.lastSyncedAt,
    required this.onForceSync,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localSyncTime = lastSyncedAt?.toLocal();
    final hour = localSyncTime?.hour.toString().padLeft(2, '0') ?? '00';
    final minute = localSyncTime?.minute.toString().padLeft(2, '0') ?? '00';
    final day = localSyncTime?.day.toString().padLeft(2, '0') ?? '00';
    final month = localSyncTime?.month.toString().padLeft(2, '0') ?? '00';
    final year = localSyncTime?.year.toString() ?? '0000';
    final now = DateTime.now();
    final isToday =
        localSyncTime != null &&
        localSyncTime.year == now.year &&
        localSyncTime.month == now.month &&
        localSyncTime.day == now.day;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: theme.colorScheme.surfaceContainerLow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            switch (syncStatus.phase) {
              SyncPhase.syncing => 'Syncing...',
              SyncPhase.offline => 'Offline — changes saved on this device',
              SyncPhase.failed => 'Sync failed — changes remain on this device',
              _ when pendingSyncCount == null => 'Sync status unknown',
              _ when pendingSyncCount! > 0 => 'Changes pending',
              SyncPhase.success => 'All synced',
              SyncPhase.idle => 'Sync status unknown',
            },
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            lastSyncedAt == null
                ? 'Never synced successfully'
                : isToday
                ? 'Last successful sync: $hour:$minute'
                : 'Last successful sync: $day/$month/$year $hour:$minute',
            style: theme.textTheme.bodySmall,
          ),
          if (syncStatus.message != null &&
              syncStatus.phase != SyncPhase.success) ...[
            const SizedBox(height: 4),
            Text(syncStatus.message!, style: theme.textTheme.bodySmall),
          ],
          if ((pendingSyncCount ?? 0) > 0) ...[
            const SizedBox(height: 4),
            Text(
              '$pendingSyncCount local ${pendingSyncCount == 1 ? 'change is' : 'changes are'} '
              'saved on this device and waiting to sync.',
              style: theme.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed:
                  syncStatus.phase == SyncPhase.syncing ? null : onForceSync,
              icon: const Icon(Icons.sync),
              label: Text(
                (pendingSyncCount ?? 0) > 0 ? 'Sync now' : 'Retry sync',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatefulWidget {
  final bool isDark;
  final bool short;

  const _LoadingCard({required this.isDark, this.short = false});

  @override
  State<_LoadingCard> createState() => _LoadingCardState();
}

class _LoadingCardState extends State<_LoadingCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedBuilder(
      animation: _pulse,
      builder:
          (context, _) => Container(
            height: widget.short ? 60 : 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Color.lerp(
                widget.isDark
                    ? const Color(0xFF1A2D3D)
                    : const Color(0xFFE7ECF1),
                widget.isDark
                    ? const Color(0xFF30485B)
                    : const Color(0xFFF7FAFC),
                reduceMotion ? 0 : _pulse.value,
              ),
            ),
          ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

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
