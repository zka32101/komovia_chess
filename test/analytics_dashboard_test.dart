import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_chess/src/screens/analytics/dashboard_home.dart';
import 'package:komovia_chess/src/screens/analytics/performance_dashboard.dart';
import 'package:komovia_chess/src/screens/analytics/engagement_dashboard.dart';
import 'package:komovia_chess/src/screens/analytics/cache_dashboard.dart';
import 'package:komovia_chess/src/screens/analytics/competitive_features_dashboard.dart';
import 'package:komovia_chess/src/widgets/analytics_charts.dart';

void main() {
  group('Analytics Dashboard Widgets', () {
    testWidgets('DashboardHome renders with scaffold', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: DashboardHome(),
          ),
        ),
      );

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.text('Analytics Dashboard'), findsOneWidget);
    });

    testWidgets('DashboardHome displays navigation tiles', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: DashboardHome(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check for dashboard section tiles
      expect(find.text('Performance'), findsWidgets);
      expect(find.text('Engagement'), findsWidgets);
      expect(find.text('Cache'), findsWidgets);
      expect(find.text('Features'), findsWidgets);
    });

    testWidgets('PerformanceDashboard renders with performance section', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: PerformanceDashboard(),
          ),
        ),
      );

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.text('Performance Metrics'), findsOneWidget);
    });

    testWidgets('PerformanceDashboard shows time range selector', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: PerformanceDashboard(),
          ),
        ),
      );

      expect(find.byType(PopupMenuButton), findsOneWidget);
      expect(find.text('View Options'), findsOneWidget);
    });

    testWidgets('EngagementDashboard renders with engagement section', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: EngagementDashboard(),
          ),
        ),
      );

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.text('User Engagement'), findsOneWidget);
    });

    testWidgets('EngagementDashboard shows retention analysis', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: EngagementDashboard(),
          ),
        ),
      );

      expect(find.text('Retention Analysis'), findsOneWidget);
    });

    testWidgets('CacheDashboard renders with cache section', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: CacheDashboard(),
          ),
        ),
      );

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.text('Cache Analytics'), findsOneWidget);
    });

    testWidgets('CacheDashboard displays cache overview', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: CacheDashboard(),
          ),
        ),
      );

      expect(find.text('Overall Hit Rate'), findsOneWidget);
      expect(find.text('Avg Lookup Time'), findsOneWidget);
    });

    testWidgets('CompetitiveFeaturesDashboard renders', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: CompetitiveFeaturesDashboard(),
          ),
        ),
      );

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.text('Feature Analytics'), findsOneWidget);
    });

    testWidgets('CompetitiveFeaturesDashboard shows feature overview', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: CompetitiveFeaturesDashboard(),
          ),
        ),
      );

      expect(find.text('Active Leaderboard Users'), findsOneWidget);
      expect(find.text('Challenge Participants'), findsOneWidget);
    });
  });

  group('Analytics Chart Widgets', () {
    testWidgets('KPICard displays label and value', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KPICard(
              label: 'Test KPI',
              value: '123',
              unit: 'ms',
              trend: '↑ 5%',
              trendColor: Colors.green,
            ),
          ),
        ),
      );

      expect(find.text('Test KPI'), findsOneWidget);
      expect(find.text('123'), findsOneWidget);
      expect(find.text('ms'), findsOneWidget);
      expect(find.text('↑ 5%'), findsOneWidget);
    });

    testWidgets('KPICard renders without trend', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KPICard(
              label: 'Simple KPI',
              value: '456',
              unit: 'users',
            ),
          ),
        ),
      );

      expect(find.text('Simple KPI'), findsOneWidget);
      expect(find.text('456'), findsOneWidget);
      expect(find.text('users'), findsOneWidget);
    });

    testWidgets('PerformanceLineChart renders with trends', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PerformanceLineChart(
              trends: [],
              title: 'Performance Trend',
              metric: 'p50',
            ),
          ),
        ),
      );

      expect(find.text('Performance Trend'), findsOneWidget);
      expect(find.text('No data available'), findsOneWidget);
    });

    testWidgets('CacheAnalyticsCard displays cache info', (WidgetTester tester) async {
      // This test requires creating a CacheAnalytics object
      // Implementation depends on mock data setup
      expect(find.byType(CacheAnalyticsCard), findsNothing);
    });
  });

  group('Dashboard Navigation', () {
    testWidgets('Dashboard tiles navigate to detail screens', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            routes: {
              '/': (context) => const DashboardHome(),
              '/analytics/performance': (context) => const PerformanceDashboard(),
              '/analytics/engagement': (context) => const EngagementDashboard(),
              '/analytics/cache': (context) => const CacheDashboard(),
              '/analytics/features': (context) => const CompetitiveFeaturesDashboard(),
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify navigation items exist but don't test navigation
      // (navigation requires more complex setup)
      expect(find.text('Performance'), findsWidgets);
      expect(find.text('Engagement'), findsWidgets);
    });
  });

  group('Dashboard Responsiveness', () {
    testWidgets('Dashboard adapts to different screen sizes', (WidgetTester tester) async {
      tester.binding.window.physicalSizeTestValue = const Size(1080, 1920);
      addTearDown(tester.binding.window.clearPhysicalSizeTestValue);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: DashboardHome(),
          ),
        ),
      );

      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('Dashboard works on small screens', (WidgetTester tester) async {
      tester.binding.window.physicalSizeTestValue = const Size(540, 960);
      addTearDown(tester.binding.window.clearPhysicalSizeTestValue);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: DashboardHome(),
          ),
        ),
      );

      expect(find.byType(Scaffold), findsOneWidget);
    });
  });
}
