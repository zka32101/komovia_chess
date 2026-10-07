import 'package:cloud_firestore/cloud_firestore.dart';

class SocialNetworkService {
  factory SocialNetworkService() => _instance;

  SocialNetworkService._internal();
  static final SocialNetworkService _instance =
      SocialNetworkService._internal();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> addFriend(String userId, String friendId) async {
    try {
      await _firestore
          .collection('social')
          .doc('friends')
          .collection(userId)
          .doc('requests')
          .set({
        'senderId': userId,
        'recipientId': friendId,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error adding friend: $e');
    }
  }

  Future<void> acceptFriendRequest(String userId, String requesterId) async {
    try {
      final friendDoc = await _firestore
          .collection('social')
          .doc('friends')
          .collection(userId)
          .doc(requesterId)
          .get();

      if (friendDoc.exists) {
        // Add to both users' friend lists
        await _firestore
            .collection('social')
            .doc('friends')
            .collection(userId)
            .doc(requesterId)
            .update({'status': 'accepted'});

        await _firestore
            .collection('social')
            .doc('friends')
            .collection(requesterId)
            .doc(userId)
            .update({'status': 'accepted'});
      }
    } catch (e) {
      print('Error accepting friend request: $e');
    }
  }

  Future<List<Friend>> getFriends(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('social')
          .doc('friends')
          .collection(userId)
          .where('status', isEqualTo: 'accepted')
          .get();

      final friends = <Friend>[];
      for (final doc in snapshot.docs) {
        final friendId = doc.id;
        final friendDoc =
            await _firestore.collection('users').doc(friendId).get();

        friends.add(Friend(
          userId: friendId,
          username: friendDoc['username'] ?? 'Unknown',
          photoUrl: friendDoc['photoUrl'] ?? '',
          rating: friendDoc['rating'] ?? 1000,
          isOnline: friendDoc['isOnline'] ?? false,
          lastSeen: friendDoc['lastSeen'] != null
              ? (friendDoc['lastSeen'] as Timestamp).toDate()
              : DateTime.now(),
        ));
      }

      return friends;
    } catch (e) {
      print('Error fetching friends: $e');
      return [];
    }
  }

  Future<List<FeedItem>> getSocialFeed(String userId, int limit) async {
    try {
      final snapshot = await _firestore
          .collection('social')
          .doc('feed')
          .collection(userId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => FeedItem.fromJson(doc.data())).toList();
    } catch (e) {
      print('Error fetching social feed: $e');
      return [];
    }
  }

  Future<UserProfile> getUserProfile(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final achievementsSnapshot = await _firestore
          .collection('achievements')
          .doc('user_achievements')
          .collection(userId)
          .get();

      final achievements = achievementsSnapshot.docs
          .map((doc) => UserAchievementMinimal.fromJson(doc.data()))
          .toList();

      return UserProfile(
        userId: userId,
        username: userDoc['username'] ?? 'Unknown',
        bio: userDoc['bio'] ?? '',
        photoUrl: userDoc['photoUrl'] ?? '',
        totalGames: userDoc['totalGames'] ?? 0,
        wins: userDoc['wins'] ?? 0,
        winRate: (userDoc['wins'] ?? 0) / (userDoc['totalGames'] ?? 1),
        rating: userDoc['rating'] ?? 1000,
        achievements: achievements,
        joinedAt: userDoc['createdAt'] != null
            ? (userDoc['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
      );
    } catch (e) {
      print('Error fetching user profile: $e');
      rethrow;
    }
  }

  Future<void> addFeedItem(
      String userId, String actionType, String actionData) async {
    try {
      await _firestore.collection('social').doc('feed').collection(userId).add({
        'userId': userId,
        'actionType': actionType,
        'actionData': actionData,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error adding feed item: $e');
    }
  }
}

class Friend {
  Friend({
    required this.userId,
    required this.username,
    required this.photoUrl,
    required this.rating,
    required this.isOnline,
    required this.lastSeen,
  });
  final String userId;
  final String username;
  final String photoUrl;
  final int rating;
  final bool isOnline;
  final DateTime lastSeen;
}

class FeedItem {
  FeedItem({
    required this.feedId,
    required this.userId,
    required this.actionType,
    required this.actionData,
    required this.createdAt,
  });

  factory FeedItem.fromJson(Map<String, dynamic> json) => FeedItem(
        feedId: json.toString(),
        userId: json['userId'] ?? '',
        actionType: json['actionType'] ?? '',
        actionData: json['actionData'] ?? '',
        createdAt: json['createdAt'] != null
            ? (json['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
      );
  final String feedId;
  final String userId;
  final String actionType;
  final String actionData;
  final DateTime createdAt;
}

class UserAchievementMinimal {
  UserAchievementMinimal({
    required this.achievementId,
    required this.unlockedAt,
  });

  factory UserAchievementMinimal.fromJson(Map<String, dynamic> json) =>
      UserAchievementMinimal(
        achievementId: json['achievementId'] ?? '',
        unlockedAt: json['unlockedAt'] != null
            ? (json['unlockedAt'] as Timestamp).toDate()
            : DateTime.now(),
      );
  final String achievementId;
  final DateTime unlockedAt;
}

class UserProfile {
  UserProfile({
    required this.userId,
    required this.username,
    required this.bio,
    required this.photoUrl,
    required this.totalGames,
    required this.wins,
    required this.winRate,
    required this.rating,
    required this.achievements,
    required this.joinedAt,
  });
  final String userId;
  final String username;
  final String bio;
  final String photoUrl;
  final int totalGames;
  final int wins;
  final double winRate;
  final int rating;
  final List<UserAchievementMinimal> achievements;
  final DateTime joinedAt;
}
