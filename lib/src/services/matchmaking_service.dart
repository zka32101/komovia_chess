import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import '../models/online_game.dart';
import 'online_game_service.dart';

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

  /// Look for a compatible opponent and, if one is found, create the
  /// game and mark both queue entries matched - or, if a compatible pair
  /// was already claimed on an earlier call, finish creating the game for
  /// it. This has to be driven by the client calling it repeatedly while
  /// waiting (e.g. every couple of seconds): this app has no Cloud
  /// Functions or scheduled backend (see CLAUDE.md), so nothing else will
  /// ever actually perform matching - `joinQueue` alone used to leave a
  /// player waiting forever, which is the bug this method fixes.
  ///
  /// Both waiting players are expected to call this periodically, so a
  /// transaction claims both sides' entries atomically the moment a
  /// compatible pair is found (status -> 'matching'), preventing a third
  /// player's concurrent call from also grabbing either one. Only the
  /// lexicographically-smaller playerId among the pair then actually
  /// creates the [OnlineGame] and flips both entries to 'matched' -
  /// otherwise both clients' simultaneous polling could create two
  /// separate games for the same pair. The other player's own next call
  /// (or a live listener on their own queue doc) picks up the finished
  /// 'matched' status.
  Future<void> tryMatch({
    required String queueId,
    required OnlineGameService gameService,
  }) async {
    try {
      final myRef = _firestore.collection('matchmaking_queue').doc(queueId);
      final myDoc = await myRef.get();
      if (!myDoc.exists) return;

      var mine = MatchmakingQueueEntry.fromJson(myDoc.data()!);

      if (mine.status == 'waiting') {
        final opponent = await _findCompatibleOpponent(mine);
        if (opponent == null) return;

        final claimed = await _claimPair(myRef, opponent.queueId);
        if (!claimed) return;

        mine = MatchmakingQueueEntry(
          queueId: mine.queueId,
          playerId: mine.playerId,
          playerName: mine.playerName,
          currentRating: mine.currentRating,
          ratingRange: mine.ratingRange,
          timeControlType: mine.timeControlType,
          queuedAt: mine.queuedAt,
          timeoutAt: mine.timeoutAt,
          priority: mine.priority,
          status: 'matching',
          color: mine.color,
          matchedOpponentId: opponent.playerId,
        );
      }

      if (mine.status != 'matching' || mine.matchedOpponentId == null) return;

      // Only the side responsible for creating the game proceeds past
      // this point; the other side just waits for 'matched' to appear.
      if (mine.playerId.compareTo(mine.matchedOpponentId!) > 0) return;

      final opponentQuery = await _firestore
          .collection('matchmaking_queue')
          .where('playerId', isEqualTo: mine.matchedOpponentId)
          .where('status', isEqualTo: 'matching')
          .limit(1)
          .get();
      if (opponentQuery.docs.isEmpty) return; // not visible yet - retry later

      final opponent =
          MatchmakingQueueEntry.fromJson(opponentQuery.docs.first.data());

      final mineIsWhite = _resolveWhitePlayer(mine, opponent);

      final game = await gameService.createGame(
        whitePlayerId: mineIsWhite ? mine.playerId : opponent.playerId,
        whitePlayerName: mineIsWhite ? mine.playerName : opponent.playerName,
        whiteRating: mineIsWhite ? mine.currentRating : opponent.currentRating,
        blackPlayerId: mineIsWhite ? opponent.playerId : mine.playerId,
        blackPlayerName: mineIsWhite ? opponent.playerName : mine.playerName,
        blackRating: mineIsWhite ? opponent.currentRating : mine.currentRating,
        gameType: 'online_pvp',
        timeControl: mine.timeControlType,
      );
      await gameService.startGame(game.gameId);

      final batch = _firestore.batch();
      batch.update(myRef, {'status': 'matched', 'matchedGameId': game.gameId});
      batch.update(
        _firestore.collection('matchmaking_queue').doc(opponent.queueId),
        {'status': 'matched', 'matchedGameId': game.gameId},
      );
      await batch.commit();

      _logger.i(
          'Matched ${mine.playerId} vs ${opponent.playerId}: ${game.gameId}');
    } catch (e, st) {
      _logger.e('Failed to try match', error: e, stackTrace: st);
      // Swallow rather than rethrow - this runs on a polling timer, and a
      // transient error on one tick shouldn't surface to the user when
      // the next tick will simply retry.
    }
  }

  /// Search currently-waiting entries (same time control, not myself) for
  /// one whose mutual rating ranges overlap mine.
  Future<MatchmakingQueueEntry?> _findCompatibleOpponent(
    MatchmakingQueueEntry mine,
  ) async {
    final myRange = _getRatingRange(mine.queuedAt, mine.currentRating);

    final snapshot = await _firestore
        .collection('matchmaking_queue')
        .where('status', isEqualTo: 'waiting')
        .where('timeControlType', isEqualTo: mine.timeControlType)
        .get();

    for (final doc in snapshot.docs) {
      if (doc.id == mine.queueId) continue;
      final candidate = MatchmakingQueueEntry.fromJson(doc.data());
      if (candidate.playerId == mine.playerId) continue;
      if (!myRange.contains(candidate.currentRating)) continue;

      final theirRange =
          _getRatingRange(candidate.queuedAt, candidate.currentRating);
      if (!theirRange.contains(mine.currentRating)) continue;

      return candidate;
    }

    return null;
  }

  /// Atomically flip both entries from 'waiting' to 'matching' with each
  /// recording the other as their matched opponent - false if either
  /// entry was no longer 'waiting' by the time the transaction ran (e.g.
  /// a third client's concurrent tryMatch already claimed one of them).
  Future<bool> _claimPair(
    DocumentReference<Map<String, dynamic>> myRef,
    String opponentQueueId,
  ) async {
    final opponentRef =
        _firestore.collection('matchmaking_queue').doc(opponentQueueId);

    return _firestore.runTransaction<bool>((transaction) async {
      final myFresh = await transaction.get(myRef);
      final opponentFresh = await transaction.get(opponentRef);

      if (!myFresh.exists || !opponentFresh.exists) return false;
      if (myFresh.data()?['status'] != 'waiting') return false;
      if (opponentFresh.data()?['status'] != 'waiting') return false;

      final myPlayerId = myFresh.data()!['playerId'] as String;
      final opponentPlayerId = opponentFresh.data()!['playerId'] as String;

      transaction
          .update(myRef, {'status': 'matching', 'matchedOpponentId': opponentPlayerId});
      transaction.update(
          opponentRef, {'status': 'matching', 'matchedOpponentId': myPlayerId});
      return true;
    });
  }

  /// Resolves color preferences into who plays white. A clear preference
  /// (one side wants white/black, the other doesn't equally want that
  /// same color) wins; if both are 'random' or both want the same color
  /// (a genuine conflict), falls back to a deterministic tie-break both
  /// clients can compute identically without further communication.
  bool _resolveWhitePlayer(
    MatchmakingQueueEntry a,
    MatchmakingQueueEntry b,
  ) {
    if (a.color == 'white' && b.color != 'white') return true;
    if (b.color == 'white' && a.color != 'white') return false;
    if (a.color == 'black' && b.color != 'black') return false;
    if (b.color == 'black' && a.color != 'black') return true;
    return a.playerId.compareTo(b.playerId) < 0;
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
