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
  return username?.trim() ?? '';
});

final userDecksProvider = FutureProvider<List<DeckSummary>>((ref) async {
  ref.watch(homeDataRevisionProvider);
  final repository = ref.watch(homeRepositoryProvider);
  return repository.getDecks();
});

final homeDashboardProvider = FutureProvider<HomeDashboardData>((ref) async {
  ref.watch(homeDataRevisionProvider);
  final repository = ref.watch(homeRepositoryProvider);
  final sessionStorage = ref.watch(sessionStorageProvider);
  final (userId, username, decks) =
      await (
        sessionStorage.readUserId(),
        ref.watch(usernameProvider.future),
        ref.watch(userDecksProvider.future),
      ).wait;
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
    if (bypass ? deck.totalCards > 0 : deck.dueCards > 0) {
      deckOfTheDay = deck;
      break;
    }
  }
  deckOfTheDay ??= decks.isNotEmpty ? decks.first : null;

  return HomeDashboardData(
    reviewDayUtc: dashboardStats.reviewDayUtc,
    reviewPreferences: (
      dailyLimit: dailyReviewLimit,
      selectiveDecksOnly: selective,
      bypassSrs: bypass,
    ),
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
    final dashboard = ref.read(homeDashboardProvider).asData?.value;
    await Navigator.of(context).pushNamed(
      AppRoutes.settings,
      arguments:
          dashboard == null
              ? null
              : (
                username: dashboard.displayName,
                reviewPreferences: dashboard.reviewPreferences,
              ),
    );
    if (!mounted) return;
    // Writes notify Home directly. Merely visiting Settings needs no new query
    // unless the clock crossed a due time or the start of a new review day.
    final now = DateTime.now().toUtc();
    final currentDashboard =
        ref.read(homeDashboardProvider).valueOrNull ?? dashboard;
    final reviewDayUtc = currentDashboard?.reviewDayUtc;
    final reviewDayExpired =
        reviewDayUtc != null &&
        (reviewDayUtc.year != now.year ||
            reviewDayUtc.month != now.month ||
            reviewDayUtc.day != now.day);
    final scheduleExpired =
        currentDashboard?.decks.any((deck) {
          final due = deck.nextDueAt;
          return due != null && !due.isAfter(now);
        }) ??
        false;
    if (reviewDayExpired || scheduleExpired) {
      ref.read(homeRepositoryProvider).expireScheduledSummaries();
      ref.invalidate(userDecksProvider);
      ref.invalidate(homeDashboardProvider);
    }
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
                title: const Text('Home'),
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
                padding: EdgeInsets.fromLTRB(
                  _pageInset(context),
                  12,
                  _pageInset(context),
                  24,
                ),
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
                            const SizedBox(height: 32),
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 16,
                              runSpacing: 8,
                              children: [
                                Semantics(
                                  header: true,
                                  child: Text(
                                    data.deckOfTheDay != null &&
                                            data.decksCount > 1
                                        ? 'Other decks · ${data.decksCount - 1}'
                                        : 'Manage decks',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
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
                            _LibraryActions(
                              onCreateDeck: _openCreateDeck,
                              onBrowseDecks: _openBrowseDecks,
                            ),
                            const SizedBox(height: 16),
                            ...data.decks
                                .where(
                                  (deck) => deck.id != data.deckOfTheDay?.id,
                                )
                                .take(5)
                                .map(
                                  (deck) => _DeckTrack(
                                    deck: deck,
                                    timeLabel: _timeLabel(
                                      deck.nextDueAt,
                                      dueCards: deck.dueCards,
                                    ),
                                    onTap: () => _openDeckDetail(deck.id),
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
    final dark = theme.brightness == Brightness.dark;
    final accent = dark ? const Color(0xFFFFB58A) : const Color(0xFFA64D24);
    final rawDueCards = data.decks.fold<int>(
      0,
      (sum, deck) => sum + deck.dueCards,
    );
    final deck = data.deckOfTheDay;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (deck != null) ...[
          Text(
            data.dueToday > 0 && deck.totalCards > 0
                ? 'Next deck'
                : 'Featured deck',
            style: theme.textTheme.labelLarge?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Material(
            color: dark ? const Color(0xFF192230) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: colors.outlineVariant),
            ),
            clipBehavior: Clip.antiAlias,
            child: Semantics(
              container: true,
              button: true,
              label:
                  'Open featured deck: ${deck.title}, ${deck.dueCards} due, $timeLabel',
              onTap: onOpenDeck,
              excludeSemantics: true,
              child: InkWell(
                onTap: onOpenDeck,
                excludeFromSemantics: true,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              deck.title,
                              style: theme.textTheme.headlineLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                height: 1.15,
                                letterSpacing: -.6,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '${deck.dueCards} due — $timeLabel',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colors.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Icon(
                          Icons.chevron_right_rounded,
                          color: colors.onSurfaceVariant,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ] else ...[
          Semantics(
            header: true,
            child: Text(
              'No decks yet',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a deck or browse public decks to begin.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 20),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 4,
          children: [
            Text(
              'Today',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '${data.dueToday} available · ${data.reviewedToday} reviewed',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        if (deck != null && data.dueToday == 0) ...[
          const SizedBox(height: 8),
          Text(
            rawDueCards > 0
                ? 'Daily review limit reached. $rawDueCards ${rawDueCards == 1 ? 'card is' : 'cards are'} still due. Check review settings to continue.'
                : 'You are caught up. Check your decks or review settings.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: onReview,
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Start review'),
          style: FilledButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: dark ? const Color(0xFF332014) : Colors.white,
            minimumSize: const Size(double.infinity, 52),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            textStyle: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 24,
          runSpacing: 8,
          children: [
            _PlanStat(
              value: '${data.streak}',
              label: '${data.streak == 1 ? 'day' : 'days'} streak',
            ),
            _PlanStat(
              value: '${data.retentionRate.toStringAsFixed(1)}%',
              label: 'retention',
            ),
          ],
        ),
      ],
    );
  }
}

class _PlanStat extends StatelessWidget {
  final String value;
  final String label;
  const _PlanStat({required this.value, required this.label});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          TextSpan(text: ' $label'),
        ],
      ),
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _DeckTrack extends StatelessWidget {
  final DeckSummary deck;
  final String timeLabel;
  final VoidCallback onTap;
  const _DeckTrack({
    required this.deck,
    required this.timeLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      children: [
        const Divider(height: 1),
        Semantics(
          container: true,
          button: true,
          label:
              'Open deck: ${deck.title}, ${deck.dueCards} due, $timeLabel, ${deck.totalCards} ${deck.totalCards == 1 ? 'card' : 'cards'}, ${deck.isPublic ? 'Public' : 'Private'}',
          onTap: onTap,
          excludeSemantics: true,
          child: InkWell(
            onTap: onTap,
            excludeFromSemantics: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          deck.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${deck.dueCards} due · $timeLabel',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  ExcludeSemantics(
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
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
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
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

double _pageInset(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  return width > 1080 ? (width - 1048) / 2 : 16;
}
