import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/performance_analytics_provider.dart';
import '../../widgets/charts/rating_progression_chart.dart';
import '../../widgets/charts/performance_breakdown_chart.dart';
import '../../widgets/indicators/streak_indicator.dart';
import '../../widgets/animations/chart_entrance_animation.dart';

/// Screen for displaying performance analytics and trends
class PerformanceAnalyticsScreen extends ConsumerWidget {
  const PerformanceAnalyticsScreen({
    required this.playerId,
    required this.playerName,
    Key? key,
  }) : super(key: key);
  final String playerId;
  final String playerName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final performanceStats = ref.watch(performanceStatsProvider(playerId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('パフォーマンス分析'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(performanceStatsProvider(playerId)),
          ),
        ],
      ),
      body: performanceStats.when(
        data: (stats) => _buildContent(context, ref, stats),
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stackTrace) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'パフォーマンスデータの取得に失敗しました',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () =>
                    ref.refresh(performanceStatsProvider(playerId)),
                icon: const Icon(Icons.refresh),
                label: const Text('再試行'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    dynamic stats,
  ) =>
      SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 16),

            // Streak information
            _buildStreakSection(context, ref),
            const SizedBox(height: 24),

            // Rating progression chart
            _buildProgressionSection(context, ref),
            const SizedBox(height: 24),

            // Performance by time control
            _buildPerformanceByTimeControl(context, ref),
            const SizedBox(height: 24),

            // Performance by opponent rank
            _buildPerformanceByRank(context, ref),
            const SizedBox(height: 24),
          ],
        ),
      );

  Widget _buildStreakSection(BuildContext context, WidgetRef ref) {
    final streakInfo = ref.watch(streakInfoProvider(playerId));

    return streakInfo.when(
      data: (streak) => ChartEntranceAnimation(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border.all(
              color: Theme.of(context).colorScheme.outline,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: StreakIndicator(
            currentStreak: streak.current,
            longestWin: streak.longestWin,
            longestLoss: streak.longestLoss,
          ),
        ),
      ),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildProgressionSection(BuildContext context, WidgetRef ref) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'レーティング進行',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildTimeRangeButton(context, '30日', 30),
                    _buildTimeRangeButton(context, '90日', 90),
                    _buildTimeRangeButton(context, '365日', 365),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ChartEntranceAnimation(
            child: RatingProgressionChart(
              playerId: playerId,
              days: 30,
            ),
          ),
        ],
      );

  Widget _buildTimeRangeButton(BuildContext context, String label, int days) =>
      OutlinedButton(
        onPressed: () {
          // TODO: Implement time range switching with state management
        },
        child: Text(label),
      );

  Widget _buildPerformanceByTimeControl(BuildContext context, WidgetRef ref) {
    final performanceByTimeControl =
        ref.watch(performanceByTimeControlProvider(playerId));

    return performanceByTimeControl.when(
      data: (performance) => ChartEntranceAnimation(
        child: PerformanceBreakdownChart(
          performanceData: performance,
          title: '時間制別パフォーマンス',
          horizontal: true,
        ),
      ),
      loading: () => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        height: 250,
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildPerformanceByRank(BuildContext context, WidgetRef ref) {
    final performanceByRank = ref.watch(performanceByRankProvider(playerId));

    return performanceByRank.when(
      data: (performance) => ChartEntranceAnimation(
        child: PerformanceBreakdownChart(
          performanceData: performance,
          title: 'レベル別パフォーマンス',
          horizontal: true,
        ),
      ),
      loading: () => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        height: 250,
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  String _getTimeControlLabel(String timeControl) {
    switch (timeControl) {
      case 'bullet':
        return 'バレット (1分以下)';
      case 'blitz':
        return 'ブリッツ (3分～5分)';
      case 'rapid':
        return 'ラピッド (10分以上)';
      default:
        return timeControl;
    }
  }
}
