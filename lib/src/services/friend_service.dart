import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/phase_k_models.dart';
import '../models/user.dart';

class FriendService {
  factory FriendService() => _instance;
  FriendService._internal();
  static final FriendService _instance = FriendService._internal();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, List<Friend>> _friendsCache = {};
  final Map<String, List<FriendRequest>> _requestsCache = {};

  static FriendService get instance => _instance;

  /// Get user's friend list
  Future<List<Friend>> getUserFriends(String userId) async {
    if (_friendsCache.containsKey(userId)) {
      return _friendsCache[userId]!;
    }

    try {
      final snapshot = await _firestore
          .collection('friends')
          .doc(userId)
          .collection('list')
          .orderBy('connectedAt', descending: true)
          .get();

      final friends =
          snapshot.docs.map((doc) => Friend.fromJson(doc.data())).toList();

      _friendsCache[userId] = friends;
      return friends;
    } catch (e) {
      debugPrint('Error fetching friends: $e');
      return [];
    }
  }

  /// Find users whose display name starts with [query], for the "add
  /// friend" search flow. Case-sensitive prefix match (Firestore has no
  /// case-insensitive query support without a denormalized lowercase
  /// field, which no user doc has).
  Future<List<UserModel>> searchUsersByDisplayName(
    String query, {
    int limit = 10,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    try {
      final snapshot = await _firestore
          .collection('users')
          .orderBy('displayName')
          .startAt([trimmed])
          .endAt(['$trimmed'])
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => UserModel.fromJson(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error searching users: $e');
      return [];
    }
  }

  /// Send friend request
  Future<void> sendFriendRequest(
    String fromUserId,
    String toUserId,
    String fromUsername,
    String fromAvatar,
  ) async {
    try {
      final requestId = DateTime.now().millisecondsSinceEpoch.toString();

      await _firestore.runTransaction((transaction) async {
        // Create request in recipient's inbox
        final recipientRequestDoc = _firestore
            .collection('friend_requests')
            .doc(toUserId)
            .collection('received')
            .doc(requestId);

        transaction.set(recipientRequestDoc, {
          'requestId': requestId,
          'fromUserId': fromUserId,
          'fromUsername': fromUsername,
          'fromAvatar': fromAvatar,
          'sentAt': FieldValue.serverTimestamp(),
          'status': 'pending',
          'respondedAt': null,
        });

        // Create request in sender's outbox
        final senderRequestDoc = _firestore
            .collection('friend_requests')
            .doc(fromUserId)
            .collection('sent')
            .doc(requestId);

        transaction.set(senderRequestDoc, {
          'requestId': requestId,
          'fromUserId': fromUserId,
          'fromUsername': fromUsername,
          'fromAvatar': fromAvatar,
          'sentAt': FieldValue.serverTimestamp(),
          'status': 'pending',
          'respondedAt': null,
        });

        final notificationId =
            '${DateTime.now().millisecondsSinceEpoch}_request';
        transaction.set(
            _firestore
                .collection('users')
                .doc(toUserId)
                .collection('notifications')
                .doc(notificationId),
            {
              'notificationId': notificationId,
              'userId': toUserId,
              'type': 'friendRequest',
              'title': 'Friend Request',
              'body': '$fromUsername sent you a friend request',
              'createdAt': FieldValue.serverTimestamp(),
              'isRead': false,
              'actionUrl': '/friends',
              'priority': 'normal',
            });
      });

      _requestsCache.remove(toUserId);
    } catch (e) {
      debugPrint('Error sending friend request: $e');
      rethrow;
    }
  }

  /// Accept friend request
  Future<void> acceptFriendRequest(
    String userId,
    String requestId,
    String friendId,
    String friendUsername,
    String friendAvatar,
    int friendRating,
  ) async {
    try {
      await _firestore.runTransaction((transaction) async {
        // Add to user's friends
        transaction.set(
            _firestore
                .collection('friends')
                .doc(userId)
                .collection('list')
                .doc(friendId),
            {
              'friendId': friendId,
              'friendUsername': friendUsername,
              'friendAvatar': friendAvatar,
              'connectedAt': FieldValue.serverTimestamp(),
              'isOnline': false,
              'lastSeen': FieldValue.serverTimestamp(),
              'friendRating': friendRating,
              'mutualChallenges': 0,
            });

        // Add to friend's friends
        final userData = await _firestore.collection('users').doc(userId).get();

        transaction.set(
            _firestore
                .collection('friends')
                .doc(friendId)
                .collection('list')
                .doc(userId),
            {
              'friendId': userId,
              // UserModel's fields are `displayName`/`photoUrl`, not
              // `username`/`avatar` -- those never existed on a real user
              // doc, so this always fell back to 'Unknown'/''.
              'friendUsername': userData['displayName'] ?? 'Unknown',
              'friendAvatar': userData['photoUrl'] ?? '',
              'connectedAt': FieldValue.serverTimestamp(),
              'isOnline': false,
              'lastSeen': FieldValue.serverTimestamp(),
              'friendRating': userData['rating'] ?? 1200,
              'mutualChallenges': 0,
            });

        // Update request status
        transaction.update(
            _firestore
                .collection('friend_requests')
                .doc(userId)
                .collection('received')
                .doc(requestId),
            {
              'status': 'accepted',
              'respondedAt': FieldValue.serverTimestamp(),
            });

        transaction.update(
            _firestore
                .collection('friend_requests')
                .doc(friendId)
                .collection('sent')
                .doc(requestId),
            {
              'status': 'accepted',
              'respondedAt': FieldValue.serverTimestamp(),
            });

        final accepterName = userData['displayName'] ?? 'Someone';
        final notificationId =
            '${DateTime.now().millisecondsSinceEpoch}_accepted';
        transaction.set(
            _firestore
                .collection('users')
                .doc(friendId)
                .collection('notifications')
                .doc(notificationId),
            {
              'notificationId': notificationId,
              'userId': friendId,
              'type': 'friendRequest',
              'title': 'Friend Request Accepted',
              'body': '$accepterName accepted your friend request',
              'createdAt': FieldValue.serverTimestamp(),
              'isRead': false,
              'actionUrl': '/friends',
              'priority': 'normal',
            });
      });

      _friendsCache.remove(userId);
      _friendsCache.remove(friendId);
      _requestsCache.remove(userId);
    } catch (e) {
      debugPrint('Error accepting friend request: $e');
      rethrow;
    }
  }

  /// Reject friend request
  Future<void> rejectFriendRequest(
    String userId,
    String requestId,
    String friendId,
  ) async {
    try {
      await _firestore.runTransaction((transaction) async {
        transaction.update(
            _firestore
                .collection('friend_requests')
                .doc(userId)
                .collection('received')
                .doc(requestId),
            {
              'status': 'rejected',
              'respondedAt': FieldValue.serverTimestamp(),
            });

        transaction.update(
            _firestore
                .collection('friend_requests')
                .doc(friendId)
                .collection('sent')
                .doc(requestId),
            {
              'status': 'rejected',
              'respondedAt': FieldValue.serverTimestamp(),
            });
      });

      _requestsCache.remove(userId);
    } catch (e) {
      debugPrint('Error rejecting friend request: $e');
      rethrow;
    }
  }

  /// Get pending friend requests
  Future<List<FriendRequest>> getPendingRequests(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('friend_requests')
          .doc(userId)
          .collection('received')
          .where('status', isEqualTo: 'pending')
          .orderBy('sentAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => FriendRequest.fromJson(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error fetching pending requests: $e');
      return [];
    }
  }

  /// Remove friend
  Future<void> removeFriend(String userId, String friendId) async {
    try {
      await _firestore.runTransaction((transaction) async {
        transaction.delete(_firestore
            .collection('friends')
            .doc(userId)
            .collection('list')
            .doc(friendId));

        transaction.delete(_firestore
            .collection('friends')
            .doc(friendId)
            .collection('list')
            .doc(userId));
      });

      _friendsCache.remove(userId);
      _friendsCache.remove(friendId);
    } catch (e) {
      debugPrint('Error removing friend: $e');
      rethrow;
    }
  }

  /// Block user
  Future<void> blockUser(
    String userId,
    String blockedUserId,
    String blockedUsername,
    String? reason,
  ) async {
    try {
      await _firestore.runTransaction((transaction) async {
        transaction.set(
            _firestore
                .collection('blocked_users')
                .doc(userId)
                .collection('list')
                .doc(blockedUserId),
            {
              'blockedUserId': blockedUserId,
              'blockedUsername': blockedUsername,
              'blockedAt': FieldValue.serverTimestamp(),
              'reason': reason,
            });

        // Remove from friends if they were friends
        transaction.delete(_firestore
            .collection('friends')
            .doc(userId)
            .collection('list')
            .doc(blockedUserId));
      });

      _friendsCache.remove(userId);
    } catch (e) {
      debugPrint('Error blocking user: $e');
      rethrow;
    }
  }

  /// Unblock user
  Future<void> unblockUser(String userId, String blockedUserId) async {
    try {
      await _firestore
          .collection('blocked_users')
          .doc(userId)
          .collection('list')
          .doc(blockedUserId)
          .delete();
    } catch (e) {
      debugPrint('Error unblocking user: $e');
      rethrow;
    }
  }

  /// Get activity feed
  Future<List<FriendActivity>> getActivityFeed(
    String userId, {
    int limit = 50,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('activity_feed')
          .doc(userId)
          .collection('feed')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => FriendActivity.fromJson(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error fetching activity feed: $e');
      return [];
    }
  }

  /// Log activity for user and their friends
  Future<void> logActivity(
    String userId,
    String activityType,
    String title,
    String description,
    Map<String, dynamic> metadata,
  ) async {
    try {
      final activityId = DateTime.now().millisecondsSinceEpoch.toString();

      // Get user's friends
      final friends = await getUserFriends(userId);

      // Add activity to all friends' feeds
      final batch = _firestore.batch();

      for (final friend in friends) {
        batch.set(
            _firestore
                .collection('activity_feed')
                .doc(friend.friendId)
                .collection('feed')
                .doc(activityId),
            {
              'activityId': activityId,
              'userId': userId,
              'activityType': activityType,
              'title': title,
              'description': description,
              'timestamp': FieldValue.serverTimestamp(),
              'metadata': metadata,
              'isRead': false,
            });
      }

      await batch.commit();
    } catch (e) {
      debugPrint('Error logging activity: $e');
    }
  }

  /// Update online status
  Future<void> updateOnlineStatus(String userId, bool isOnline) async {
    try {
      final friends = await getUserFriends(userId);

      for (final friend in friends) {
        await _firestore
            .collection('friends')
            .doc(friend.friendId)
            .collection('list')
            .doc(userId)
            .update({
          'isOnline': isOnline,
          'lastSeen': isOnline ? null : FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Error updating online status: $e');
    }
  }

  /// Clear cache
  void clearCache() {
    _friendsCache.clear();
    _requestsCache.clear();
  }
}
