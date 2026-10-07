import 'package:flutter/material.dart';
import '../models/analytics_models.dart';

/// KPI card widget for dashboard
class KPICard extends StatelessWidget {
  const KPICard({
    required this.kpi,
    super.key,
    this.color,
  });
  final DashboardKPI kpi;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final cardColor = color ?? Colors.blue;
    final trendIcon =
        kpi.trend == 'up' ? Icons.trending_up : Icons.trending_down;
    final trendColor = kpi.trend == 'up' ? Colors.green : Colors.red;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  kpi.label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                ),
                if (kpi.trend != null)
                  Icon(trendIcon, color: trendColor, size: 18),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  kpi.value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: cardColor,
                      ),
                ),
                const SizedBox(width: 4),
                Text(
                  kpi.unit,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
            ),
            if (kpi.trendPercent != null) ...[
              const SizedBox(height: 8),
              Text(
                'vs last period: ${kpi.trendPercent}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: trendColor,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Performance chart displaying accuracy over time
class PerformanceChart extends StatelessWidget {
  const PerformanceChart({required this.trend, super.key});
  final PerformanceTrend trend;

  @override
  Widget build(BuildContext context) {
    if (trend.totalDataPoints == 0) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Text(
              'No performance data available',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Performance Trend (Last 30 Days)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(
                    trend.metrics.length,
                    (index) => _BarColumn(
                      value: trend.metrics[index].accuracy,
                      maxValue: 100,
                      date: trend.metrics[index].timestamp,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Average Accuracy',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                    Text(
                      '${trend.averageAccuracy.toStringAsFixed(1)}%',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Trend',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                    Text(
                      trend.trendDirection > 0 ? '↗ Improving' : '↘ Declining',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: trend.trendDirection > 0
                                ? Colors.green
                                : Colors.red,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BarColumn extends StatelessWidget {
  const _BarColumn({
    required this.value,
    required this.maxValue,
    required this.date,
  });
  final double value;
  final double maxValue;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final height = (value / maxValue) * 150;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Tooltip(
            message: '${value.toStringAsFixed(1)}%',
            child: Container(
              width: 24,
              height: height,
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${date.day}/${date.month}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                ),
          ),
        ],
      ),
    );
  }
}

/// Difficulty breakdown widget
class DifficultyBreakdownWidget extends StatelessWidget {
  const DifficultyBreakdownWidget({required this.breakdowns, super.key});
  final List<DifficultyBreakdown> breakdowns;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Performance by Difficulty',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              ...breakdowns
                  .map((breakdown) => _DifficultyRow(breakdown: breakdown)),
            ],
          ),
        ),
      );
}

class _DifficultyRow extends StatelessWidget {
  const _DifficultyRow({required this.breakdown});
  final DifficultyBreakdown breakdown;

  Color _getDifficultyColor() {
    switch (breakdown.difficulty.toLowerCase()) {
      case 'easy':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'hard':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getDifficultyColor();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                breakdown.difficulty.toUpperCase(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
              ),
              Text(
                '${breakdown.gamesPlayed} games',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: breakdown.winRate / 100,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${breakdown.wins}W - ${breakdown.gamesPlayed - breakdown.wins}L',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                'Accuracy: ${breakdown.averageAccuracy.toStringAsFixed(1)}%',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Streak information card
class StreakCard extends StatelessWidget {
  const StreakCard({required this.streakInfo, super.key});
  final StreakInfo streakInfo;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Streaks',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _StreakStat(
                    label: 'Current Win Streak',
                    value: streakInfo.currentWinStreak,
                    color: Colors.green,
                  ),
                  _StreakStat(
                    label: 'Longest Win Streak',
                    value: streakInfo.longestWinStreak,
                    color: Colors.lightGreen,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}

class _StreakStat extends StatelessWidget {
  const _StreakStat({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              value.toString(),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
        ],
      );
}
