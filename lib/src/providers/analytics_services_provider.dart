import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/analytics_engagement_service.dart';
import '../services/analytics_funnel_service.dart';
import '../services/analytics_revenue_service.dart';

/// Analytics revenue service provider (singleton)
///
/// Provides [AnalyticsRevenueService] for tracking subscription and revenue events
final analyticsRevenueServiceProvider =
    Provider<AnalyticsRevenueService>((ref) => AnalyticsRevenueService());

/// Analytics engagement service provider (singleton)
///
/// Provides [AnalyticsEngagementService] for tracking user engagement events
final analyticsEngagementServiceProvider =
    Provider<AnalyticsEngagementService>((ref) => AnalyticsEngagementService());

/// Analytics funnel service provider (singleton)
///
/// Provides [AnalyticsFunnelService] for tracking purchase funnel progression
final analyticsFunnelServiceProvider =
    Provider<AnalyticsFunnelService>((ref) => AnalyticsFunnelService());
