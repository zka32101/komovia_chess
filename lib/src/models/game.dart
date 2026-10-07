import 'package:freezed_annotation/freezed_annotation.dart';

part 'game.freezed.dart';
part 'game.g.dart';

@freezed
class GameModel with _$GameModel {
  const factory GameModel({
    required String gameId,
    required String type, // 'online_pvp', 'cpu', 'puzzle'
    required String status, // 'matchmaking', 'active', 'completed', 'abandoned'
    required String whitePlayerId,
    required String blackPlayerId,
    required int whiteRating,
    required int blackRating,
    required List<Map<String, dynamic>> moves,
    String? whitePlayerName,
    String? blackPlayerName,
    String? pgn,
    String? currentFen,
    String? timeControl, // '10min', '5min', '3min'
    int? timeControlMs,
    int? whiteTimeRemainingMs,
    int? blackTimeRemainingMs,
    String? result, // 'white_win', 'black_win', 'draw', null
    String?
        resultReason, // 'checkmate', 'resignation', 'timeout', 'draw_agreement', 'abandonment'
    String? abandonedBy,
    int? whiteRatingDelta,
    int? blackRatingDelta,
    int? whiteNewRating,
    int? blackNewRating,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? endedAt,
  }) = _GameModel;

  factory GameModel.fromJson(Map<String, dynamic> json) =>
      _$GameModelFromJson(json);
}
