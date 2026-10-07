import 'package:freezed_annotation/freezed_annotation.dart';

part 'match_record.freezed.dart';
part 'match_record.g.dart';

/// Represents a single match/game record
@freezed
class MatchRecord with _$MatchRecord {
  const factory MatchRecord({
    required String matchId,
    required String playerId,
    required String opponentId,
    required String opponentName,
    required int playerRatingBefore,
    required int playerRatingAfter,
    required int opponentRatingBefore,
    required int opponentRatingAfter,
    required String result, // 'win', 'loss', 'draw'
    required String timeControl, // 'bullet', 'blitz', 'rapid'
    required DateTime playedAt,
    int? duration, // seconds
    String? pgn, // For future chess analysis
  }) = _MatchRecord;

  factory MatchRecord.fromJson(Map<String, dynamic> json) =>
      _$MatchRecordFromJson(json);
}
