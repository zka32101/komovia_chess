import 'package:freezed_annotation/freezed_annotation.dart';

part 'analytics_snapshot.freezed.dart';
part 'analytics_snapshot.g.dart';

/// Monthly analytics snapshot for a player
@freezed
class AnalyticsSnapshot with _$AnalyticsSnapshot {
  const factory AnalyticsSnapshot({
    required String playerId,
    required int monthYear, // e.g., 202608 for Aug 2026
    required int gamesPlayed,
    required int wins,
    required int losses,
    required int draws,
    required int ratingChange,
    required double avgRatingGained,
    required double avgRatingLost,
  }) = _AnalyticsSnapshot;

  factory AnalyticsSnapshot.fromJson(Map<String, dynamic> json) =>
      _$AnalyticsSnapshotFromJson(json);
}
