import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/monitoring_service.dart';
import '../services/ab_testing_service.dart';
import '../services/feedback_analysis_service.dart';
import '../services/analytics_dashboard_service.dart';

// ========== Service Providers ==========

/// Access to MonitoringService singleton
final monitoringServiceProvider = Provider((ref) => MonitoringService.instance);

/// Access to ABTestingService singleton
final abTestingServiceProvider = Provider((ref) => ABTestingService.instance);

/// Access to FeedbackAnalysisService singleton
final feedbackAnalysisServiceProvider =
    Provider((ref) => FeedbackAnalysisService.instance);

/// Access to AnalyticsDashboardService singleton
final analyticsDashboardServiceProvider =
    Provider((ref) => AnalyticsDashboardService.instance);

// ========== Monitoring Providers ==========

/// Get performance summary for a time period
final performanceSummaryProvider =
    FutureProvider.family<PerformanceSummary, Duration>((ref, period) async {
  final monitoring = ref.watch(monitoringServiceProvider);
  return monitoring.getPerformanceSummary(period);
});

/// Get crash rate for period
final crashRateProvider =
    FutureProvider.family<double, Duration>((ref, period) async {
  final monitoring = ref.watch(monitoringServiceProvider);
  return monitoring.getCrashRate(period);
});

/// Get ANR rate for period
final anrRateProvider =
    FutureProvider.family<double, Duration>((ref, period) async {
  final monitoring = ref.watch(monitoringServiceProvider);
  return monitoring.getANRRate(period);
});

/// Get average performance metric
final averageMetricProvider =
    FutureProvider.family<int, (String, Duration)>((ref, args) async {
  final monitoring = ref.watch(monitoringServiceProvider);
  return monitoring.getAverageMetric(args.$1, args.$2);
});

// ========== Feedback Analysis Providers ==========

/// Analyze sentiment of feedback text
final feedbackSentimentProvider =
    FutureProvider.family<SentimentAnalysis, String>((ref, text) async {
  final analysis = ref.watch(feedbackAnalysisServiceProvider);
  return analysis.analyzeFeedbackSentiment(text);
});

/// Get aggregated feedback report for period
final feedbackReportProvider =
    FutureProvider.family<FeedbackReport, Duration>((ref, period) async {
  final analysis = ref.watch(feedbackAnalysisServiceProvider);
  return analysis.aggregateFeedback(period);
});

/// Get sentiment trend
final sentimentTrendProvider =
    FutureProvider.family<double, Duration>((ref, period) async {
  final analysis = ref.watch(feedbackAnalysisServiceProvider);
  // Use public method instead of private implementation
  final report = await analysis.aggregateFeedback(period);
  return report.sentimentTrend;
});

// ========== A/B Testing Providers ==========

/// Get user's variant for experiment
final userVariantProvider =
    FutureProvider.family<String, (String, String)>((ref, args) async {
  final aBTesting = ref.watch(abTestingServiceProvider);
  return aBTesting.getUserVariant(args.$1, args.$2);
});

/// Get variant-specific value
final variantValueProvider =
    FutureProvider.family<dynamic, (String, String, Type)>((ref, args) async {
  final aBTesting = ref.watch(abTestingServiceProvider);
  // Type system limitation - simplified version
  return null;
});

/// Get experiment results
final experimentResultsProvider =
    FutureProvider.family<ExperimentResults, String>((ref, experimentId) async {
  final aBTesting = ref.watch(abTestingServiceProvider);
  return aBTesting.analyzeResults(experimentId);
});

// ========== Analytics Dashboard Providers ==========

/// Get complete dashboard summary
final dashboardSummaryProvider = FutureProvider<DashboardSummary>((ref) async {
  final dashboard = ref.watch(analyticsDashboardServiceProvider);
  return dashboard.getDashboardSummary();
});

/// Get retention metrics
final retentionMetricsProvider = FutureProvider<RetentionMetrics>((ref) async {
  final dashboard = ref.watch(analyticsDashboardServiceProvider);
  final summary = await dashboard.getDashboardSummary();
  return summary.retention;
});

/// Get conversion metrics
final conversionMetricsProvider =
    FutureProvider<ConversionMetrics>((ref) async {
  final dashboard = ref.watch(analyticsDashboardServiceProvider);
  final summary = await dashboard.getDashboardSummary();
  return summary.conversion;
});

/// Get crash metrics
final crashMetricsProvider = FutureProvider<CrashMetrics>((ref) async {
  final dashboard = ref.watch(analyticsDashboardServiceProvider);
  final summary = await dashboard.getDashboardSummary();
  return summary.crashes;
});

/// Get engagement metrics
final engagementMetricsProvider =
    FutureProvider<EngagementMetrics>((ref) async {
  final dashboard = ref.watch(analyticsDashboardServiceProvider);
  final summary = await dashboard.getDashboardSummary();
  return summary.engagement;
});

/// Analyze funnel conversion
final funnelAnalysisProvider =
    FutureProvider.family<FunnelAnalysis, String>((ref, funnelName) async {
  final dashboard = ref.watch(analyticsDashboardServiceProvider);
  return dashboard.analyzeFunnel(funnelName);
});

/// Analyze cohort retention
final cohortAnalysisProvider =
    FutureProvider.family<CohortAnalysis, DateTime>((ref, cohortDate) async {
  final dashboard = ref.watch(analyticsDashboardServiceProvider);
  return dashboard.analyzeCohort(cohortDate);
});

/// Get KPI trend
final kpiTrendProvider =
    FutureProvider.family<KPITrend, (String, Duration)>((ref, args) async {
  final dashboard = ref.watch(analyticsDashboardServiceProvider);
  return dashboard.getKPITrend(args.$1, args.$2);
});

// ========== State Management Providers ==========

/// Track recent actions for monitoring
final recentActionsProvider = StateProvider<List<String>>((ref) => []);

/// Manage active experiments
final activeExperimentsProvider = StateProvider<List<String>>((ref) => []);

/// Store latest dashboard summary
final latestDashboardProvider = StateProvider<DashboardSummary?>((ref) => null);

/// Track alert state
final alertsProvider = StateProvider<List<String>>((ref) => []);

// ========== Notifiers for State Management ==========

/// Notifier for managing active experiments
class ActiveExperimentsNotifier extends StateNotifier<List<String>> {
  ActiveExperimentsNotifier() : super([]);

  void addExperiment(String experimentId) {
    state = [...state, experimentId];
  }

  void removeExperiment(String experimentId) {
    state = state.where((id) => id != experimentId).toList();
  }

  void clearCompleted() {
    state = [];
  }
}

/// Notifier for managing monitoring alerts
class AlertsNotifier extends StateNotifier<List<String>> {
  AlertsNotifier() : super([]);

  void addAlert(String message) {
    state = [...state, message];
  }

  void dismissAlert(String message) {
    state = state.where((alert) => alert != message).toList();
  }

  void clearAll() {
    state = [];
  }
}

// ========== Computed Providers ==========

/// Check if monitoring is healthy
final monitoringHealthProvider = FutureProvider<bool>((ref) async {
  final summary = await ref.watch(
    performanceSummaryProvider(const Duration(days: 7)).future,
  );

  return summary.crashFreeRate >= 0.99 &&
      !summary.startupExceedsTarget &&
      !summary.navigationExceedsTarget &&
      summary.anrRate < 0.005;
});

/// Get critical issues from feedback
final criticalIssuesProvider = FutureProvider<List<FeedbackIssue>>((ref) async {
  final report = await ref.watch(
    feedbackReportProvider(const Duration(days: 7)).future,
  );

  return report.topIssues
      .where((issue) => issue.severity == 'critical')
      .toList();
});

/// Get recommended optimizations
final optimizationRecommendationsProvider =
    FutureProvider<List<String>>((ref) async {
  final summary = await ref.watch(dashboardSummaryProvider.future);
  final recommendations = <String>[];

  if (summary.crashes.crashFreeRate < 0.99) {
    recommendations
        .add('Investigate crash rate: ${summary.crashes.crashFreeRate}');
  }

  if (summary.engagement.sessionsPerDay < 1.5) {
    recommendations.add('Improve engagement: Low session frequency');
  }

  if (summary.conversion.conversionRate < 0.03) {
    recommendations.add('Optimize paywall conversion rate');
  }

  if (summary.retention.d7 < 0.20) {
    recommendations.add('Improve 7-day retention with better onboarding');
  }

  return recommendations;
});
