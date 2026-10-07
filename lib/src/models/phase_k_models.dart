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

@freezed
class LeaderboardEntry with _$LeaderboardEntry {
  const factory LeaderboardEntry({
    required String userId,
    required String username,
    required int rating,
    required int rank,
    required int wins,
    required int losses,
    required int draws,
    required DateTime lastUpdated,
    @Default('') String region,
    @Default(0.0) double winRate,
    @Default([]) List<DateTime> recentMatches,
  }) = _LeaderboardEntry;

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) =>
      _$LeaderboardEntryFromJson(json);
}

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

@freezed
class Friend with _$Friend {
  const factory Friend({
    required String friendId,
    required String friendUsername,
    required String friendAvatar,
    // ignore: invalid_annotation_target
    @JsonKey(fromJson: _requiredDateTimeFromTimestamp)
    required DateTime connectedAt,
    required bool isOnline,
    // ignore: invalid_annotation_target
    @JsonKey(fromJson: _dateTimeFromTimestamp) required DateTime? lastSeen,
    required int friendRating,
    @Default(0) int mutualChallenges,
  }) = _Friend;

  factory Friend.fromJson(Map<String, dynamic> json) => _$FriendFromJson(json);
}

@freezed
class FriendRequest with _$FriendRequest {
  const factory FriendRequest({
    required String requestId,
    required String fromUserId,
    required String fromUsername,
    required String fromAvatar,
    // ignore: invalid_annotation_target
    @JsonKey(fromJson: _requiredDateTimeFromTimestamp) required DateTime sentAt,
    required String status, // 'pending', 'accepted', 'rejected', 'cancelled'
    // ignore: invalid_annotation_target
    @JsonKey(fromJson: _dateTimeFromTimestamp) required DateTime? respondedAt,
  }) = _FriendRequest;

  factory FriendRequest.fromJson(Map<String, dynamic> json) =>
      _$FriendRequestFromJson(json);
}

@freezed
class BlockedUser with _$BlockedUser {
  const factory BlockedUser({
    required String blockedUserId,
    required String blockedUsername,
    required DateTime blockedAt,
    required String? reason,
  }) = _BlockedUser;

  factory BlockedUser.fromJson(Map<String, dynamic> json) =>
      _$BlockedUserFromJson(json);
}

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

@freezed
class Tournament with _$Tournament {
  const factory Tournament({
    required String tournamentId,
    required String name,
    required String description,
    required String
        status, // 'registration', 'in-progress', 'completed', 'cancelled'
    // ignore: invalid_annotation_target
    @JsonKey(fromJson: _requiredDateTimeFromTimestamp)
    required DateTime startDate,
    // ignore: invalid_annotation_target
    @JsonKey(fromJson: _requiredDateTimeFromTimestamp)
    required DateTime endDate,
    required String
        format, // 'single-elimination', 'double-elimination', 'round-robin', 'swiss'
    required int maxParticipants,
    required int currentParticipants,
    required String timeControl,
    required int entryFee,
    required int prizePool,
    required String createdBy,
    required List<String> participantIds,
  }) = _Tournament;

  factory Tournament.fromJson(Map<String, dynamic> json) =>
      _$TournamentFromJson(json);
}

@freezed
class TournamentParticipant with _$TournamentParticipant {
  const factory TournamentParticipant({
    required String participantId,
    required String tournamentId,
    required String userId,
    required String username,
    required int seedRating,
    // ignore: invalid_annotation_target
    @JsonKey(fromJson: _requiredDateTimeFromTimestamp)
    required DateTime joinedAt,
    required String status, // 'registered', 'active', 'eliminated', 'withdrew'
    required int points,
    required int wins,
    required int losses,
    required int draws,
    @Default([]) List<String> opponentIds,
  }) = _TournamentParticipant;

  factory TournamentParticipant.fromJson(Map<String, dynamic> json) =>
      _$TournamentParticipantFromJson(json);
}

@freezed
class TournamentMatch with _$TournamentMatch {
  const factory TournamentMatch({
    required String matchId,
    required String tournamentId,
    required int round,
    required String player1Id,
    required String player2Id,
    required String status, // 'scheduled', 'in-progress', 'completed'
    // ignore: invalid_annotation_target
    @JsonKey(fromJson: _requiredDateTimeFromTimestamp)
    required DateTime scheduledAt,
    // ignore: invalid_annotation_target
    @JsonKey(fromJson: _dateTimeFromTimestamp) required DateTime? startedAt,
    // ignore: invalid_annotation_target
    @JsonKey(fromJson: _dateTimeFromTimestamp) required DateTime? completedAt,
    required String? winnerId,
    required String? loserId,
    required String? gameId,
  }) = _TournamentMatch;

  factory TournamentMatch.fromJson(Map<String, dynamic> json) =>
      _$TournamentMatchFromJson(json);
}

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
