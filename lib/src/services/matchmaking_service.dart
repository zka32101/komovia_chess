import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import '../models/online_game.dart';

/// Manages matchmaking queue and player pairing
class MatchmakingService {
  MatchmakingService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _firestore;
  final Logger _logger = Logger();

  // Matchmaking configuration
  static const int _baseTimeoutSeconds = 30;
  static const int _checkIntervalMs = 1000; // Check for matches every second

  // Rating range expansion over time (in seconds)
  static const Map<int, int> _ratingRangeByWaitTime = {
    0: 50, // First 10 seconds: ±50
    10: 100, // 10-20 seconds: ±100
    20: 200, // 20-30 seconds: ±200
    30: 300, // 30+ seconds: ±300
  };

  /// Add player to matchmaking queue
  Future<MatchmakingQueueEntry> joinQueue({
    required String playerId,
    required String playerName,
    required int currentRating,
    required String timeControlType,
    required String color, // 'white', 'black', or 'random'
  }) async {
    try {
      final queueId = _firestore.collection('matchmaking_queue').doc().id;
      final now = DateTime.now();
      final timeoutAt = now.add(const Duration(seconds: _baseTimeoutSeconds));

      final entry = MatchmakingQueueEntry(
        queueId: queueId,
        playerId: playerId,
        playerName: playerName,
        currentRating: currentRating,
        ratingRange: RatingRange(
          min: currentRating - 50,
          max: currentRating + 50,
        ),
        timeControlType: timeControlType,
        queuedAt: now,
        timeoutAt: timeoutAt,
        priority: _calculatePriority(currentRating),
        status: 'waiting',
        color: color,
      );

      await _firestore
          .collection('matchmaking_queue')
          .doc(queueId)
          .set(entry.toJson());

      _logger.i('Player $playerId joined queue: $queueId');

      // Start matching process
      _startMatchingProcess(queueId);

      return entry;
    } catch (e, st) {
      _logger.e('Failed to join queue', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Remove player from queue
  Future<void> leaveQueue(String queueId) async {
    try {
      await _firestore.collection('matchmaking_queue').doc(queueId).delete();
      _logger.i('Player removed from queue: $queueId');
    } catch (e, st) {
      _logger.e('Failed to leave queue', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Get current queue status
  Future<Map<String, dynamic>> getQueueStatus(String queueId) async {
    try {
      final doc =
          await _firestore.collection('matchmaking_queue').doc(queueId).get();

      if (!doc.exists) {
        return {'status': 'not_found'};
      }

      final entry = MatchmakingQueueEntry.fromJson(doc.data()!);

      return {
        'status': entry.status,
        'queueId': entry.queueId,
        'matchedGameId': entry.matchedGameId,
        'waitTimeSeconds': entry.waitTimeSeconds,
        'isExpired': entry.isExpired,
        'ratingRange': {
          'min': entry.ratingRange.min,
          'max': entry.ratingRange.max,
        },
      };
    } catch (e, st) {
      _logger.e('Failed to get queue status', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Get queue statistics
  Future<Map<String, dynamic>> getQueueStats() async {
    try {
      final snapshot = await _firestore
          .collection('matchmaking_queue')
          .where('status', isEqualTo: 'waiting')
          .get();

      final totalWaiting = snapshot.docs.length;

      // Group by time control
      final byTimeControl = <String, int>{};
      for (final doc in snapshot.docs) {
        final entry = MatchmakingQueueEntry.fromJson(doc.data());
        byTimeControl[entry.timeControlType] =
            (byTimeControl[entry.timeControlType] ?? 0) + 1;
      }

      return {
        'totalWaiting': totalWaiting,
        'byTimeControl': byTimeControl,
        'avgWaitTimeSeconds': _calculateAverageWaitTime(snapshot.docs),
      };
    } catch (e, st) {
      _logger.e('Failed to get queue stats', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Start matching process for a queue entry
  void _startMatchingProcess(String queueId) {
    // This would typically run in a Cloud Function or scheduled task
    // For now, log that matching has started
    _logger.i('Matching process started for queue entry: $queueId');
  }

  /// Calculate priority score (higher = more important to match)
  int _calculatePriority(int rating) {
    // Priority based on rating: higher ratings get slightly higher priority
    // to ensure better matches for stronger players
    return rating ~/ 100;
  }

  /// Get rating range based on wait time
  RatingRange _getRatingRange(DateTime queuedAt, int baseRating) {
    final waitTime = DateTime.now().difference(queuedAt).inSeconds;

    int range = 50;
    if (waitTime >= 30) {
      range = 300;
    } else if (waitTime >= 20) {
      range = 200;
    } else if (waitTime >= 10) {
      range = 100;
    }

    return RatingRange(
      min: baseRating - range,
      max: baseRating + range,
    );
  }

  /// Calculate average wait time
  double _calculateAverageWaitTime(List<QueryDocumentSnapshot> docs) {
    if (docs.isEmpty) return 0;

    double total = 0;
    for (final doc in docs) {
      final entry =
          MatchmakingQueueEntry.fromJson(doc.data()! as Map<String, dynamic>);
      total += entry.waitTimeSeconds;
    }

    return total / docs.length;
  }

  /// Cleanup expired queue entries (typically called by Cloud Function)
  Future<int> cleanupExpiredEntries() async {
    try {
      final snapshot = await _firestore
          .collection('matchmaking_queue')
          .where('timeoutAt', isLessThan: Timestamp.now())
          .get();

      int cleaned = 0;
      final batch = _firestore.batch();

      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
        cleaned++;
      }

      await batch.commit();
      _logger.i('Cleaned up $cleaned expired queue entries');

      return cleaned;
    } catch (e, st) {
      _logger.e('Failed to cleanup expired entries', error: e, stackTrace: st);
      rethrow;
    }
  }
}
