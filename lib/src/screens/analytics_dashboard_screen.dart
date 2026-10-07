import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/phase_m_providers.dart';
import '../widgets/analytics_dashboard_widgets.dart';

/// Comprehensive analytics dashboard screen
class AnalyticsDashboardScreen extends ConsumerWidget {
  const AnalyticsDashboardScreen({required this.userId, super.key});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(playerAnalyticsDashboardProvider(userId));
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        elevation: 0,
        centerTitle: true,
      ),
      body: dashboardAsync.when(
        loading: () => const _LoadingState(),
        error: (err, stack) => _ErrorState(error: err),
        data: (dashboard) => _DashboardContent(
          dashboard: dashboard,
          userId: userId,
          isDarkMode: isDarkMode,
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Loading analytics...',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error});
  final Object error;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.red[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load analytics',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                // Retry logic handled by provider
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.dashboard,
    required this.userId,
    required this.isDarkMode,
  });
  final dynamic dashboard;
  final String userId;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 20,
          vertical: 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header section
            _buildHeaderSection(context),
            const SizedBox(height: 24),

            // KPI cards grid
            if (isMobile)
              _buildMobileKPIGrid(context)
            else
              _buildDesktopKPIGrid(context),
            const SizedBox(height: 24),

            // Performance chart
            _buildPerformanceChartSection(context),
            const SizedBox(height: 24),

            // Difficulty breakdown
            _buildDifficultySection(context),
            const SizedBox(height: 24),

            // Streak information
            _buildStreakSection(context),
            const SizedBox(height: 24),

            // Quick stats footer
            _buildQuickStatsFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Performance',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Last updated: ${DateTime.now().toString().split('.')[0]}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
        ],
      );

  Widget _buildMobileKPIGrid(BuildContext context) => Column(
        children: [
          _buildKPICard(
            context,
            'Win Rate',
            '${dashboard.gameStats.winRate.toStringAsFixed(1)}%',
            Colors.blue,
          ),
          const SizedBox(height: 12),
          _buildKPICard(
            context,
            'Total Games',
            dashboard.gameStats.totalGames.toString(),
            Colors.green,
          ),
          const SizedBox(height: 12),
          _buildKPICard(
            context,
            'Accuracy',
            '${dashboard.gameStats.averageAccuracy.toStringAsFixed(1)}%',
            Colors.orange,
          ),
          const SizedBox(height: 12),
          _buildKPICard(
            context,
            'Current Streak',
            dashboard.streakInfo.currentWinStreak.toString(),
            Colors.purple,
          ),
        ],
      );

  Widget _buildDesktopKPIGrid(BuildContext context) => GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildKPICard(
            context,
            'Win Rate',
            '${dashboard.gameStats.winRate.toStringAsFixed(1)}%',
            Colors.blue,
          ),
          _buildKPICard(
            context,
            'Total Games',
            dashboard.gameStats.totalGames.toString(),
            Colors.green,
          ),
          _buildKPICard(
            context,
            'Accuracy',
            '${dashboard.gameStats.averageAccuracy.toStringAsFixed(1)}%',
            Colors.orange,
          ),
          _buildKPICard(
            context,
            'Current Streak',
            dashboard.streakInfo.currentWinStreak.toString(),
            Colors.purple,
          ),
        ],
      );

  Widget _buildKPICard(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) =>
      Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: color.withOpacity(0.1),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      );

  Widget _buildPerformanceChartSection(BuildContext context) =>
      PerformanceChart(trend: dashboard.performanceTrend);

  Widget _buildDifficultySection(BuildContext context) =>
      DifficultyBreakdownWidget(
        breakdowns: dashboard.difficultyStats,
      );

  Widget _buildStreakSection(BuildContext context) =>
      StreakCard(streakInfo: dashboard.streakInfo);

  Widget _buildQuickStatsFooter(BuildContext context) {
    final stats = dashboard.gameStats;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[100]!.withOpacity(isDarkMode ? 0.1 : 1),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildQuickStat(context, 'Wins', stats.wins.toString()),
          _buildQuickStat(
            context,
            'Losses',
            stats.losses.toString(),
          ),
          _buildQuickStat(context, 'Draws', stats.draws.toString()),
          _buildQuickStat(
            context,
            'Moves',
            (stats.totalMoves / 1000).toStringAsFixed(1) + 'K',
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStat(BuildContext context, String label, String value) =>
      Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                  fontSize: 11,
                ),
          ),
        ],
      );
}
