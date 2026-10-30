import 'package:freezed_annotation/freezed_annotation.dart';
import '../services/shogi_rank_service.dart';

part 'user.freezed.dart';
part 'user.g.dart';

@freezed
abstract class UserModel with _$UserModel {
  const factory UserModel({
    required String uid,
    required String email,
    String? displayName,
    String? photoUrl,
    @Default(false) bool emailVerified,
    // Canonical rating for kyu/dan evaluation - both CPU games
    // (cpu_game_provider.dart) and online PvP games (online_game_service.dart)
    // update this same field, and ranking_service.dart/profile screens all
    // read it. `onlineRating` below is a legacy, now-unused field kept only
    // so existing Firestore documents that still carry it don't fail to
    // deserialize - previously CPU and online games tracked two separate,
    // never-reconciled rating numbers, so a player's kyu/dan rank shown on
    // their profile (from onlineRating) and their position on the
    // leaderboard (from rating) disagreed depending on which game mode
    // they actually played.
    @Default(1500) int rating,
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
    // Preset avatar icon id from komovia_core's shared `kAvatarIcons`
    // catalog (see `avatarIconById`). null for every user who existed
    // before this feature shipped, or who never opened the picker -
    // resolve with `avatarIconById(user.avatarId)` wherever this is
    // displayed, never read this field directly, since it safely falls
    // back to the default icon for null/empty/unknown ids.
    String? avatarId,
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
