import 'package:freezed_annotation/freezed_annotation.dart';

part 'puzzle.freezed.dart';
part 'puzzle.g.dart';

@freezed
class PuzzleModel with _$PuzzleModel {
  const factory PuzzleModel({
    required String id,
    required String fen,
    required List<String> moves, // Solution moves in UCI format
    required int rating,
    required List<String> themes, // 'fork', 'pin', 'checkmate', etc.
    int? handCount, // Number of moves to solve
    DateTime? createdAt,
  }) = _PuzzleModel;

  factory PuzzleModel.fromJson(Map<String, dynamic> json) =>
      _$PuzzleModelFromJson(json);
}

@freezed
class UserPuzzleResultModel with _$UserPuzzleResultModel {
  const factory UserPuzzleResultModel({
    required String userId,
    required String puzzleId,
    required bool solved,
    required int attempts,
    List<String>? userMoves, // User's moves if not solved
    DateTime? timestamp,
  }) = _UserPuzzleResultModel;

  factory UserPuzzleResultModel.fromJson(Map<String, dynamic> json) =>
      _$UserPuzzleResultModelFromJson(json);
}

@freezed
class DailyChallengeModel with _$DailyChallengeModel {
  const factory DailyChallengeModel({
    required String date,
    required String theme,
    required List<String> puzzleIds,
    DateTime? createdAt,
  }) = _DailyChallengeModel;

  factory DailyChallengeModel.fromJson(Map<String, dynamic> json) =>
      _$DailyChallengeModelFromJson(json);
}
