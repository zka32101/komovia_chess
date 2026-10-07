import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';

/// Manages friend relationships and player connections
class PlayerConnectionService {
  PlayerConnectionService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _firestore;
  final Logger _logger = Logger();

  static const String _playersCollection = 'players';
  static const String _connectionsSubcollection = 'connections';
  static const String _requestsSubcollection = 'friend_requests';

  /// Send friend request to another player
  Future<void> sendFriendRequest({
    required String fromPlayerId,
    required String toPlayerId,
  }) async {
    try {
      if (fromPlayerId == toPlayerId) {
        throw Exception('Cannot send friend request to yourself');
      }

      final requestId = '$fromPlayerId-$toPlayerId';
      final now = DateTime.now();

      final request = FriendRequest(
        requestId: requestId,
        fromPlayerId: fromPlayerId,
        toPlayerId: toPlayerId,
        status: 'pending',
        sentDate: now,
      );

      await _firestore
          .collection(_playersCollection)
          .doc(toPlayerId)
          .collection(_requestsSubcollection)
          .doc(requestId)
          .set(request.toJson());

      _logger.i('Friend request sent from $fromPlayerId to $toPlayerId');
    } catch (e, st) {
      _logger.e('Failed to send friend request', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Accept friend request
  Future<void> acceptFriendRequest({
    required String playerId,
    required String requestId,
  }) async {
    try {
      final requestDoc = await _firestore
          .collection(_playersCollection)
          .doc(playerId)
          .collection(_requestsSubcollection)
          .doc(requestId)
          .get();

      if (!requestDoc.exists) {
        throw Exception('Friend request not found');
      }

      final request = FriendRequest.fromJson(requestDoc.data()!);
      final now = DateTime.now();

      // Create bidirectional friendship
      final connection1 = PlayerConnection(
        connectionId: '$playerId-${request.fromPlayerId}',
        player1Id: playerId,
        player2Id: request.fromPlayerId,
        status: 'active',
        connectedDate: now,
      );

      final connection2 = PlayerConnection(
        connectionId: '${request.fromPlayerId}-$playerId',
        player1Id: request.fromPlayerId,
        player2Id: playerId,
        status: 'active',
        connectedDate: now,
      );

      // Write both connections
      await _firestore
          .collection(_playersCollection)
          .doc(playerId)
          .collection(_connectionsSubcollection)
          .doc(connection1.connectionId)
          .set(connection1.toJson());

      await _firestore
          .collection(_playersCollection)
          .doc(request.fromPlayerId)
          .collection(_connectionsSubcollection)
          .doc(connection2.connectionId)
          .set(connection2.toJson());

      // Delete request
      await requestDoc.reference.delete();

      _logger.i('Friend request accepted: $requestId');
    } catch (e, st) {
      _logger.e('Failed to accept friend request', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Decline friend request
  Future<void> declineFriendRequest({
    required String playerId,
    required String requestId,
  }) async {
    try {
      await _firestore
          .collection(_playersCollection)
          .doc(playerId)
          .collection(_requestsSubcollection)
          .doc(requestId)
          .delete();

      _logger.i('Friend request declined: $requestId');
    } catch (e, st) {
      _logger.e('Failed to decline friend request', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Remove existing friend
  Future<void> removeFriend({
    required String playerId,
    required String friendId,
  }) async {
    try {
      final connectionId1 = '$playerId-$friendId';
      final connectionId2 = '$friendId-$playerId';

      // Delete both direction connections
      await _firestore
          .collection(_playersCollection)
          .doc(playerId)
          .collection(_connectionsSubcollection)
          .doc(connectionId1)
          .delete();

      await _firestore
          .collection(_playersCollection)
          .doc(friendId)
          .collection(_connectionsSubcollection)
          .doc(connectionId2)
          .delete();

      _logger.i('Removed friend: $playerId <-> $friendId');
    } catch (e, st) {
      _logger.e('Failed to remove friend', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Get player's friends list
  Future<List<PlayerConnection>> getFriendsList(String playerId) async {
    try {
      final snapshot = await _firestore
          .collection(_playersCollection)
          .doc(playerId)
          .collection(_connectionsSubcollection)
          .where('status', isEqualTo: 'active')
          .get();

      return snapshot.docs
          .map((doc) => PlayerConnection.fromJson(doc.data()))
          .toList();
    } catch (e, st) {
      _logger.e('Failed to get friends list', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Get pending friend requests (incoming)
  Future<List<FriendRequest>> getPendingRequests(String playerId) async {
    try {
      final snapshot = await _firestore
          .collection(_playersCollection)
          .doc(playerId)
          .collection(_requestsSubcollection)
          .where('status', isEqualTo: 'pending')
          .orderBy('sentDate', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => FriendRequest.fromJson(doc.data()))
          .toList();
    } catch (e, st) {
      _logger.e('Failed to get pending requests', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Get sent friend requests (outgoing)
  Future<List<FriendRequest>> getSentRequests(String playerId) async {
    try {
      final snapshot = await _firestore
          .collection(_playersCollection)
          .where('sentRequestIds', arrayContains: playerId)
          .get();

      return snapshot.docs.expand((doc) {
        final requests = (doc['sent_requests'] as List?)
                ?.where((req) => req['fromPlayerId'] == playerId)
                .map((req) => FriendRequest.fromJson(
                    Map<String, dynamic>.from(req as Map)))
                .toList() ??
            [];
        return requests;
      }).toList();
    } catch (e, st) {
      _logger.e('Failed to get sent requests', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Check if two players are friends
  Future<FriendshipStatus> isPlayerFriend(
    String playerId,
    String otherPlayerId,
  ) async {
    try {
      final connectionId = '$playerId-$otherPlayerId';

      final doc = await _firestore
          .collection(_playersCollection)
          .doc(playerId)
          .collection(_connectionsSubcollection)
          .doc(connectionId)
          .get();

      if (doc.exists) {
        final connection = PlayerConnection.fromJson(doc.data()!);
        return FriendshipStatus(
          isFriend: connection.status == 'active',
          status: connection.status,
          connectedDate: connection.connectedDate,
        );
      }

      // Check for pending request
      final requestId = '$otherPlayerId-$playerId';
      final requestDoc = await _firestore
          .collection(_playersCollection)
          .doc(playerId)
          .collection(_requestsSubcollection)
          .doc(requestId)
          .get();

      if (requestDoc.exists) {
        return FriendshipStatus(
          isFriend: false,
          status: 'pending_incoming',
          connectedDate: null,
        );
      }

      // Check for sent request
      final sentRequestId = '$playerId-$otherPlayerId';
      final sentRequestDoc = await _firestore
          .collection(_playersCollection)
          .doc(otherPlayerId)
          .collection(_requestsSubcollection)
          .doc(sentRequestId)
          .get();

      if (sentRequestDoc.exists) {
        return FriendshipStatus(
          isFriend: false,
          status: 'pending_outgoing',
          connectedDate: null,
        );
      }

      return FriendshipStatus(
        isFriend: false,
        status: 'none',
        connectedDate: null,
      );
    } catch (e, st) {
      _logger.e('Failed to check friendship', error: e, stackTrace: st);
      rethrow;
    }
  }
}

/// Player connection record
class PlayerConnection {
  PlayerConnection({
    required this.connectionId,
    required this.player1Id,
    required this.player2Id,
    required this.status,
    required this.connectedDate,
    this.updatedAt,
  });

  factory PlayerConnection.fromJson(Map<String, dynamic> json) =>
      PlayerConnection(
        connectionId: json['connectionId'] as String,
        player1Id: json['player1Id'] as String,
        player2Id: json['player2Id'] as String,
        status: json['status'] as String,
        connectedDate: (json['connectedDate'] as Timestamp).toDate(),
        updatedAt: json['updatedAt'] != null
            ? (json['updatedAt'] as Timestamp).toDate()
            : null,
      );
  final String connectionId;
  final String player1Id;
  final String player2Id;
  final String status; // active, pending, blocked
  final DateTime connectedDate;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() => {
        'connectionId': connectionId,
        'player1Id': player1Id,
        'player2Id': player2Id,
        'status': status,
        'connectedDate': Timestamp.fromDate(connectedDate),
        'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      };
}

/// Friend request
class FriendRequest {
  FriendRequest({
    required this.requestId,
    required this.fromPlayerId,
    required this.toPlayerId,
    required this.status,
    required this.sentDate,
    this.respondedDate,
  });

  factory FriendRequest.fromJson(Map<String, dynamic> json) => FriendRequest(
        requestId: json['requestId'] as String,
        fromPlayerId: json['fromPlayerId'] as String,
        toPlayerId: json['toPlayerId'] as String,
        status: json['status'] as String,
        sentDate: (json['sentDate'] as Timestamp).toDate(),
        respondedDate: json['respondedDate'] != null
            ? (json['respondedDate'] as Timestamp).toDate()
            : null,
      );
  final String requestId;
  final String fromPlayerId;
  final String toPlayerId;
  final String status; // pending, accepted, declined
  final DateTime sentDate;
  final DateTime? respondedDate;

  Map<String, dynamic> toJson() => {
        'requestId': requestId,
        'fromPlayerId': fromPlayerId,
        'toPlayerId': toPlayerId,
        'status': status,
        'sentDate': Timestamp.fromDate(sentDate),
        'respondedDate':
            respondedDate != null ? Timestamp.fromDate(respondedDate!) : null,
      };
}

/// Friendship status
class FriendshipStatus {
  FriendshipStatus({
    required this.isFriend,
    required this.status,
    this.connectedDate,
  });
  final bool isFriend;
  final String status; // none, pending_incoming, pending_outgoing, active
  final DateTime? connectedDate;
}
