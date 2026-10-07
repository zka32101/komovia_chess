import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/phase_m_analytics_providers.dart';
import '../../widgets/analytics_charts.dart';

class EngagementDashboard extends ConsumerWidget {
  const EngagementDashboard({Key? key, this.days = 7}) : super(key: key);
  final int days;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(
          title: const Text('User Engagement'),
          elevation: 0,
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _EngagementSectionTitle(days: days),
                const SizedBox(height: 16),
                _UserEngagementOverview(),
                const SizedBox(height: 24),
                Text(
                  'Retention Analysis',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                _RetentionMetricsSection(),
                const SizedBox(height: 24),
                _ChurnAnalysisSection(),
              ],
            ),
          ),
        ),
      );
}

class _EngagementSectionTitle extends StatelessWidget {
  const _EngagementSectionTitle({required this.days});
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
                  builder: (context) => EngagementDashboard(days: result),
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

class _UserEngagementOverview extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Engagement Overview',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(
                        'DAU',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '2,450',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Text(
                        'MAU',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '15,800',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Text(
                        'Avg Session',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '18m 32s',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
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

class _RetentionMetricsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final retentionAsync = ref.watch(
      retentionMetricsProvider('2024-09-16'),
    );

    return retentionAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
      data: (retention) {
        if (retention == null) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No retention data available',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          );
        }
        return RetentionHeatmap(metrics: retention);
      },
    );
  }
}

class _ChurnAnalysisSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final churnAsync = ref.watch(churnAnalyticsProvider(14));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Churn Analysis',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        churnAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err')),
          data: (churnedUsers) {
            if (churnedUsers.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No churned users in the last 14 days',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              );
            }

            return Column(
              children: churnedUsers
                  .take(5)
                  .map((metrics) => EngagementMetricsCard(metrics: metrics))
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}
