import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import 'dart:async';

/// Optimized matchmaking with rating and time control matching
class OptimizedMatchmakingService {
  // Maximum rating range

  OptimizedMatchmakingService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _firestore;
  final Logger _logger = Logger();

  static const String _queuesCollection = 'matchmakingQueues';
  static const String _playersCollection = 'users';
  static const int _matchmakingTimeoutMs = 30000; // 30 seconds
  static const int _ratingToleranceInitial = 100; // Initial rating range
  static const int _ratingToleranceIncrement =
      50; // Increase tolerance every 5s
  static const int _maxRatingTolerance = 400;

  /// Enqueue a player for matchmaking
  Future<MatchmakingQueue> enqueuePlayer({
    required String playerId,
    required String playerName,
    required int rating,
    required String timeControl,
    bool isProvisional = false,
  }) async {
    try {
      final queueId = _firestore.collection(_queuesCollection).doc().id;
      final now = DateTime.now();

      final queueEntry = MatchmakingQueue(
        queueId: queueId,
        playerId: playerId,
        playerName: playerName,
        rating: rating,
        timeControl: timeControl,
        isProvisional: isProvisional,
        enqueuedAt: now,
        status: 'waiting',
      );

      await _firestore
          .collection(_queuesCollection)
          .doc(queueId)
          .set(queueEntry.toJson());

      _logger.i(
          'Enqueued player $playerId ($playerName, rating: $rating) for $timeControl');

      return queueEntry;
    } catch (e, st) {
      _logger.e('Failed to enqueue player', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Find a match for a player
  Future<MatchResult?> findMatch(String queueId) async {
    try {
      // Get the queued player
      final playerQueueDoc =
          await _firestore.collection(_queuesCollection).doc(queueId).get();

      if (!playerQueueDoc.exists) {
        return null;
      }

      final playerQueue = MatchmakingQueue.fromJson(playerQueueDoc.data()!);

      if (playerQueue.status != 'waiting') {
        return null;
      }

      // Calculate wait time
      final waitTimeMs =
          DateTime.now().difference(playerQueue.enqueuedAt).inMilliseconds;

      // Determine current rating tolerance
      final currentTolerance = _calculateRatingTolerance(waitTimeMs);

      // Find potential opponents
      final potentialMatches = await _findPotentialMatches(
        playerId: playerQueue.playerId,
        rating: playerQueue.rating,
        timeControl: playerQueue.timeControl,
        ratingTolerance: currentTolerance,
        isProvisional: playerQueue.isProvisional,
      );

      if (potentialMatches.isEmpty) {
        return null;
      }

      // Select best match based on rating similarity
      final bestMatch = _selectBestMatch(playerQueue, potentialMatches);

      if (bestMatch != null) {
        return MatchResult(
          player1Id: playerQueue.playerId,
          player1Name: playerQueue.playerName,
          player1Rating: playerQueue.rating,
          player2Id: bestMatch.playerId,
          player2Name: bestMatch.playerName,
          player2Rating: bestMatch.rating,
          timeControl: playerQueue.timeControl,
          ratingDifference: (playerQueue.rating - bestMatch.rating).abs(),
          matchedAt: DateTime.now(),
        );
      }

      return null;
    } catch (e, st) {
      _logger.e('Failed to find match', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Accept match and mark players as matched
  Future<void> acceptMatch({
    required String player1Id,
    required String player2Id,
    required String gameId,
  }) async {
    try {
      final batch = _firestore.batch();

      // Mark queue entries as matched
      final queueDocs = await _firestore
          .collection(_queuesCollection)
          .where('playerId', whereIn: [player1Id, player2Id]).get();

      for (final doc in queueDocs.docs) {
        batch.update(doc.reference, {
          'status': 'matched',
          'gameId': gameId,
          'matchedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      _logger.i('Match accepted: $player1Id vs $player2Id (game: $gameId)');
    } catch (e, st) {
      _logger.e('Failed to accept match', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Decline match and re-queue player
  Future<void> declineMatch({
    required String playerId,
    required String queueId,
  }) async {
    try {
      await _firestore.collection(_queuesCollection).doc(queueId).update({
        'status': 'waiting',
        'lastDeclineAt': FieldValue.serverTimestamp(),
      });

      _logger.i('Player $playerId declined match, re-queued');
    } catch (e, st) {
      _logger.e('Failed to decline match', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Remove player from queue
  Future<void> removeFromQueue(String queueId) async {
    try {
      await _firestore.collection(_queuesCollection).doc(queueId).delete();
      _logger.i('Removed queue entry: $queueId');
    } catch (e, st) {
      _logger.e('Failed to remove from queue', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Get matchmaking statistics
  Future<MatchmakingStats> getMatchmakingStats(String timeControl) async {
    try {
      final activeQueues = await _firestore
          .collection(_queuesCollection)
          .where('timeControl', isEqualTo: timeControl)
          .where('status', isEqualTo: 'waiting')
          .get();

      final int totalWaiting = activeQueues.size;
      double averageWaitTimeMs = 0;

      if (totalWaiting > 0) {
        final now = DateTime.now();
        double totalWaitTime = 0;

        for (final doc in activeQueues.docs) {
          final queue = MatchmakingQueue.fromJson(doc.data());
          totalWaitTime +=
              now.difference(queue.enqueuedAt).inMilliseconds.toDouble();
        }

        averageWaitTimeMs = totalWaitTime / totalWaiting;
      }

      // Distribution by rating range
      final ratingDistribution = <String, int>{
        '600-999': 0,
        '1000-1299': 0,
        '1300-1599': 0,
        '1600-1899': 0,
        '1900-2199': 0,
        '2200+': 0,
      };

      for (final doc in activeQueues.docs) {
        final queue = MatchmakingQueue.fromJson(doc.data());
        final rating = queue.rating;

        if (rating < 1000) {
          ratingDistribution['600-999'] = ratingDistribution['600-999']! + 1;
        } else if (rating < 1300)
          ratingDistribution['1000-1299'] =
              ratingDistribution['1000-1299']! + 1;
        else if (rating < 1600)
          ratingDistribution['1300-1599'] =
              ratingDistribution['1300-1599']! + 1;
        else if (rating < 1900)
          ratingDistribution['1600-1899'] =
              ratingDistribution['1600-1899']! + 1;
        else if (rating < 2200)
          ratingDistribution['1900-2199'] =
              ratingDistribution['1900-2199']! + 1;
        else
          ratingDistribution['2200+'] = ratingDistribution['2200+']! + 1;
      }

      return MatchmakingStats(
        timeControl: timeControl,
        playersWaiting: totalWaiting,
        averageWaitTimeMs: averageWaitTimeMs.toInt(),
        ratingDistribution: ratingDistribution,
      );
    } catch (e, st) {
      _logger.e('Failed to get matchmaking stats', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Private helper methods

  int _calculateRatingTolerance(int waitTimeMs) {
    final toleranceIncreases = waitTimeMs ~/ 5000; // Increase every 5 seconds
    final calculatedTolerance = _ratingToleranceInitial +
        (toleranceIncreases * _ratingToleranceIncrement);
    return calculatedTolerance.clamp(0, _maxRatingTolerance);
  }

  Future<List<MatchmakingQueue>> _findPotentialMatches({
    required String playerId,
    required int rating,
    required String timeControl,
    required int ratingTolerance,
    required bool isProvisional,
  }) async {
    try {
      final lowerBound = (rating - ratingTolerance).clamp(600, 3000);
      final upperBound = (rating + ratingTolerance).clamp(600, 3000);

      final snapshot = await _firestore
          .collection(_queuesCollection)
          .where('timeControl', isEqualTo: timeControl)
          .where('status', isEqualTo: 'waiting')
          .where('rating', isGreaterThanOrEqualTo: lowerBound)
          .where('rating', isLessThanOrEqualTo: upperBound)
          .get();

      final matches = snapshot.docs
          .map((doc) => MatchmakingQueue.fromJson(doc.data()))
          .where((queue) =>
              queue.playerId != playerId && queue.status == 'waiting')
          .toList();

      return matches;
    } catch (e, st) {
      _logger.e('Failed to find potential matches', error: e, stackTrace: st);
      return [];
    }
  }

  MatchmakingQueue? _selectBestMatch(
    MatchmakingQueue player,
    List<MatchmakingQueue> potentialMatches,
  ) {
    if (potentialMatches.isEmpty) return null;

    // Sort by rating similarity
    potentialMatches.sort((a, b) {
      final aDiff = (player.rating - a.rating).abs();
      final bDiff = (player.rating - b.rating).abs();
      return aDiff.compareTo(bDiff);
    });

    return potentialMatches.first;
  }
}

/// Matchmaking queue entry
class MatchmakingQueue {
  MatchmakingQueue({
    required this.queueId,
    required this.playerId,
    required this.playerName,
    required this.rating,
    required this.timeControl,
    required this.isProvisional,
    required this.enqueuedAt,
    required this.status,
    this.gameId,
  });

  factory MatchmakingQueue.fromJson(Map<String, dynamic> json) =>
      MatchmakingQueue(
        queueId: json['queueId'] as String,
        playerId: json['playerId'] as String,
        playerName: json['playerName'] as String,
        rating: json['rating'] as int,
        timeControl: json['timeControl'] as String,
        isProvisional: json['isProvisional'] as bool? ?? false,
        enqueuedAt: (json['enqueuedAt'] as Timestamp).toDate(),
        status: json['status'] as String,
        gameId: json['gameId'] as String?,
      );
  final String queueId;
  final String playerId;
  final String playerName;
  final int rating;
  final String timeControl;
  final bool isProvisional;
  final DateTime enqueuedAt;
  final String status; // waiting, matched, declined
  final String? gameId;

  Map<String, dynamic> toJson() => {
        'queueId': queueId,
        'playerId': playerId,
        'playerName': playerName,
        'rating': rating,
        'timeControl': timeControl,
        'isProvisional': isProvisional,
        'enqueuedAt': Timestamp.fromDate(enqueuedAt),
        'status': status,
        'gameId': gameId,
      };
}

/// Match result
class MatchResult {
  MatchResult({
    required this.player1Id,
    required this.player1Name,
    required this.player1Rating,
    required this.player2Id,
    required this.player2Name,
    required this.player2Rating,
    required this.timeControl,
    required this.ratingDifference,
    required this.matchedAt,
  });
  final String player1Id;
  final String player1Name;
  final int player1Rating;
  final String player2Id;
  final String player2Name;
  final int player2Rating;
  final String timeControl;
  final int ratingDifference;
  final DateTime matchedAt;
}

/// Matchmaking statistics
class MatchmakingStats {
  MatchmakingStats({
    required this.timeControl,
    required this.playersWaiting,
    required this.averageWaitTimeMs,
    required this.ratingDistribution,
  });
  final String timeControl;
  final int playersWaiting;
  final int averageWaitTimeMs;
  final Map<String, int> ratingDistribution;
}
