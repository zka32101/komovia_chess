import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:komovia_core/komovia_core.dart';
import '../models/phase_k_models.dart' show FriendActivity;
import '../models/user.dart';

/// `Friendship` has no storage dependency (see its own doc comments in
/// komovia_core) — converting to/from Firestore's `DocumentSnapshot`/
/// `Timestamp` shape is this service's own responsibility.
///
/// A relationship doc's own id is always the *other* party's uid (see
/// [_friendDoc]), so [ownerUid] (read from the path, not the doc) becomes
/// `Friendship.uid` and the doc id becomes `Friendship.friendUid`.
Friendship _friendshipFromDoc(
  String ownerUid,
  DocumentSnapshot<Map<String, dynamic>> doc,
) {
  final data = doc.data() ?? const {};
  return Friendship.fromJson({
    ...data,
    'uid': ownerUid,
    'friendUid': doc.id,
  });
}

class FriendService {
  factory FriendService({FirebaseFirestore? firestore}) =>
      firestore == null ? _instance : FriendService._internal(firestore);
  FriendService._internal([FirebaseFirestore? firestore])
      : _firestore = firestore ?? FirebaseFirestore.instance;
  static final FriendService _instance = FriendService._internal();

  static FriendService get instance => _instance;

  final FirebaseFirestore _firestore;

  /// Reference to a user's own entry for a given friend, on either side of
  /// the relationship (`users/{uid}/friends/{otherUid}`).
  DocumentReference<Map<String, dynamic>> _friendDoc(
    String uid,
    String otherUid,
  ) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('friends')
        .doc(otherUid);
  }

  /// Looks up a user's display name to denormalize onto a
  /// friend-relationship doc — `Friendship.fromJson` requires displayName,
  /// but the relationship document itself only ever stores a uid, so this
  /// has to be fetched from the user's own profile at write time.
  Future<String> _lookupDisplayName(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data()?['displayName'] as String? ?? 'Unknown';
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

  /// Send a friend request (or, if one is already pending, just refresh it).
  ///
  /// The relationship is denormalized into both users' own `friends`
  /// subcollections so each side's queries only ever need to read their own
  /// data — both sides get a 'pending' entry here, not just the sender's.
  ///
  /// Refuses (returns false, writes nothing) if a relationship already
  /// exists as 'accepted' or 'blocked' — without this guard, re-running this
  /// against an existing accepted friend would silently reset both sides
  /// back to 'pending'. Re-sending while already 'pending' is harmless and
  /// still allowed (just refreshes addedAt).
  Future<bool> sendFriendRequest(String currentUid, String friendUid) async {
    try {
      final existingStatus = await getFriendStatus(
        currentUid: currentUid,
        friendUid: friendUid,
      );
      if (existingStatus == 'accepted' || existingStatus == 'blocked') {
        debugPrint(
          'sendFriendRequest no-op: $friendUid is already $existingStatus for $currentUid',
        );
        return false;
      }

      final now = DateTime.now().toIso8601String();
      final friendDisplayName = await _lookupDisplayName(friendUid);
      final currentDisplayName = await _lookupDisplayName(currentUid);

      String requestedBy = currentUid;
      if (existingStatus == 'pending') {
        final existingData = (await _friendDoc(currentUid, friendUid).get()).data();
        requestedBy = existingData?['requestedBy'] as String? ?? currentUid;
      }

      final batch = _firestore.batch();
      batch.set(_friendDoc(currentUid, friendUid), {
        'uid': friendUid,
        'displayName': friendDisplayName,
        'status': 'pending',
        'addedAt': now,
        'requestedBy': requestedBy,
      });
      batch.set(_friendDoc(friendUid, currentUid), {
        'uid': currentUid,
        'displayName': currentDisplayName,
        'status': 'pending',
        'addedAt': now,
        'requestedBy': requestedBy,
      });

      final notificationId = '${DateTime.now().millisecondsSinceEpoch}_request';
      batch.set(
          _firestore
              .collection('users')
              .doc(friendUid)
              .collection('notifications')
              .doc(notificationId),
          {
            // 'uid'/no top-level 'actionUrl'/'priority' - this doc is read
            // back as a `package:komovia_core` `AppNotification`, whose
            // extra fields live inside 'data' rather than at the top level.
            'uid': friendUid,
            'type': 'friend_request',
            'title': 'Friend Request',
            'body': '$currentDisplayName sent you a friend request',
            'createdAt': FieldValue.serverTimestamp(),
            'isRead': false,
            'data': {'actionUrl': '/friends', 'priority': 'normal'},
          });

      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('Error sending friend request: $e');
      return false;
    }
  }

  /// Accept a pending friend request — marks both sides' entries as
  /// accepted.
  Future<bool> acceptFriendRequest({
    required String currentUid,
    required String friendUid,
  }) async {
    try {
      final batch = _firestore.batch();
      batch.set(
        _friendDoc(currentUid, friendUid),
        {'uid': friendUid, 'status': 'accepted'},
        SetOptions(merge: true),
      );
      batch.set(
        _friendDoc(friendUid, currentUid),
        {'uid': currentUid, 'status': 'accepted'},
        SetOptions(merge: true),
      );

      final accepterName = await _lookupDisplayName(currentUid);
      final notificationId = '${DateTime.now().millisecondsSinceEpoch}_accepted';
      batch.set(
          _firestore
              .collection('users')
              .doc(friendUid)
              .collection('notifications')
              .doc(notificationId),
          {
            'uid': friendUid,
            'type': 'friend_request',
            'title': 'Friend Request Accepted',
            'body': '$accepterName accepted your friend request',
            'createdAt': FieldValue.serverTimestamp(),
            'isRead': false,
            'data': {'actionUrl': '/friends', 'priority': 'normal'},
          });

      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('Error accepting friend request: $e');
      return false;
    }
  }

  /// Reject a pending friend request — removes both sides' pending entries,
  /// so the sender is free to send a new request later. Also used for the
  /// sender's own "cancel request" action, since canceling a request you
  /// sent is the same data operation as the recipient declining it.
  ///
  /// Refuses (no-op) unless the relationship is actually 'pending' on the
  /// caller's own side, so a stale UI can't use this to delete an
  /// already-accepted friendship.
  Future<bool> rejectFriendRequest({
    required String currentUid,
    required String friendUid,
  }) async {
    try {
      final status = await getFriendStatus(
        currentUid: currentUid,
        friendUid: friendUid,
      );
      if (status != 'pending') {
        debugPrint(
          'rejectFriendRequest no-op: $friendUid is $status for $currentUid, not pending',
        );
        return false;
      }

      final batch = _firestore.batch();
      batch.delete(_friendDoc(currentUid, friendUid));
      batch.delete(_friendDoc(friendUid, currentUid));
      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('Error rejecting friend request: $e');
      return false;
    }
  }

  /// Remove a friend — both sides, so neither user is left with a stale
  /// mirror entry pointing at a friendship the other side ended.
  Future<bool> removeFriend(String currentUid, String friendUid) async {
    try {
      final batch = _firestore.batch();
      batch.delete(_friendDoc(currentUid, friendUid));
      batch.delete(_friendDoc(friendUid, currentUid));
      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('Error removing friend: $e');
      return false;
    }
  }

  /// Block a user. Works even for someone who was never actually a friend
  /// (the caller's own entry is a full upsert, not a merge-update, since a
  /// bare update would leave required fields like displayName/addedAt
  /// missing on a brand-new doc).
  ///
  /// Also mirrors the block onto the target's own entry, if one already
  /// exists — otherwise a blocked former friend would keep reading
  /// 'accepted' on their own side. The mirror is skipped if the target's
  /// entry is already 'blocked' for any reason, so this never overwrites a
  /// block the target placed independently; `blockedBy` records who
  /// actually caused each entry's blocked state, so [unblockFriend] can
  /// tell its own mirror apart from that independent block later.
  Future<bool> blockFriend({
    required String currentUid,
    required String friendUid,
  }) async {
    try {
      final ref = _friendDoc(currentUid, friendUid);
      final existing = (await ref.get()).data();

      await ref.set({
        'uid': friendUid,
        'displayName':
            existing?['displayName'] as String? ?? await _lookupDisplayName(friendUid),
        'status': 'blocked',
        'addedAt': existing?['addedAt'] ?? DateTime.now().toIso8601String(),
        'blockedBy': currentUid,
      });

      final otherRef = _friendDoc(friendUid, currentUid);
      final otherDoc = await otherRef.get();
      if (otherDoc.exists && otherDoc.data()?['status'] != 'blocked') {
        await otherRef.update({'status': 'blocked', 'blockedBy': currentUid});
      }

      return true;
    } catch (e) {
      debugPrint('Error blocking user: $e');
      return false;
    }
  }

  /// Unblock a user — removes the block on the caller's own side, returning
  /// to "no relationship" (a fresh friend request can be sent afterward).
  ///
  /// Also removes the mirror [blockFriend] placed on the target's own
  /// entry — but only when `blockedBy` shows this specific block caused it;
  /// if the target independently blocked back, their own block is left
  /// standing since only they can lift it.
  Future<bool> unblockFriend({
    required String currentUid,
    required String friendUid,
  }) async {
    try {
      await _friendDoc(currentUid, friendUid).delete();

      final otherRef = _friendDoc(friendUid, currentUid);
      final otherDoc = await otherRef.get();
      if (otherDoc.exists &&
          otherDoc.data()?['status'] == 'blocked' &&
          otherDoc.data()?['blockedBy'] == currentUid) {
        await otherRef.delete();
      }

      return true;
    } catch (e) {
      debugPrint('Error unblocking user: $e');
      return false;
    }
  }

  /// Get a user's relationships in a given [status] ('accepted' by
  /// default, 'pending' for requests, 'blocked' for blocked users).
  Future<List<Friendship>> getFriends(
    String uid, {
    String status = 'accepted',
  }) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('friends')
          .where('status', isEqualTo: status)
          .get();

      return snapshot.docs.map((doc) => _friendshipFromDoc(uid, doc)).toList();
    } catch (e) {
      debugPrint('Error fetching friends: $e');
      return [];
    }
  }

  /// Friend requests [uid] has received and hasn't responded to yet (an
  /// incoming OR outgoing pending entry — see `Friendship.wasRequestedBy`
  /// for distinguishing the two in the UI).
  Future<List<Friendship>> getPendingRequests(String uid) async {
    return getFriends(uid, status: 'pending');
  }

  /// Users [uid] has blocked.
  Future<List<Friendship>> getBlockedUsers(String uid) async {
    return getFriends(uid, status: 'blocked');
  }

  /// Raw relationship status on [currentUid]'s own side ('pending',
  /// 'accepted', 'blocked'), or null if no relationship doc exists at all.
  Future<String?> getFriendStatus({
    required String currentUid,
    required String friendUid,
  }) async {
    try {
      final doc = await _friendDoc(currentUid, friendUid).get();
      if (!doc.exists) return null;
      return doc.data()?['status'] as String?;
    } catch (e) {
      debugPrint('Error checking friend status: $e');
      return null;
    }
  }

  /// Get a user's activity feed (game results posted by their friends).
  ///
  /// `FriendActivity` has no komovia_core equivalent (it's a feed entry,
  /// not a relationship) and is unaffected by the `Friendship` migration —
  /// kept as this app's own model.
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

  /// Log an activity to the user's accepted friends' feeds.
  Future<void> logActivity(
    String userId,
    String activityType,
    String title,
    String description,
    Map<String, dynamic> metadata,
  ) async {
    try {
      final activityId = DateTime.now().millisecondsSinceEpoch.toString();
      final friends = await getFriends(userId);
      final batch = _firestore.batch();

      for (final friend in friends) {
        batch.set(
            _firestore
                .collection('activity_feed')
                .doc(friend.friendUid)
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
            });
      }

      await batch.commit();
    } catch (e) {
      debugPrint('Error logging activity: $e');
    }
  }
}
