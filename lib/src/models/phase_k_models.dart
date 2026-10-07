import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'phase_k_models.freezed.dart';
part 'phase_k_models.g.dart';

/// Every timestamp field below is written to Firestore via
/// `FieldValue.serverTimestamp()` (see friend_service.dart), which reads
/// back as a [Timestamp], not the ISO-8601 string json_serializable's
/// default `DateTime` handling expects. Used as a `@JsonKey(fromJson:)`
/// converter on those fields so `fromJson` doesn't throw on real data.
DateTime? _dateTimeFromTimestamp(Object? json) {
  if (json == null) return null;
  if (json is Timestamp) return json.toDate();
  if (json is String) return DateTime.parse(json);
  return null;
}

DateTime _requiredDateTimeFromTimestamp(Object? json) =>
    (json is Timestamp) ? json.toDate() : DateTime.parse(json as String);

// ========== Leaderboard Models ==========
//
// `LeaderboardEntry` used to be declared here, but it was dead scaffolding
// with zero real callers (its only consumers were `phase_t_providers.dart`,
// `leaderboard_service.dart` and `leaderboard_service_optimized.dart`,
// themselves unreachable from anywhere in the app) — deleted, along with
// those three files, in favor of komovia_core's `LeaderboardEntry`, which
// is what the real, routed leaderboard (`ranking_service.dart` /
// `leaderboard_provider.dart` / the `screens/ranking/*` screens) uses.

@freezed
class LeaderboardHistory with _$LeaderboardHistory {
  const factory LeaderboardHistory({
    required String userId,
    required DateTime timestamp,
    required int rating,
    required int rank,
    required String period, // 'daily', 'weekly', 'monthly', 'all-time'
  }) = _LeaderboardHistory;

  factory LeaderboardHistory.fromJson(Map<String, dynamic> json) =>
      _$LeaderboardHistoryFromJson(json);
}

@freezed
class RankingStats with _$RankingStats {
  const factory RankingStats({
    required String userId,
    required int currentRating,
    required int peakRating,
    required DateTime peakDate,
    required int rank,
    required int percentile,
    required int totalGamesPlayed,
    required Map<String, int> ratingByTimeControl,
  }) = _RankingStats;

  factory RankingStats.fromJson(Map<String, dynamic> json) =>
      _$RankingStatsFromJson(json);
}

// ========== Friend System Models ==========
//
// `Friend`/`FriendRequest`/`BlockedUser` used to live here as 3 separate
// shapes (a friends list, a requestId-keyed request inbox/outbox, and a
// standalone blocked-user record). They have been replaced by
// `package:komovia_core`'s `Friendship` — a single denormalized
// relationship-doc-per-pair with a `status` field ('pending'/'accepted'/
// 'blocked') instead of a separate request object. See
// `friend_service.dart` for the new shape and `friend_provider.dart`/
// `friends_screen.dart` for its friendUid-keyed call sites.

@freezed
class FriendActivity with _$FriendActivity {
  const factory FriendActivity({
    required String activityId,
    required String userId,
    required String
        activityType, // 'win', 'loss', 'achievement', 'online', 'challenge'
    required String description,
    // ignore: invalid_annotation_target
    @JsonKey(fromJson: _requiredDateTimeFromTimestamp)
    required DateTime timestamp,
    required Map<String, dynamic> metadata,
  }) = _FriendActivity;

  factory FriendActivity.fromJson(Map<String, dynamic> json) =>
      _$FriendActivityFromJson(json);
}

// ========== Challenge System Models ==========

@freezed
class Challenge with _$Challenge {
  const factory Challenge({
    required String challengeId,
    required String challengerUserId,
    required String challengerUsername,
    required String challengeeUserId,
    required String challengeeUsername,
    // ignore: invalid_annotation_target
    @JsonKey(fromJson: _requiredDateTimeFromTimestamp)
    required DateTime createdAt,
    required String
        status, // 'pending', 'accepted', 'rejected', 'completed', 'cancelled'
    required String timeControl, // 'blitz', 'rapid', 'classical'
    required int wagerPoints,
    // ignore: invalid_annotation_target
    @JsonKey(fromJson: _dateTimeFromTimestamp) required DateTime? respondedAt,
    required String? winnerId,
    required String? gameId,
    // ignore: invalid_annotation_target
    @JsonKey(fromJson: _dateTimeFromTimestamp) required DateTime? completedAt,
  }) = _Challenge;

  factory Challenge.fromJson(Map<String, dynamic> json) =>
      _$ChallengeFromJson(json);
}

@freezed
class ChallengeStreak with _$ChallengeStreak {
  const factory ChallengeStreak({
    required String userId,
    required int currentStreak,
    required int bestStreak,
    // ignore: invalid_annotation_target
    @JsonKey(fromJson: _requiredDateTimeFromTimestamp)
    required DateTime streakStartDate,
    required int totalChallengesWon,
    required int totalChallengesLost,
    required double winRate,
  }) = _ChallengeStreak;

  factory ChallengeStreak.fromJson(Map<String, dynamic> json) =>
      _$ChallengeStreakFromJson(json);
}

@freezed
class ChallengeResult with _$ChallengeResult {
  const factory ChallengeResult({
    required String resultId,
    required String challengeId,
    required String winnerId,
    required String loserId,
    required int winnerRatingGain,
    required int loserRatingLoss,
    // ignore: invalid_annotation_target
    @JsonKey(fromJson: _requiredDateTimeFromTimestamp)
    required DateTime completedAt,
    required String gameMode, // 'white', 'black', 'random'
    @Default(0) int moveCount,
  }) = _ChallengeResult;

  factory ChallengeResult.fromJson(Map<String, dynamic> json) =>
      _$ChallengeResultFromJson(json);
}

// ========== Tournament System Models ==========
//
// `Tournament`/`TournamentParticipant`/`TournamentMatch` used to live here
// with chess-specific status/format vocabulary ('registration'/
// 'in-progress', 'single-elimination'/'double-elimination', non-nullable
// player slots with no bye support) and monetization fields (entryFee/
// prizePool). They have been replaced by `package:komovia_core`'s
// `Tournament`/`TournamentParticipant`/`TournamentMatch` (status vocabulary
// 'upcoming'/'active'/'completed'/'cancelled', format
// 'single_elimination'/'round_robin'/'swiss', nullable bye-aware player
// slots). `entryFee`/`prizePool`/`currentParticipants`/`timeControl` have
// no komovia_core equivalent and are kept as extra Firestore fields outside
// the shared model's toJson/fromJson — see `tournament_service.dart`.
// `TournamentStandings`/`TournamentRanking` below are unaffected: they're
// computed from each participant subdocument's own points/wins/losses/
// draws fields (also chess-specific, also kept outside the shared
// `TournamentParticipant`'s toJson/fromJson), not from the removed
// `TournamentParticipant` model itself.

@freezed
class TournamentStandings with _$TournamentStandings {
  const factory TournamentStandings({
    required String tournamentId,
    required List<TournamentRanking> rankings,
    required DateTime lastUpdated,
  }) = _TournamentStandings;

  factory TournamentStandings.fromJson(Map<String, dynamic> json) =>
      _$TournamentStandingsFromJson(json);
}

@freezed
class TournamentRanking with _$TournamentRanking {
  const factory TournamentRanking({
    required int position,
    required String userId,
    required String username,
    required int points,
    required int wins,
    required int losses,
    required int draws,
    required double buchholz, // Buchholz tie-break score
    @Default(0) int performance,
  }) = _TournamentRanking;

  factory TournamentRanking.fromJson(Map<String, dynamic> json) =>
      _$TournamentRankingFromJson(json);
}

@freezed
class TournamentPrize with _$TournamentPrize {
  const factory TournamentPrize({
    required String prizeId,
    required String tournamentId,
    required int position,
    required int prizeAmount,
    required String? awardedTo,
    required DateTime? awardedAt,
  }) = _TournamentPrize;

  factory TournamentPrize.fromJson(Map<String, dynamic> json) =>
      _$TournamentPrizeFromJson(json);
}

// ========== Activity Feed Models ==========

@freezed
class SocialActivity with _$SocialActivity {
  const factory SocialActivity({
    required String activityId,
    required String userId,
    required String
        activityType, // 'friend_joined', 'challenge_sent', 'tournament_joined', 'achievement_unlocked'
    required String title,
    required String description,
    required DateTime timestamp,
    required Map<String, dynamic> relatedData,
    @Default(false) bool isRead,
  }) = _SocialActivity;

  factory SocialActivity.fromJson(Map<String, dynamic> json) =>
      _$SocialActivityFromJson(json);
}

@freezed
class LeaderboardComparison with _$LeaderboardComparison {
  const factory LeaderboardComparison({
    required String userId1,
    required String username1,
    required int rating1,
    required int rank1,
    required String userId2,
    required String username2,
    required int rating2,
    required int rank2,
    required int headToHeadWins1,
    required int headToHeadWins2,
    required int headToHeadDraws,
  }) = _LeaderboardComparison;

  factory LeaderboardComparison.fromJson(Map<String, dynamic> json) =>
      _$LeaderboardComparisonFromJson(json);
}
