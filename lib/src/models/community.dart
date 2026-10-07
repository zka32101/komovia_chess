import 'package:freezed_annotation/freezed_annotation.dart';

part 'community.freezed.dart';
part 'community.g.dart';

enum PostCategory {
  @JsonValue('puzzle')
  puzzle,
  @JsonValue('strategy')
  strategy,
  @JsonValue('game')
  game,
  @JsonValue('general')
  general,
}

enum PostStatus {
  @JsonValue('published')
  published,
  @JsonValue('pending_review')
  pendingReview,
  @JsonValue('flagged')
  flagged,
  @JsonValue('removed')
  removed,
}

enum ChallengeStatus {
  @JsonValue('pending')
  pending,
  @JsonValue('accepted')
  accepted,
  @JsonValue('completed')
  completed,
}

@freezed
class UserProfile with _$UserProfile {
  const factory UserProfile({
    required String userId,
    required String displayName,
    required int rating,
    required int totalGamesPlayed,
    required int totalPuzzlesSolved,
    required DateTime joinDate,
    required String preferredTimeControl,
    required Map<String, String> socialLinks,
    required int followers,
    required int following,
    String? avatar,
    String? bio,
  }) = _UserProfile;

  factory UserProfile.fromJson(Map<String, dynamic> json) =>
      _$UserProfileFromJson(json);
}

@freezed
class CommunityPost with _$CommunityPost {
  const factory CommunityPost({
    required String id,
    required String authorId,
    required String content,
    required PostCategory category,
    required int upvotes,
    required int downvotes,
    required int replies,
    required DateTime createdDate,
    required PostStatus status,
  }) = _CommunityPost;

  factory CommunityPost.fromJson(Map<String, dynamic> json) =>
      _$CommunityPostFromJson(json);
}

@freezed
class PuzzleChallenge with _$PuzzleChallenge {
  const factory PuzzleChallenge({
    required String id,
    required String challengerId,
    required String challengedId,
    required String puzzleId,
    required DateTime expiryDate,
    required ChallengeStatus status,
    int? challengerScore,
    int? challengedScore,
    String? winner,
  }) = _PuzzleChallenge;

  factory PuzzleChallenge.fromJson(Map<String, dynamic> json) =>
      _$PuzzleChallengeFromJson(json);
}

@freezed
class CommunityGroup with _$CommunityGroup {
  const factory CommunityGroup({
    required String id,
    required String name,
    required String description,
    required String category,
    required int memberCount,
    required String creatorId,
    required DateTime createdDate,
    required List<String> members,
    required List<String> rules,
  }) = _CommunityGroup;

  factory CommunityGroup.fromJson(Map<String, dynamic> json) =>
      _$CommunityGroupFromJson(json);
}

enum FlagReason {
  @JsonValue('spam')
  spam,
  @JsonValue('offensive')
  offensive,
  @JsonValue('inappropriate')
  inappropriate,
  @JsonValue('misleading')
  misleading,
  @JsonValue('other')
  other,
}

@freezed
class FlaggedContent with _$FlaggedContent {
  const factory FlaggedContent({
    required String id,
    required String contentId,
    required String contentType,
    required String reporterId,
    required FlagReason reason,
    required String description,
    required DateTime flaggedAt,
  }) = _FlaggedContent;

  factory FlaggedContent.fromJson(Map<String, dynamic> json) =>
      _$FlaggedContentFromJson(json);
}
