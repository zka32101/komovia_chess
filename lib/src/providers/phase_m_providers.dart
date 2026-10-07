import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/analytics_dashboard_service_impl.dart';
import '../models/analytics_models.dart';

/// Phase M: Analytics Dashboard Providers

/// Singleton analytics dashboard service
final analyticsDashboardServiceProvider =
    Provider<AnalyticsDashboardService>((ref) => AnalyticsDashboardService());

/// Get player analytics dashboard
final playerAnalyticsDashboardProvider =
    FutureProvider.family<PlayerAnalyticsDashboard, String>(
        (ref, userId) async {
  final service = ref.watch(analyticsDashboardServiceProvider);
  return service.getPlayerDashboard(userId);
});

/// Get game statistics for a player
final playerGameStatsProvider =
    FutureProvider.family<GameStats, String>((ref, userId) async {
  final dashboard =
      await ref.watch(playerAnalyticsDashboardProvider(userId).future);
  return dashboard.gameStats;
});

/// Get streak information
final playerStreakInfoProvider =
    FutureProvider.family<StreakInfo, String>((ref, userId) async {
  final dashboard =
      await ref.watch(playerAnalyticsDashboardProvider(userId).future);
  return dashboard.streakInfo;
});

/// Get performance trend
final performanceTrendProvider =
    FutureProvider.family<PerformanceTrend, String>((ref, userId) async {
  final dashboard =
      await ref.watch(playerAnalyticsDashboardProvider(userId).future);
  return dashboard.performanceTrend;
});

/// Get difficulty breakdown
final difficultyBreakdownProvider =
    FutureProvider.family<List<DifficultyBreakdown>, String>(
        (ref, userId) async {
  final dashboard =
      await ref.watch(playerAnalyticsDashboardProvider(userId).future);
  return dashboard.difficultyStats;
});

/// Compare two players
final playerComparisonProvider =
    FutureProvider.family<(GameStats, GameStats), (String, String)>(
        (ref, playerIds) async {
  final service = ref.watch(analyticsDashboardServiceProvider);
  return service.comparePlayersStats(playerIds.$1, playerIds.$2);
});

/// Dashboard refresh trigger
final dashboardRefreshProvider =
    StateProvider<DateTime>((ref) => DateTime.now());

/// Invalidation notifier
final analyticsInvalidationProvider =
    StateNotifierProvider<AnalyticsInvalidationNotifier, List<String>>((ref) {
  final service = ref.watch(analyticsDashboardServiceProvider);
  return AnalyticsInvalidationNotifier(service);
});

/// Notifier for manual analytics invalidation
class AnalyticsInvalidationNotifier extends StateNotifier<List<String>> {
  AnalyticsInvalidationNotifier(this._service) : super([]);
  final AnalyticsDashboardService _service;

  void invalidatePlayer(String userId) {
    _service.invalidatePlayerAnalytics(userId);
    state = [...state, userId];
  }

  void clearAll() {
    _service.clearCache();
    state = [];
  }

  List<String> getInvalidationHistory() => state;
}

/// Batch analytics loading
final batchPlayerAnalyticsProvider =
    FutureProvider.family<Map<String, PlayerAnalyticsDashboard>, List<String>>(
        (ref, userIds) async {
  final service = ref.watch(analyticsDashboardServiceProvider);
  return service.batchGetDashboards(userIds);
});

/// Analytics dashboard KPIs
final dashboardKPIsProvider =
    FutureProvider.family<List<DashboardKPI>, String>((ref, userId) async {
  final data = await ref.watch(playerAnalyticsDashboardProvider(userId).future);
  final stats = data.gameStats;
  return [
    DashboardKPI(
      label: 'Win Rate',
      value: stats.winRate.toStringAsFixed(1),
      unit: '%',
      trend: stats.winRate > 50 ? 'up' : 'down',
    ),
    DashboardKPI(
      label: 'Total Games',
      value: stats.totalGames.toString(),
      unit: 'games',
    ),
    DashboardKPI(
      label: 'Accuracy',
      value: stats.averageAccuracy.toStringAsFixed(1),
      unit: '%',
    ),
    DashboardKPI(
      label: 'Current Streak',
      value: data.streakInfo.currentWinStreak.toString(),
      unit: 'wins',
    ),
  ];
});
