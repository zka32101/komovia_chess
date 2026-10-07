import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/performance_service.dart';
import '../models/rating_progression.dart';
import '../models/performance_stats.dart';

/// Provider for performance service
final performanceServiceProvider = Provider((ref) => PerformanceService());

/// Provider for rating progression over a specific period
final ratingProgressionProvider = StreamProvider.family<List<RatingProgression>,
    ({String playerId, int days})>(
  (ref, params) async* {
    final service = ref.watch(performanceServiceProvider);
    yield* service.watchRatingProgression(
      params.playerId,
      days: params.days,
    );
  },
);

/// Provider for win rate
final performanceWinRateProvider = FutureProvider.family<double, String>(
  (ref, playerId) {
    final service = ref.watch(performanceServiceProvider);
    return service.getWinRate(playerId);
  },
);

/// Provider for performance by opponent rank
final performanceByRankProvider =
    FutureProvider.family<Map<String, int>, String>(
  (ref, playerId) {
    final service = ref.watch(performanceServiceProvider);
    return service.getPerformanceByRank(playerId);
  },
);

/// Provider for performance by time control
final performanceByTimeControlProvider =
    FutureProvider.family<Map<String, int>, String>(
  (ref, playerId) {
    final service = ref.watch(performanceServiceProvider);
    return service.getPerformanceByTimeControl(playerId);
  },
);

/// Provider for streak information
final streakInfoProvider = FutureProvider.family<StreakInfo, String>(
  (ref, playerId) async {
    final service = ref.watch(performanceServiceProvider);
    return service.getStreakInfo(playerId);
  },
);

/// Comprehensive performance stats provider
final performanceStatsProvider =
    FutureProvider.family<PerformanceStats, String>(
  (ref, playerId) async {
    final service = ref.watch(performanceServiceProvider);

    // Fetch all performance data
    final progression30 = await service.getRatingProgression(
      playerId,
      days: 30,
    );
    final progression90 = await service.getRatingProgression(
      playerId,
      days: 90,
    );
    final byRank = await service.getPerformanceByRank(playerId);
    final byTimeControl = await service.getPerformanceByTimeControl(playerId);
    final streak = await service.getStreakInfo(playerId);

    return PerformanceStats(
      playerId: playerId,
      progressionLast30Days: progression30,
      progressionLast90Days: progression90,
      currentStreak: streak.current,
      longestWinStreak: streak.longestWin,
      longestLossStreak: streak.longestLoss,
      performanceByRank: byRank,
      performanceByTimeControl: byTimeControl,
      updatedAt: DateTime.now(),
    );
  },
);
