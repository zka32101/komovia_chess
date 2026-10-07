import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/phase_m_analytics_providers.dart';
import '../../widgets/analytics_charts.dart';

class CacheDashboard extends ConsumerWidget {
  const CacheDashboard({Key? key, this.days = 7}) : super(key: key);
  final int days;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(
          title: const Text('Cache Analytics'),
          elevation: 0,
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CacheSectionTitle(days: days),
                const SizedBox(height: 16),
                _CacheOverviewCards(),
                const SizedBox(height: 24),
                Text(
                  'Cache Details',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                _CacheAnalyticsDetail(days: days),
              ],
            ),
          ),
        ),
      );
}

class _CacheSectionTitle extends StatelessWidget {
  const _CacheSectionTitle({required this.days});
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
                  builder: (context) => CacheDashboard(days: result),
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

class _CacheOverviewCards extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Row(
        children: [
          Expanded(
            child: KPICard(
              label: 'Overall Hit Rate',
              value: '87.3',
              unit: '%',
              trend: '↑ 2.1%',
              trendColor: Colors.green,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: KPICard(
              label: 'Avg Lookup Time',
              value: '2.4',
              unit: 'ms',
              trend: '↓ 0.3ms',
              trendColor: Colors.green,
            ),
          ),
        ],
      );
}

class _CacheAnalyticsDetail extends ConsumerWidget {
  const _CacheAnalyticsDetail({required this.days});
  final int days;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cacheAsync = ref.watch(cacheAnalyticsProvider(days));

    return cacheAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
      data: (caches) {
        if (caches.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No cache data available',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          );
        }

        return Column(
          children: [
            ...caches.map((analytics) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: CacheAnalyticsCard(analytics: analytics),
                )),
          ],
        );
      },
    );
  }
}
