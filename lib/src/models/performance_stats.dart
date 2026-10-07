import 'package:freezed_annotation/freezed_annotation.dart';
import 'rating_progression.dart';

part 'performance_stats.freezed.dart';
part 'performance_stats.g.dart';

/// Comprehensive performance statistics for a player
@freezed
class PerformanceStats with _$PerformanceStats {
  const factory PerformanceStats({
    required String playerId,
    required List<RatingProgression> progressionLast30Days,
    required List<RatingProgression> progressionLast90Days,
    required int currentStreak, // positive = wins, negative = losses
    required int longestWinStreak,
    required int longestLossStreak,
    required Map<String, int> performanceByRank, // e.g., "3段": 65 (win %)
    required Map<String, int> performanceByTimeControl,
    required DateTime updatedAt,
  }) = _PerformanceStats;

  factory PerformanceStats.fromJson(Map<String, dynamic> json) =>
      _$PerformanceStatsFromJson(json);
}
