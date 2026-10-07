import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/phase_m_analytics_providers.dart';
import '../../widgets/analytics_charts.dart';

class DashboardHome extends ConsumerWidget {
  const DashboardHome({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kpisAsync = ref.watch(dashboardKPIsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics Dashboard'),
        elevation: 0,
      ),
      body: kpisAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (err, stack) => Center(
          child: Text('Error: $err'),
        ),
        data: (kpis) => SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Key Performance Indicators',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.2,
                  ),
                  itemCount: kpis.length,
                  itemBuilder: (context, index) {
                    final kpi = kpis[index];
                    return KPICard(
                      label: kpi.label,
                      value: kpi.value,
                      unit: kpi.unit,
                      trend: kpi.trend,
                      trendColor: _getTrendColor(kpi.trend),
                    );
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  'Dashboard Sections',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.5,
                  children: [
                    _DashboardTile(
                      title: 'Performance',
                      icon: Icons.speed,
                      onTap: () {
                        Navigator.of(context)
                            .pushNamed('/analytics/performance');
                      },
                    ),
                    _DashboardTile(
                      title: 'Engagement',
                      icon: Icons.people,
                      onTap: () {
                        Navigator.of(context)
                            .pushNamed('/analytics/engagement');
                      },
                    ),
                    _DashboardTile(
                      title: 'Cache',
                      icon: Icons.storage,
                      onTap: () {
                        Navigator.of(context).pushNamed('/analytics/cache');
                      },
                    ),
                    _DashboardTile(
                      title: 'Features',
                      icon: Icons.star,
                      onTap: () {
                        Navigator.of(context).pushNamed('/analytics/features');
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color? _getTrendColor(String? trend) {
    if (trend == null) return null;
    if (trend.contains('↑')) return Colors.green;
    if (trend.contains('↓')) return Colors.red;
    return Colors.grey;
  }
}

class _DashboardTile extends StatelessWidget {
  const _DashboardTile({
    required this.title,
    required this.icon,
    required this.onTap,
  });
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 40,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ),
      );
}
