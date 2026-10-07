import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/phase_k_models.dart';
import '../utils/query_cache.dart';
import '../utils/pagination_helper.dart';

class FriendServiceOptimized {
  factory FriendServiceOptimized() => _instance;
  FriendServiceOptimized._internal() {
    _friendsCache = SmartCache(
      fetcher: _getUserFriendsFromDb,
      cacheTtl: const Duration(minutes: 10),
    );
    _requestsCache = SmartCache(
      fetcher: _getPendingRequestsFromDb,
      cacheTtl: const Duration(minutes: 5),
    );
    _activityCache = SmartCache(
      fetcher: _getActivityFeedFromDb,
      cacheTtl: const Duration(minutes: 2),
    );
    _friendCountCache = MonitoredCache(
      cacheTtl: const Duration(minutes: 15),
    );
  }
  static final FriendServiceOptimized _instance =
      FriendServiceOptimized._internal();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late final SmartCache<String, List<Friend>> _friendsCache;
  late final SmartCache<String, List<FriendRequest>> _requestsCache;
  late final SmartCache<String, List<FriendActivity>> _activityCache;
  late final MonitoredCache<String, int> _friendCountCache;

  static FriendServiceOptimized get instance => _instance;

  /// Get user's friend list with pagination
  Future<PaginatedResult<Friend>> getUserFriendsPaginated(
    String userId, {
    int pageSize = 20,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      final params = PaginationParams(
        pageSize: pageSize,
        startAfter: startAfter,
      );

      var query = _firestore
          .collection('friends')
          .doc(userId)
          .collection('list')
          .orderBy('connectedAt', descending: true);

      query = QueryOptimizer.applyPagination(
        query,
        params,
      );

      return await QueryOptimizer.executePaginatedQuery(
        query,
        params,
        Friend.fromJson,
      );
    } catch (e) {
      debugPrint('Error fetching paginated friends: $e');
      return PaginatedResult.empty();
    }
  }

  /// Get pending friend requests with pagination
  Future<PaginatedResult<FriendRequest>> getPendingRequestsPaginated(
    String userId, {
    int pageSize = 20,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      final params = PaginationParams(
        pageSize: pageSize,
        startAfter: startAfter,
      );

      var query = _firestore
          .collection('friend_requests')
          .where('toUserId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true);

      query = QueryOptimizer.applyPagination(
        query,
        params,
      );

      return await QueryOptimizer.executePaginatedQuery(
        query,
        params,
        FriendRequest.fromJson,
      );
    } catch (e) {
      debugPrint('Error fetching paginated requests: $e');
      return PaginatedResult.empty();
    }
  }

  /// Get activity feed with pagination
  Future<PaginatedResult<FriendActivity>> getActivityFeedPaginated(
    String userId, {
    int pageSize = 30,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      final params = PaginationParams(
        pageSize: pageSize,
        startAfter: startAfter,
      );

      var query = _firestore
          .collection('activity_feeds')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true);

      query = QueryOptimizer.applyPagination(
        query,
        params,
      );

      return await QueryOptimizer.executePaginatedQuery(
        query,
        params,
        FriendActivity.fromJson,
      );
    } catch (e) {
      debugPrint('Error fetching activity feed: $e');
      return PaginatedResult.empty();
    }
  }

  /// Get user's friend list with caching
  Future<List<Friend>> getUserFriendsOptimized(String userId) async =>
      _friendsCache.get(userId);

  /// Get pending requests with caching
  Future<List<FriendRequest>> getPendingRequestsOptimized(
          String userId) async =>
      _requestsCache.get(userId);

  /// Get activity feed with caching
  Future<List<FriendActivity>> getActivityFeedOptimized(
    String userId, {
    int limit = 50,
  }) async =>
      _activityCache.get(userId);

  /// Get friend count (cached)
  Future<int> getFriendCount(String userId) async {
    final cached = _friendCountCache.get(userId);
    if (cached != null) {
      return cached;
    }

    try {
      final countSnapshot = await _firestore
          .collection('friends')
          .doc(userId)
          .collection('list')
          .count()
          .get();

      final count = countSnapshot.count ?? 0;
      _friendCountCache.set(userId, count);
      return count;
    } catch (e) {
      debugPrint('Error fetching friend count: $e');
      return 0;
    }
  }

  /// Get multiple users' friend lists (batch)
  Future<Map<String, List<Friend>>> getUserFriendsBatch(
    List<String> userIds,
  ) async {
    try {
      // Batch load friends lists
      final results = <String, List<Friend>>{};

      for (final userId in userIds) {
        final friends = await getUserFriendsOptimized(userId);
        results[userId] = friends;
      }

      return results;
    } catch (e) {
      debugPrint('Error fetching friends batch: $e');
      return {};
    }
  }

  /// Check if two users are friends (cached)
  Future<bool> areFriends(String userId1, String userId2) async {
    try {
      final doc = await _firestore
          .collection('friends')
          .doc(userId1)
          .collection('list')
          .doc(userId2)
          .get();

      return doc.exists;
    } catch (e) {
      debugPrint('Error checking friend status: $e');
      return false;
    }
  }

  /// Get mutual friends between two users
  Future<List<Friend>> getMutualFriends(String userId1, String userId2) async {
    try {
      final friends1 = await getUserFriendsOptimized(userId1);
      final friends2 = await getUserFriendsOptimized(userId2);

      final ids1 = friends1.map((f) => f.friendId).toSet();
      final ids2 = friends2.map((f) => f.friendId).toSet();

      final mutualIds = ids1.intersection(ids2);

      return friends1.where((f) => mutualIds.contains(f.friendId)).toList();
    } catch (e) {
      debugPrint('Error fetching mutual friends: $e');
      return [];
    }
  }

  /// Database fetchers

  Future<List<Friend>> _getUserFriendsFromDb(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('friends')
          .doc(userId)
          .collection('list')
          .orderBy('connectedAt', descending: true)
          .get();

      return snapshot.docs.map((doc) => Friend.fromJson(doc.data())).toList();
    } catch (e) {
      debugPrint('Error fetching friends from db: $e');
      return [];
    }
  }

  Future<List<FriendRequest>> _getPendingRequestsFromDb(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('friend_requests')
          .where('toUserId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => FriendRequest.fromJson(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error fetching requests from db: $e');
      return [];
    }
  }

  Future<List<FriendActivity>> _getActivityFeedFromDb(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('activity_feeds')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      return snapshot.docs
          .map((doc) => FriendActivity.fromJson(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error fetching activity feed from db: $e');
      return [];
    }
  }

  /// Cache invalidation

  void invalidateUserCache(String userId) {
    _friendsCache.invalidate(userId);
    _requestsCache.invalidate(userId);
    _activityCache.invalidate(userId);
    _friendCountCache.remove(userId);
  }

  void invalidateFriendCache(String userId1, String userId2) {
    invalidateUserCache(userId1);
    invalidateUserCache(userId2);
  }

  void clearCache() {
    _friendsCache.invalidateAll();
    _requestsCache.invalidateAll();
    _activityCache.invalidateAll();
    _friendCountCache.clear();
  }
}
