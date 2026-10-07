import 'package:freezed_annotation/freezed_annotation.dart';
import '../services/shogi_rank_service.dart';

part 'user.freezed.dart';
part 'user.g.dart';

@freezed
class UserModel with _$UserModel {
  const factory UserModel({
    required String uid,
    required String email,
    String? displayName,
    String? photoUrl,
    @Default(false) bool emailVerified,
    @Default(0) int rating,
    @Default(0) int onlineRating,
    @Default(0) int puzzlesSolved,
    @Default(0) int gamesPlayed,
    @Default(0) int wins,
    @Default(0) int losses,
    @Default(0) int draws,
    DateTime? createdAt,
    DateTime? lastSignInAt,
    // 将棋式ランキング
    @_ShogiRankConverter() ShogiRank? shogiRank,
  }) = _UserModel;

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);
}

/// ShogiRankをJSON変換するためのコンバーター
class _ShogiRankConverter
    implements JsonConverter<ShogiRank?, Map<String, dynamic>?> {
  const _ShogiRankConverter();

  @override
  ShogiRank? fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const ShogiRank.dan(1); // デフォルト値
    }
    return ShogiRank.fromJson(json);
  }

  @override
  Map<String, dynamic>? toJson(ShogiRank? value) => value?.toJson();
}
