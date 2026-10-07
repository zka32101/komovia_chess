import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/community.dart';

/// Community Service for user engagement and social features
class CommunityService {
  factory CommunityService({FirebaseFirestore? firestore}) {
    if (firestore != null) {
      _instance._firestore = firestore;
    }
    return _instance;
  }

  CommunityService._internal() : _firestore = FirebaseFirestore.instance;
  static final CommunityService _instance = CommunityService._internal();

  FirebaseFirestore _firestore;

  /// Create user profile
  Future<void> createUserProfile(String userId, UserProfile profile) async {
    try {
      await _firestore
          .collection('user_profiles')
          .doc(userId)
          .set(profile.toJson());
    } catch (e) {
      print('Profile creation error: $e');
      rethrow;
    }
  }

  /// Get user profile
  Future<UserProfile?> getUserProfile(String userId) async {
    try {
      final doc =
          await _firestore.collection('user_profiles').doc(userId).get();
      if (!doc.exists) return null;
      return UserProfile.fromJson(doc.data()!);
    } catch (e) {
      print('Error fetching user profile: $e');
      return null;
    }
  }

  /// Update user profile
  Future<void> updateUserProfile(
      String userId, Map<String, dynamic> updates) async {
    try {
      await _firestore.collection('user_profiles').doc(userId).update(updates);
    } catch (e) {
      print('Profile update error: $e');
      rethrow;
    }
  }

  /// Create puzzle challenge
  Future<void> createPuzzleChallenge({
    required String challengerId,
    required String challengedId,
    required String puzzleId,
    required DateTime expiryDate,
  }) async {
    try {
      final challenge = PuzzleChallenge(
        id: _firestore.collection('puzzle_challenges').doc().id,
        challengerId: challengerId,
        challengedId: challengedId,
        puzzleId: puzzleId,
        expiryDate: expiryDate,
        status: ChallengeStatus.pending,
        challengerScore: null,
        challengedScore: null,
        winner: null,
      );

      await _firestore
          .collection('puzzle_challenges')
          .doc(challenge.id)
          .set(challenge.toJson());
    } catch (e) {
      print('Challenge creation error: $e');
      rethrow;
    }
  }

  /// Accept puzzle challenge
  Future<void> acceptPuzzleChallenge(String challengeId) async {
    try {
      await _firestore
          .collection('puzzle_challenges')
          .doc(challengeId)
          .update({'status': ChallengeStatus.accepted.name});
    } catch (e) {
      print('Challenge acceptance error: $e');
      rethrow;
    }
  }

  /// Join community group
  Future<void> joinCommunityGroup(String userId, String groupId) async {
    try {
      await _firestore.collection('community_groups').doc(groupId).update({
        'members': FieldValue.arrayUnion([userId]),
        'memberCount': FieldValue.increment(1),
      });
    } catch (e) {
      print('Group join error: $e');
      rethrow;
    }
  }

  /// Create community post
  Future<void> createCommunityPost({
    required String authorId,
    required String content,
    required PostCategory category,
  }) async {
    try {
      final post = CommunityPost(
        id: _firestore.collection('community_posts').doc().id,
        authorId: authorId,
        content: content,
        category: category,
        upvotes: 0,
        downvotes: 0,
        replies: 0,
        createdDate: DateTime.now(),
        status: PostStatus.published,
      );

      await _firestore
          .collection('community_posts')
          .doc(post.id)
          .set(post.toJson());
    } catch (e) {
      print('Post creation error: $e');
      rethrow;
    }
  }

  /// Upvote post
  Future<void> upvotePost(String postId) async {
    try {
      await _firestore
          .collection('community_posts')
          .doc(postId)
          .update({'upvotes': FieldValue.increment(1)});
    } catch (e) {
      print('Upvote error: $e');
      rethrow;
    }
  }

  /// Downvote post
  Future<void> downvotePost(String postId) async {
    try {
      await _firestore
          .collection('community_posts')
          .doc(postId)
          .update({'downvotes': FieldValue.increment(1)});
    } catch (e) {
      print('Downvote error: $e');
      rethrow;
    }
  }

  /// Get community feed
  Future<List<CommunityPost>> getCommunityFeed({int limit = 50}) async {
    try {
      final querySnapshot = await _firestore
          .collection('community_posts')
          .where('status', isEqualTo: PostStatus.published.name)
          .orderBy('createdDate', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs
          .map((doc) => CommunityPost.fromJson(doc.data()))
          .toList();
    } catch (e) {
      print('Error fetching community feed: $e');
      return [];
    }
  }

  /// Get leaderboard
  Future<List<UserProfile>> getLeaderboard({int limit = 100}) async {
    try {
      final querySnapshot = await _firestore
          .collection('user_profiles')
          .orderBy('rating', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs
          .map((doc) => UserProfile.fromJson(doc.data()))
          .toList();
    } catch (e) {
      print('Error fetching leaderboard: $e');
      return [];
    }
  }

  /// Follow user
  Future<void> followUser(String userId, String targetUserId) async {
    try {
      await _firestore
          .collection('user_profiles')
          .doc(userId)
          .update({'following': FieldValue.increment(1)});

      await _firestore
          .collection('user_profiles')
          .doc(targetUserId)
          .update({'followers': FieldValue.increment(1)});

      await _firestore
          .collection('follows')
          .doc('${userId}_$targetUserId')
          .set({
        'follower': userId,
        'following': targetUserId,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Follow error: $e');
      rethrow;
    }
  }

  /// Get active challenges
  Future<List<PuzzleChallenge>> getActiveChallenges(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('puzzle_challenges')
          .where('challengedId', isEqualTo: userId)
          .where('status', isEqualTo: ChallengeStatus.pending.name)
          .get();

      return querySnapshot.docs
          .map((doc) => PuzzleChallenge.fromJson(doc.data()))
          .toList();
    } catch (e) {
      print('Error fetching active challenges: $e');
      return [];
    }
  }

  /// Get community groups
  Future<List<CommunityGroup>> getCommunityGroups({int limit = 50}) async {
    try {
      final querySnapshot = await _firestore
          .collection('community_groups')
          .orderBy('memberCount', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs
          .map((doc) => CommunityGroup.fromJson(doc.data()))
          .toList();
    } catch (e) {
      print('Error fetching community groups: $e');
      return [];
    }
  }

  /// Flag content
  Future<void> flagContent({
    required String contentId,
    required String contentType,
    required String reporterId,
    required FlagReason reason,
    required String description,
  }) async {
    try {
      final flag = FlaggedContent(
        id: _firestore.collection('flagged_content').doc().id,
        contentId: contentId,
        contentType: contentType,
        reporterId: reporterId,
        reason: reason,
        description: description,
        flaggedAt: DateTime.now(),
      );

      await _firestore
          .collection('flagged_content')
          .doc(flag.id)
          .set(flag.toJson());

      // Update post status
      if (contentType == 'post') {
        await _firestore
            .collection('community_posts')
            .doc(contentId)
            .update({'status': PostStatus.flagged.name});
      }
    } catch (e) {
      print('Flag error: $e');
      rethrow;
    }
  }
}
