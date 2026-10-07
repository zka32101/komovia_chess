import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/player_comparison_service.dart';
import '../services/rating_prediction_service.dart';
import '../services/performance_trend_service.dart';

/// Phase Q - Specialized Analytics Providers
/// Provides reactive access to player comparison, rating prediction, and performance analysis

// Service Providers
final playerComparisonServiceProvider = Provider<PlayerComparisonService>(
    (ref) => PlayerComparisonService(firestore: FirebaseFirestore.instance));

final ratingPredictionServiceProvider = Provider<RatingPredictionService>(
    (ref) => RatingPredictionService(firestore: FirebaseFirestore.instance));

final performanceTrendServiceProvider = Provider<PerformanceTrendService>(
    (ref) => PerformanceTrendService(firestore: FirebaseFirestore.instance));

// Player Comparison Providers

/// Get head-to-head comparison between two players
final headToHeadComparisonProvider =
    FutureProvider.family<HeadToHeadComparison, (String, String)>(
        (ref, params) {
  final service = ref.watch(playerComparisonServiceProvider);
  return service.getHeadToHeadComparison(params.$1, params.$2);
});

/// Analyze complete player profile with strengths and weaknesses
final playerProfileProvider =
    FutureProvider.family<PlayerProfile, String>((ref, playerId) {
  final service = ref.watch(playerComparisonServiceProvider);
  return service.analyzePlayerProfile(playerId);
});

/// Get player matchup statistics against all opponents
final playerMatchupsProvider =
    FutureProvider.family<List<MatchupStats>, String>((ref, playerId) {
  final service = ref.watch(playerComparisonServiceProvider);
  return service.getPlayerMatchups(playerId);
});

// Rating Prediction Providers

/// Predict player's rating N days in the future
final futureRatingPredictionProvider =
    FutureProvider.family<RatingForecast, ({String playerId, int daysAhead})>(
        (ref, params) {
  final service = ref.watch(ratingPredictionServiceProvider);
  return service.predictFutureRating(
    params.playerId,
    daysAhead: params.daysAhead,
  );
});

/// Analyze rating volatility and stability trends
final ratingVolatilityProvider =
    FutureProvider.family<RatingVolatility, String>((ref, playerId) {
  final service = ref.watch(ratingPredictionServiceProvider);
  return service.analyzeRatingVolatility(playerId);
});

/// Get rating progression over time with monthly aggregation
final ratingProgressionProvider =
    FutureProvider.family<RatingProgression, ({String playerId, int months})>(
        (ref, params) {
  final service = ref.watch(ratingPredictionServiceProvider);
  return service.getRatingProgression(
    params.playerId,
    months: params.months,
  );
});

// Performance Trend Providers

/// Analyze performance trends across 7/30/90 day periods
final performanceTrendsProvider =
    FutureProvider.family<PerformanceTrends, String>((ref, playerId) {
  final service = ref.watch(performanceTrendServiceProvider);
  return service.analyzePerformanceTrends(playerId);
});

/// Get performance metrics for a specific time period
final performanceMetricsForPeriodProvider =
    FutureProvider.family<TimePeriodMetrics, ({String playerId, int daysBack})>(
        (ref, params) {
  final service = ref.watch(performanceTrendServiceProvider);
  return service.getPerformanceMetricsForPeriod(
    params.playerId,
    daysBack: params.daysBack,
  );
});

/// Analyze performance breakdown by day of week
final performanceByDayOfWeekProvider =
    FutureProvider.family<Map<String, DayPerformance>, String>((ref, playerId) {
  final service = ref.watch(performanceTrendServiceProvider);
  return service.analyzePerformanceByDayOfWeek(playerId);
});

// Combined Analytics Providers

/// Get complete analytics dashboard for a player
final playerAnalyticsDashboardProvider =
    FutureProvider.family<PlayerAnalyticsDashboard, String>(
        (ref, playerId) async {
  final profileAsync = ref.watch(playerProfileProvider(playerId));
  final trendsAsync = ref.watch(performanceTrendsProvider(playerId));
  final volatilityAsync = ref.watch(ratingVolatilityProvider(playerId));
  final predictionAsync = ref.watch(futureRatingPredictionProvider(
    (playerId: playerId, daysAhead: 30),
  ));

  return Future.wait([
    profileAsync.when(
      data: (data) async => data,
      error: (err, st) => throw err,
      loading: () => throw Exception('Loading player profile'),
    ),
    trendsAsync.when(
      data: (data) async => data,
      error: (err, st) => throw err,
      loading: () => throw Exception('Loading trends'),
    ),
    volatilityAsync.when(
      data: (data) async => data,
      error: (err, st) => throw err,
      loading: () => throw Exception('Loading volatility'),
    ),
    predictionAsync.when(
      data: (data) async => data,
      error: (err, st) => throw err,
      loading: () => throw Exception('Loading prediction'),
    ),
  ]).then((results) => PlayerAnalyticsDashboard(
        profile: results[0] as PlayerProfile,
        trends: results[1] as PerformanceTrends,
        volatility: results[2] as RatingVolatility,
        forecast: results[3] as RatingForecast,
      ));
});

/// Combined data class for complete player analytics dashboard
class PlayerAnalyticsDashboard {
  PlayerAnalyticsDashboard({
    required this.profile,
    required this.trends,
    required this.volatility,
    required this.forecast,
  });
  final PlayerProfile profile;
  final PerformanceTrends trends;
  final RatingVolatility volatility;
  final RatingForecast forecast;
}
