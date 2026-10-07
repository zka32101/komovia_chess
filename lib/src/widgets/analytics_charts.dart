import 'package:flutter/material.dart';
import '../models/analytics_models.dart';

class PerformanceLineChart extends StatelessWidget {
  // p50, p95, p99

  const PerformanceLineChart({
    required this.trends,
    required this.title,
    required this.metric,
    super.key,
  });
  final List<QueryPerformanceTrend> trends;
  final String title;
  final String metric;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              if (trends.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('No data available'),
                  ),
                )
              else
                SizedBox(
                  height: 200,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (int i = 0; i < trends.length; i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Column(
                              children: [
                                Text(
                                  _getMetricValue(trends[i]).toString(),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  width: 30,
                                  height: _getBarHeight(i, trends.length),
                                  color: Colors.blue,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  trends[i].period.toString().split(' ')[0],
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      );

  int _getMetricValue(QueryPerformanceTrend trend) {
    switch (metric) {
      case 'p50':
        return trend.p50Latency;
      case 'p95':
        return trend.p95Latency;
      case 'p99':
        return trend.p99Latency;
      default:
        return trend.p50Latency;
    }
  }

  double _getBarHeight(int index, int total) {
    const maxHeight = 120.0;
    if (total == 0) return 0;
    final value = _getMetricValue(trends[index]).toDouble();
    final maxValue = trends
        .map((t) => _getMetricValue(t).toDouble())
        .reduce((a, b) => a > b ? a : b);
    if (maxValue == 0) return 0;
    return (value / maxValue) * maxHeight;
  }
}

class CacheAnalyticsCard extends StatelessWidget {
  const CacheAnalyticsCard({required this.analytics, super.key});
  final CacheAnalytics analytics;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                analytics.cacheName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
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
                        'Hit Rate',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                      Text(
                        '${(analytics.hitRate * 100).toStringAsFixed(1)}%',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hits',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                      Text(
                        '${analytics.hitCount}',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Avg Lookup',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                      Text(
                        '${analytics.avgCacheLookup.inMilliseconds}ms',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: analytics.hitRate,
                minHeight: 6,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                  analytics.hitRate > 0.7 ? Colors.green : Colors.orange,
                ),
              ),
            ],
          ),
        ),
      );
}

class FeatureAdoptionCard extends StatelessWidget {
  const FeatureAdoptionCard({required this.stats, super.key});
  final CompetitiveFeatureStats stats;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stats.feature,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
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
                        'Active Users',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                      Text(
                        '${stats.activeUsers}',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Adoption Rate',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                      Text(
                        '${(stats.adoptionRate * 100).toStringAsFixed(1)}%',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Interactions',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                      Text(
                        '${stats.totalInteractions}',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: stats.adoptionRate,
                minHeight: 6,
                backgroundColor: Colors.grey[300],
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            ],
          ),
        ),
      );
}

class EngagementMetricsCard extends StatelessWidget {
  const EngagementMetricsCard({required this.metrics, super.key});
  final UserEngagementMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final playTimeHours = metrics.totalPlayTime.inSeconds / 3600;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'User: ${metrics.userId.substring(0, 8)}...',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
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
                      'Sessions',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                    Text(
                      '${metrics.sessionsCount}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Play Time',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                    Text(
                      '${playTimeHours.toStringAsFixed(1)}h',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                    Text(
                      metrics.churnedUser ? 'Churned' : 'Active',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color:
                                metrics.churnedUser ? Colors.red : Colors.green,
                          ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (metrics.featureUsage.isNotEmpty) ...[
              Text(
                'Feature Usage',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: metrics.featureUsage.entries
                    .map(
                      (e) => Chip(
                        label: Text('${e.key}: ${e.value}'),
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class KPICard extends StatelessWidget {
  const KPICard({
    required this.label,
    required this.value,
    required this.unit,
    super.key,
    this.trend,
    this.trendColor,
  });
  final String label;
  final String value;
  final String unit;
  final String? trend;
  final Color? trendColor;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: value,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            TextSpan(
                              text: ' $unit',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (trend != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: (trendColor ?? Colors.grey).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        trend!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: trendColor ?? Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
}

class RetentionHeatmap extends StatelessWidget {
  const RetentionHeatmap({required this.metrics, super.key});
  final RetentionMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final retentionData = metrics.retentionByDay;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Retention: ${metrics.cohortDate}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
              ),
              itemCount: retentionData.length,
              itemBuilder: (context, index) {
                final day = index + 1;
                final retention = retentionData[day] ?? 0;

                return Tooltip(
                  message: 'Day $day: ${retention.toStringAsFixed(1)}%',
                  child: Container(
                    decoration: BoxDecoration(
                      color: _getRetentionColor(retention / 100),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                      child: Text(
                        'D$day',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Color _getRetentionColor(double retention) {
    if (retention > 0.7) return Colors.green;
    if (retention > 0.4) return Colors.orange;
    return Colors.red;
  }
}
