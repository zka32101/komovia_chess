import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/phase_m_analytics_providers.dart';
import '../../widgets/analytics_charts.dart';

class PerformanceDashboard extends ConsumerWidget {
  const PerformanceDashboard({Key? key, this.days = 7}) : super(key: key);
  final int days;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(
          title: const Text('Performance Metrics'),
          elevation: 0,
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PerformanceSectionTitle(days: days),
                const SizedBox(height: 16),
                _PerformanceTrendsSection(days: days),
                const SizedBox(height: 24),
                Text(
                  'Query Type Comparison',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                _QueryTypeComparisonSection(),
                const SizedBox(height: 24),
                _RegressionDetectionSection(),
              ],
            ),
          ),
        ),
      );
}

class _PerformanceSectionTitle extends StatelessWidget {
  const _PerformanceSectionTitle({required this.days});
  final int days;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Last $days Days',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          PopupMenuButton<int>(
            onSelected: (result) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => PerformanceDashboard(days: result),
                ),
              );
            },
            itemBuilder: (context) => <PopupMenuEntry<int>>[
              const PopupMenuItem<int>(
                value: 7,
                child: Text('Last 7 Days'),
              ),
              const PopupMenuItem<int>(
                value: 30,
                child: Text('Last 30 Days'),
              ),
              const PopupMenuItem<int>(
                value: 90,
                child: Text('Last 90 Days'),
              ),
            ],
            child: const Chip(label: Text('View Options')),
          ),
        ],
      );
}

class _PerformanceTrendsSection extends ConsumerWidget {
  const _PerformanceTrendsSection({required this.days});
  final int days;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendsP50 = ref.watch(
      queryPerformanceTrendsProvider(
        (queryType: 'leaderboard', days: days),
      ),
    );

    return trendsP50.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
      data: (trends) => Column(
        children: [
          PerformanceLineChart(
            trends: trends,
            title: 'P50 Latency (Median)',
            metric: 'p50',
          ),
          const SizedBox(height: 16),
          PerformanceLineChart(
            trends: trends,
            title: 'P95 Latency (95th Percentile)',
            metric: 'p95',
          ),
          const SizedBox(height: 16),
          PerformanceLineChart(
            trends: trends,
            title: 'P99 Latency (99th Percentile)',
            metric: 'p99',
          ),
        ],
      ),
    );
  }
}

class _QueryTypeComparisonSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final comparison = ref.watch(performanceComparisonProvider(7));

    return comparison.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
      data: (data) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Latency Comparison (P50)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: (data['queryTypes'] as List<String>?)
                          ?.asMap()
                          .entries
                          .map(
                            (entry) => Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: Column(
                                children: [
                                  Text(
                                    entry.value,
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    width: 40,
                                    height: ((data['latencies']
                                                as List<int>?)?[entry.key] ??
                                            100)
                                        .toDouble(),
                                    color: Colors.blue,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${(data['latencies'] as List<int>?)?[entry.key]}ms',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList() ??
                      [],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RegressionDetectionSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final regressionP50 = ref.watch(
      performanceRegressionProvider(
        (queryType: 'leaderboard', currentP50: 150),
      ),
    );

    return regressionP50.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
      data: (isRegression) => Card(
        color: isRegression ? Colors.red[50] : Colors.green[50],
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                isRegression ? Icons.warning : Icons.check_circle,
                color: isRegression ? Colors.red : Colors.green,
                size: 32,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isRegression
                          ? 'Performance Regression Detected'
                          : 'Performance Healthy',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isRegression ? Colors.red : Colors.green,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isRegression
                          ? 'Leaderboard queries show >20% degradation'
                          : 'All query types performing within targets',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
