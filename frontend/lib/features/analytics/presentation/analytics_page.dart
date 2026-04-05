import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/analytics_repository.dart';
import '../domain/analytics_models.dart';

class AnalyticsPage extends ConsumerStatefulWidget {
  const AnalyticsPage({super.key});

  @override
  ConsumerState<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends ConsumerState<AnalyticsPage> {
  int _rangeDays = 30;

  Future<void> _refresh() async {
    ref.invalidate(analyticsDashboardProvider(_rangeDays));
    await ref.read(analyticsDashboardProvider(_rangeDays).future);
  }

  @override
  Widget build(BuildContext context) {
    final analyticsAsync = ref.watch(analyticsDashboardProvider(_rangeDays));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh analytics',
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: analyticsAsync.when(
            loading: () => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: const [
                _SkeletonCard(height: 220),
                SizedBox(height: 16),
                _SkeletonCard(height: 220),
                SizedBox(height: 16),
                _SkeletonCard(height: 220),
              ],
            ),
            error: (error, _) => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
              children: [
                _ErrorState(
                  message: '$error',
                  onRetry: _refresh,
                ),
              ],
            ),
            data: (data) => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                _AnalyticsHeroCard(data: data, isDark: isDark),
                const SizedBox(height: 16),
                _RangeSelector(
                  currentValue: _rangeDays,
                  onChanged: (value) {
                    if (value == _rangeDays) return;
                    setState(() => _rangeDays = value);
                  },
                ),
                const SizedBox(height: 16),
                _MetricWrap(data: data),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Study rhythm',
                  subtitle:
                      '${data.reviewsInRange} reviews across ${data.rangeDays} days',
                  child: _ReviewBarChart(
                    points: data.reviewActivity,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Retention trend',
                  subtitle:
                      '${(data.retentionRate * 100).toStringAsFixed(1)}% pass rate in the selected window',
                  child: _AccuracyLineChart(
                    points: data.accuracyTrend,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Learning pipeline',
                  subtitle: 'Current card distribution from your synced database state',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _StateDistributionBar(data: data),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _InfoPill(
                            label: 'Learned',
                            value: '${data.learnedCards}',
                            icon: Icons.school_outlined,
                          ),
                          _InfoPill(
                            label: 'Mature',
                            value: '${data.matureCards}',
                            icon: Icons.psychology_alt_outlined,
                          ),
                          _InfoPill(
                            label: 'Due in 24h',
                            value: '${data.dueNext24Hours}',
                            icon: Icons.schedule_outlined,
                          ),
                          _InfoPill(
                            label: 'Longest interval',
                            value: '${data.longestIntervalDays.toStringAsFixed(0)} d',
                            icon: Icons.timeline_outlined,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Review answer mix',
                  subtitle: 'Again resets the card. Hard, Good and Easy count as successful recall.',
                  child: _RatingBreakdownCard(
                    breakdown: data.ratingBreakdown,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Deck insights',
                  subtitle: 'Workload and performance across your active decks',
                  child: _DeckInsightList(
                    insights: data.deckInsights,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'What this means',
                  subtitle: 'Plain-language summary of what to focus on next',
                  child: _InsightSummary(
                    data: data,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnalyticsHeroCard extends StatelessWidget {
  final AnalyticsDashboardData data;
  final bool isDark;

  const _AnalyticsHeroCard({
    required this.data,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: isDark
              ? const [Color(0xFF1D1536), Color(0xFF0F1A30)]
              : const [Color(0xFFF4ECFF), Color(0xFFEAF6FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 64,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.white.withOpacity(0.82),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Image.asset(
                  'assets/LogoWithText_WithoutBG.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(Icons.auto_stories_rounded),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Synced learning analytics',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      data.username.isEmpty ? 'Flashapp learner' : data.username,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodyMedium?.color?.withOpacity(0.72),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            data.hasCards
                ? 'You have ${data.totalCards} active cards across ${data.totalDecks} decks. ${data.dueNow} are currently due and ${data.dueNext24Hours} are due within the next 24 hours.'
                : 'Create a deck and review some cards to start building your analytics dashboard.',
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeroChip(icon: Icons.local_fire_department_outlined, label: '${data.currentStreak} day streak'),
              _HeroChip(icon: Icons.auto_graph_outlined, label: '${(data.retentionRate * 100).toStringAsFixed(1)}% retention'),
              _HeroChip(icon: Icons.today_outlined, label: '${data.reviewsToday} reviewed today'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: isDark ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.82),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}

class _RangeSelector extends StatelessWidget {
  final int currentValue;
  final ValueChanged<int> onChanged;

  const _RangeSelector({
    required this.currentValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      children: [
        for (final value in const [7, 30, 90])
          ChoiceChip(
            label: Text('$value days'),
            selected: currentValue == value,
            onSelected: (_) => onChanged(value),
          ),
      ],
    );
  }
}

class _MetricWrap extends StatelessWidget {
  final AnalyticsDashboardData data;

  const _MetricWrap({required this.data});

  @override
  Widget build(BuildContext context) {
    final items = [
      _MetricCard(
        icon: Icons.analytics_outlined,
        label: 'Reviews',
        value: '${data.reviewsInRange}',
        note: '${data.reviewsToday} today',
      ),
      _MetricCard(
        icon: Icons.track_changes_outlined,
        label: 'Retention',
        value: '${(data.retentionRate * 100).toStringAsFixed(1)}%',
        note: '${data.activeDaysInRange} active days',
      ),
      _MetricCard(
        icon: Icons.hourglass_bottom_outlined,
        label: 'Due now',
        value: '${data.dueNow}',
        note: '${data.dueNext24Hours} in 24h',
      ),
      _MetricCard(
        icon: Icons.speed_outlined,
        label: 'Average load',
        value: data.averageStudyLoad.toStringAsFixed(1),
        note: 'Best day ${data.bestDayCount}',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        final tileWidth = compact
            ? constraints.maxWidth
            : (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final item in items)
              SizedBox(
                width: tileWidth,
                child: item,
              ),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String note;

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.note,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      constraints: const BoxConstraints(minHeight: 148),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: isDark ? const Color(0xFF171B2E) : Colors.white,
        border: Border.all(
          color: isDark ? const Color(0xFF2D3454) : const Color(0xFFE8EAF2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22),
          const SizedBox(height: 12),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.72),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            note,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: isDark ? const Color(0xFF121628) : Colors.white,
        border: Border.all(
          color: isDark ? const Color(0xFF252A45) : const Color(0xFFE7EAF3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.72),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _ReviewBarChart extends StatelessWidget {
  final List<DailyCountPoint> points;
  final bool isDark;

  const _ReviewBarChart({required this.points, required this.isDark});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty || points.every((point) => point.count == 0)) {
      return const _ChartEmptyState(label: 'No review activity yet');
    }

    final peak = points.fold<int>(0, (max, point) => math.max(max, point.count));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 180,
          child: CustomPaint(
            painter: _BarChartPainter(points: points, isDark: isDark),
            child: const SizedBox.expand(),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_shortDate(points.first.date)),
            Text('Peak $peak reviews', style: Theme.of(context).textTheme.labelSmall),
            Text(_shortDate(points.last.date)),
          ],
        ),
      ],
    );
  }
}

class _AccuracyLineChart extends StatelessWidget {
  final List<AccuracyPoint> points;
  final bool isDark;

  const _AccuracyLineChart({required this.points, required this.isDark});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty || points.every((point) => point.reviewed == 0)) {
      return const _ChartEmptyState(label: 'No graded reviews yet');
    }

    final highest = points.fold<double>(0, (max, point) => math.max(max, point.accuracy));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 180,
          child: CustomPaint(
            painter: _LineChartPainter(points: points, isDark: isDark),
            child: const SizedBox.expand(),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_shortDate(points.first.date)),
            Text('Best ${(highest * 100).toStringAsFixed(0)}%', style: Theme.of(context).textTheme.labelSmall),
            Text(_shortDate(points.last.date)),
          ],
        ),
      ],
    );
  }
}

class _StateDistributionBar extends StatelessWidget {
  final AnalyticsDashboardData data;

  const _StateDistributionBar({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.totalCards == 0) {
      return const _ChartEmptyState(label: 'No cards available yet');
    }

    final segments = <Widget>[];

    void addSegment(int value, Color color) {
      if (value <= 0) return;
      segments.add(
        Expanded(
          flex: value,
          child: Container(color: color),
        ),
      );
    }

    addSegment(data.newCards, const Color(0xFF7C4DFF));
    addSegment(data.learningCards, const Color(0xFFFFA726));
    addSegment(data.reviewCards, const Color(0xFF26A69A));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(height: 14, child: Row(children: segments)),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 12,
          runSpacing: 10,
          children: [
            _LegendItem(color: const Color(0xFF7C4DFF), label: 'New', value: data.newCards),
            _LegendItem(color: const Color(0xFFFFA726), label: 'Learning', value: data.learningCards),
            _LegendItem(color: const Color(0xFF26A69A), label: 'Review', value: data.reviewCards),
          ],
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final int value;

  const _LegendItem({required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF8F9FD),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text('$label · $value'),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _InfoPill({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      constraints: const BoxConstraints(minWidth: 140),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isDark ? const Color(0xFF171C31) : const Color(0xFFF8F9FD),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.bodySmall),
              Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
        ],
      ),
    );
  }
}

class _RatingBreakdownCard extends StatelessWidget {
  final RatingBreakdown breakdown;
  final bool isDark;

  const _RatingBreakdownCard({required this.breakdown, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final total = breakdown.total == 0 ? 1 : breakdown.total;

    Widget tile(String label, int value, Color color) {
      final percent = (value / total) * 100;
      return Container(
        constraints: const BoxConstraints(minWidth: 130),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isDark ? const Color(0xFF1A1F34) : const Color(0xFFF8F9FD),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(height: 10),
            Text(label),
            const SizedBox(height: 6),
            Text('$value', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text('${percent.toStringAsFixed(0)}% of answers', maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        tile('Again', breakdown.again, const Color(0xFFEF5350)),
        tile('Hard', breakdown.hard, const Color(0xFFFFA726)),
        tile('Good', breakdown.good, const Color(0xFF42A5F5)),
        tile('Easy', breakdown.easy, const Color(0xFF66BB6A)),
      ],
    );
  }
}

class _DeckInsightList extends StatelessWidget {
  final List<DeckAnalyticsInsight> insights;
  final bool isDark;

  const _DeckInsightList({required this.insights, required this.isDark});

  @override
  Widget build(BuildContext context) {
    if (insights.isEmpty) {
      return const _ChartEmptyState(label: 'No deck analytics yet');
    }

    return Column(
      children: [
        for (var i = 0; i < insights.length; i++) ...[
          _DeckInsightTile(insight: insights[i], isDark: isDark),
          if (i != insights.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _DeckInsightTile extends StatelessWidget {
  final DeckAnalyticsInsight insight;
  final bool isDark;

  const _DeckInsightTile({required this.insight, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: isDark ? const Color(0xFF171C31) : const Color(0xFFF8F9FD),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(insight.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MiniStat(label: 'Cards', value: '${insight.totalCards}'),
              _MiniStat(label: 'Due', value: '${insight.dueCards}'),
              _MiniStat(label: 'Reviewed', value: '${insight.reviewedCount}'),
              _MiniStat(label: 'Accuracy', value: '${(insight.accuracy * 100).toStringAsFixed(0)}%'),
              _MiniStat(label: 'Mature', value: '${insight.matureCards}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
      ),
      child: Text('$label: $value'),
    );
  }
}

class _InsightSummary extends StatelessWidget {
  final AnalyticsDashboardData data;
  final bool isDark;

  const _InsightSummary({required this.data, required this.isDark});

  List<String> _messages() {
    final messages = <String>[];

    if (data.dueNow > math.max(10, data.reviewsToday * 2)) {
      messages.add('Your due queue is building up. A shorter catch-up session today will make tomorrow easier.');
    } else {
      messages.add('Your due queue looks manageable. You are keeping the review load under control.');
    }

    if (data.retentionRate < 0.75) {
      messages.add('Retention has dipped a bit. Consider trimming card density or adding more context to difficult cards.');
    } else {
      messages.add('Retention is strong. Your recent review quality suggests the spacing is working well.');
    }

    if (data.matureCards > 0) {
      messages.add('${data.matureCards} cards have reached mature status, which means your long-term knowledge base is growing.');
    } else {
      messages.add('You are still building toward mature cards. A few more consistent review days will start that curve.');
    }

    return messages.take(3).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final messages = _messages();
    return Column(
      children: [
        for (var index = 0; index < messages.length; index++) ...[
          _InsightTile(message: messages[index], index: index, isDark: isDark),
          if (index != messages.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _InsightTile extends StatelessWidget {
  final String message;
  final int index;
  final bool isDark;

  const _InsightTile({required this.message, required this.index, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final colors = [const Color(0xFF7C4DFF), const Color(0xFFFFA726), const Color(0xFF26A69A)];
    final color = colors[index % colors.length];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: isDark ? const Color(0xFF171C31) : const Color(0xFFF8F9FD),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 12, height: 12, margin: const EdgeInsets.only(top: 4), decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final List<DailyCountPoint> points;
  final bool isDark;

  _BarChartPainter({required this.points, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    const leftPadding = 8.0;
    const bottomPadding = 18.0;
    const topPadding = 8.0;

    final chartHeight = size.height - bottomPadding - topPadding;
    final chartWidth = size.width - leftPadding;
    final maxValue = points.fold<int>(0, (max, point) => math.max(max, point.count));
    final safeMax = maxValue == 0 ? 1 : maxValue;
    final slotWidth = chartWidth / points.length;
    final barWidth = math.max(4.0, slotWidth * 0.55);

    final gridPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withOpacity(0.06)
      ..strokeWidth = 1;
    final barPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF7C4DFF), Color(0xFFFF5BB2)],
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
      ).createShader(Rect.fromLTWH(0, topPadding, size.width, chartHeight));

    for (var i = 0; i < 4; i++) {
      final y = topPadding + (chartHeight / 3) * i;
      canvas.drawLine(Offset(leftPadding, y), Offset(size.width, y), gridPaint);
    }

    for (var index = 0; index < points.length; index++) {
      final point = points[index];
      final normalized = point.count / safeMax;
      final barHeight = chartHeight * normalized;
      final dx = leftPadding + slotWidth * index + (slotWidth - barWidth) / 2;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(dx, size.height - bottomPadding - barHeight, barWidth, math.max(3, barHeight)),
        const Radius.circular(999),
      );
      canvas.drawRRect(rect, barPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.isDark != isDark;
  }
}

class _LineChartPainter extends CustomPainter {
  final List<AccuracyPoint> points;
  final bool isDark;

  _LineChartPainter({required this.points, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    const leftPadding = 8.0;
    const rightPadding = 8.0;
    const topPadding = 12.0;
    const bottomPadding = 18.0;

    final chartHeight = size.height - topPadding - bottomPadding;
    final chartWidth = size.width - leftPadding - rightPadding;
    final gridPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withOpacity(0.06)
      ..strokeWidth = 1;

    for (var i = 0; i < 4; i++) {
      final y = topPadding + (chartHeight / 3) * i;
      canvas.drawLine(Offset(leftPadding, y), Offset(size.width - rightPadding, y), gridPaint);
    }

    if (points.length == 1) {
      final center = Offset(size.width / 2, topPadding + chartHeight * (1 - points.first.accuracy));
      final pointPaint = Paint()..color = const Color(0xFF26A69A);
      canvas.drawCircle(center, 5, pointPaint);
      return;
    }

    final minDate = points.first.date;
    final maxDate = points.last.date;
    final totalDays = math.max(1, maxDate.difference(minDate).inDays);

    Offset toOffset(AccuracyPoint point) {
      final dayOffset = point.date.difference(minDate).inDays;
      final dx = leftPadding + (dayOffset / totalDays) * chartWidth;
      final dy = topPadding + chartHeight * (1 - point.accuracy.clamp(0.0, 1.0));
      return Offset(dx, dy);
    }

    final areaPath = Path();
    final linePath = Path();
    final firstOffset = toOffset(points.first);
    linePath.moveTo(firstOffset.dx, firstOffset.dy);
    areaPath.moveTo(firstOffset.dx, size.height - bottomPadding);
    areaPath.lineTo(firstOffset.dx, firstOffset.dy);

    for (var index = 1; index < points.length; index++) {
      final offset = toOffset(points[index]);
      linePath.lineTo(offset.dx, offset.dy);
      areaPath.lineTo(offset.dx, offset.dy);
    }

    final lastOffset = toOffset(points.last);
    areaPath.lineTo(lastOffset.dx, size.height - bottomPadding);
    areaPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF26A69A).withOpacity(0.28),
          const Color(0xFF26A69A).withOpacity(0.02),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final linePaint = Paint()
      ..color = const Color(0xFF26A69A)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(areaPath, fillPaint);
    canvas.drawPath(linePath, linePaint);

    final dotPaint = Paint()..color = const Color(0xFF26A69A);
    final dotOutline = Paint()
      ..color = isDark ? const Color(0xFF111523) : Colors.white
      ..style = PaintingStyle.fill;

    for (final point in points) {
      final offset = toOffset(point);
      canvas.drawCircle(offset, 5.5, dotOutline);
      canvas.drawCircle(offset, 3.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.isDark != isDark;
  }
}

class _ChartEmptyState extends StatelessWidget {
  final String label;

  const _ChartEmptyState({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: theme.brightness == Brightness.dark ? Colors.white.withOpacity(0.03) : const Color(0xFFF8F9FD),
      ),
      child: Column(
        children: [
          const Icon(Icons.insights_outlined, size: 28),
          const SizedBox(height: 12),
          Text(label),
        ],
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  final double height;

  const _SkeletonCard({required this.height});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: isDark ? const Color(0xFF171B2E) : const Color(0xFFF5F7FC),
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
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF171B2E) : Colors.white,
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
          const SizedBox(height: 12),
          Text(
            'Could not load analytics',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}

String _shortDate(DateTime date) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[date.month - 1]} ${date.day}';
}
