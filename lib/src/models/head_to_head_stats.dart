import 'package:freezed_annotation/freezed_annotation.dart';
import 'match_record.dart';

part 'head_to_head_stats.freezed.dart';
part 'head_to_head_stats.g.dart';

/// Head-to-head statistics between two players
@freezed
class HeadToHeadStats with _$HeadToHeadStats {
  const factory HeadToHeadStats({
    required String player1Id,
    required String player2Id,
    required int player1Wins,
    required int player2Wins,
    required int draws,
    required double player1WinRate,
    required double player2WinRate,
    required int ratingDifference, // player1 - player2
    required DateTime lastMatch,
    required List<MatchRecord> recentMatches, // last 10
  }) = _HeadToHeadStats;

  factory HeadToHeadStats.fromJson(Map<String, dynamic> json) =>
      _$HeadToHeadStatsFromJson(json);
}
