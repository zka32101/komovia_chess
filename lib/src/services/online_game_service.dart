import 'dart:math' show pow;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import '../models/online_game.dart';
import 'friend_service.dart';

/// Manages online multiplayer games in real-time
class OnlineGameService {
  OnlineGameService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _firestore;
  final Logger _logger = Logger();

  // Game collection paths
  static const String _gamesCollection = 'games';
  static const String _gameMovesSubcollection = 'moves';

  /// Create a new online game from matched players
  Future<OnlineGame> createGame({
    required String whitePlayerId,
    required String whitePlayerName,
    required int whiteRating,
    required String blackPlayerId,
    required String blackPlayerName,
    required int blackRating,
    required String gameType, // online_pvp, online_rapid, online_blitz
    required String timeControl, // 10min, 5min, 3min
  }) async {
    try {
      final gameId = _firestore.collection(_gamesCollection).doc().id;
      final now = DateTime.now();

      // Convert time control string to milliseconds
      final timeControlMs = _parseTimeControl(timeControl);

      final game = OnlineGame(
        gameId: gameId,
        type: gameType,
        status: 'matchmaking',
        createdAt: now,
        whitePlayerId: whitePlayerId,
        blackPlayerId: blackPlayerId,
        whitePlayerName: whitePlayerName,
        blackPlayerName: blackPlayerName,
        whiteRating: whiteRating,
        blackRating: blackRating,
        pgn: '',
        currentFen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        moves: [],
        timeControl: timeControl,
        timeControlMs: timeControlMs,
        whiteTimeRemainingMs: timeControlMs,
        blackTimeRemainingMs: timeControlMs,
      );

      // Save game to Firestore
      await _firestore
          .collection(_gamesCollection)
          .doc(gameId)
          .set(game.toJson());

      _logger.i(
          'Created online game: $gameId ($whitePlayerName vs $blackPlayerName)');

      return game;
    } catch (e, st) {
      _logger.e('Failed to create game', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Start the game (transition from matchmaking to active)
  Future<void> startGame(String gameId) async {
    try {
      await _firestore.collection(_gamesCollection).doc(gameId).update({
        'status': 'active',
        'startedAt': FieldValue.serverTimestamp(),
      });

      _logger.i('Game started: $gameId');
    } catch (e, st) {
      _logger.e('Failed to start game', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Record a move in the game
  Future<void> recordMove({
    required String gameId,
    required int moveNumber,
    required String from,
    required String to,
    required String playerId,
    required String updatedFen,
    required String updatedPgn,
    String? promotion,
  }) async {
    try {
      final moveId = _firestore
          .collection(_gamesCollection)
          .doc(gameId)
          .collection(_gameMovesSubcollection)
          .doc()
          .id;

      final move = GameMove(
        moveNumber: moveNumber,
        from: from,
        to: to,
        promotion: promotion,
        timestamp: DateTime.now(),
        playerId: playerId,
      );

      // Save move to subcollection
      await _firestore
          .collection(_gamesCollection)
          .doc(gameId)
          .collection(_gameMovesSubcollection)
          .doc(moveId)
          .set(move.toJson());

      // Update game document with new FEN and PGN
      await _firestore.collection(_gamesCollection).doc(gameId).update({
        'currentFen': updatedFen,
        'pgn': updatedPgn,
        'moves': FieldValue.arrayUnion([move.toJson()]),
        'lastMoveTimestamp': FieldValue.serverTimestamp(),
      });

      _logger.i('Move recorded in game $gameId: $from$to');
    } catch (e, st) {
      _logger.e('Failed to record move', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Update time remaining for both players
  Future<void> updateTimeRemaining({
    required String gameId,
    required int whiteTimeMs,
    required int blackTimeMs,
  }) async {
    try {
      await _firestore.collection(_gamesCollection).doc(gameId).update({
        'whiteTimeRemainingMs': whiteTimeMs,
        'blackTimeRemainingMs': blackTimeMs,
      });

      // Check for timeout
      if (whiteTimeMs <= 0) {
        await _endGameWithResult(
          gameId: gameId,
          result: 'black_win',
          resultReason: 'timeout',
        );
      } else if (blackTimeMs <= 0) {
        await _endGameWithResult(
          gameId: gameId,
          result: 'white_win',
          resultReason: 'timeout',
        );
      }
    } catch (e, st) {
      _logger.e('Failed to update time', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Record player activity (for detecting timeouts)
  Future<void> recordActivity(String gameId, String playerId) async {
    try {
      final fieldName = playerId == 'white'
          ? 'whiteLastActivityTimestamp'
          : 'blackLastActivityTimestamp';

      await _firestore.collection(_gamesCollection).doc(gameId).update({
        fieldName: FieldValue.serverTimestamp(),
      });
    } catch (e, st) {
      _logger.e('Failed to record activity', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// End game with specific result
  Future<void> _endGameWithResult({
    required String gameId,
    required String result, // white_win, black_win, draw
    required String resultReason,
    int? whiteRatingDelta,
    int? blackRatingDelta,
  }) async {
    try {
      // Get current game to calculate new ratings if needed
      final gameDoc =
          await _firestore.collection(_gamesCollection).doc(gameId).get();
      final game = OnlineGame.fromJson(gameDoc.data()!);

      int whiteNewRating = game.whiteRating;
      int blackNewRating = game.blackRating;

      // Calculate rating changes if not provided
      if (whiteRatingDelta == null || blackRatingDelta == null) {
        final ratingChange =
            _calculateRatingChange(game.whiteRating, game.blackRating, result);
        whiteRatingDelta = ratingChange['whiteChange']!;
        blackRatingDelta = ratingChange['blackChange']!;
      }

      whiteNewRating = game.whiteRating + whiteRatingDelta;
      blackNewRating = game.blackRating + blackRatingDelta;

      // Update game with results
      await _firestore.collection(_gamesCollection).doc(gameId).update({
        'status': 'completed',
        'endedAt': FieldValue.serverTimestamp(),
        'result': result,
        'resultReason': resultReason,
        'whiteRatingDelta': whiteRatingDelta,
        'blackRatingDelta': blackRatingDelta,
        'whiteNewRating': whiteNewRating,
        'blackNewRating': blackNewRating,
      });

      _logger.i('Game completed: $gameId - $result ($resultReason)');

      await _logGameEndActivity(
        gameId: gameId,
        game: game,
        result: result,
        resultReason: resultReason,
      );
    } catch (e, st) {
      _logger.e('Failed to end game', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Posts a "I won/lost/drew" activity to each player's friends' feeds.
  /// Best-effort: a failure here shouldn't be treated as the game itself
  /// failing to end, so errors are swallowed (logActivity already does
  /// this internally too).
  Future<void> _logGameEndActivity({
    required String gameId,
    required OnlineGame game,
    required String result,
    required String resultReason,
  }) async {
    try {
      Future<void> log(String userId, String opponentName, String outcome) {
        final title = outcome == 'win'
            ? 'Game won!'
            : outcome == 'loss'
                ? 'Game lost'
                : 'Game drawn';
        final description = outcome == 'win'
            ? 'Won against $opponentName ($resultReason)'
            : outcome == 'loss'
                ? 'Lost against $opponentName ($resultReason)'
                : 'Drew against $opponentName ($resultReason)';

        return FriendService.instance.logActivity(
          userId,
          outcome,
          title,
          description,
          {'gameId': gameId, 'opponentName': opponentName, 'result': result},
        );
      }

      if (result == 'white_win') {
        await log(game.whitePlayerId, game.blackPlayerName, 'win');
        await log(game.blackPlayerId, game.whitePlayerName, 'loss');
      } else if (result == 'black_win') {
        await log(game.blackPlayerId, game.whitePlayerName, 'win');
        await log(game.whitePlayerId, game.blackPlayerName, 'loss');
      } else {
        await log(game.whitePlayerId, game.blackPlayerName, 'draw');
        await log(game.blackPlayerId, game.whitePlayerName, 'draw');
      }
    } catch (e) {
      _logger.w('Failed to log game-end activity for $gameId: $e');
    }
  }

  /// End game when player resigns
  Future<void> resignGame(String gameId, String playerId) async {
    try {
      final gameDoc =
          await _firestore.collection(_gamesCollection).doc(gameId).get();
      final game = OnlineGame.fromJson(gameDoc.data()!);

      final result = playerId == game.whitePlayerId ? 'black_win' : 'white_win';

      await _endGameWithResult(
        gameId: gameId,
        result: result,
        resultReason: 'resignation',
      );

      _logger.i('Player $playerId resigned from game $gameId');
    } catch (e, st) {
      _logger.e('Failed to resign game', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Offer a draw to the opponent
  Future<void> offerDraw(String gameId, String playerId) async {
    try {
      await _firestore.collection(_gamesCollection).doc(gameId).update({
        'drawOfferedBy': playerId,
      });

      _logger.i('Player $playerId offered a draw in game $gameId');
    } catch (e, st) {
      _logger.e('Failed to offer draw', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Decline the outstanding draw offer
  Future<void> declineDraw(String gameId) async {
    try {
      await _firestore.collection(_gamesCollection).doc(gameId).update({
        'drawOfferedBy': null,
      });

      _logger.i('Draw offer declined in game $gameId');
    } catch (e, st) {
      _logger.e('Failed to decline draw', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Accept the outstanding draw offer, ending the game as a draw
  Future<void> acceptDraw(String gameId) async {
    try {
      await _endGameWithResult(
        gameId: gameId,
        result: 'draw',
        resultReason: 'draw_agreement',
      );

      await _firestore.collection(_gamesCollection).doc(gameId).update({
        'drawOfferedBy': null,
      });

      _logger.i('Draw accepted in game $gameId');
    } catch (e, st) {
      _logger.e('Failed to accept draw', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Abandon game (player disconnected/timeout)
  Future<void> abandonGame(String gameId, String playerId) async {
    try {
      final gameDoc =
          await _firestore.collection(_gamesCollection).doc(gameId).get();
      final game = OnlineGame.fromJson(gameDoc.data()!);

      final result = playerId == game.whitePlayerId ? 'black_win' : 'white_win';

      await _firestore.collection(_gamesCollection).doc(gameId).update({
        'status': 'abandoned',
        'endedAt': FieldValue.serverTimestamp(),
        'result': result,
        'resultReason': 'abandonment',
        'abandonedBy': playerId,
      });

      _logger.i('Player $playerId abandoned game $gameId');
    } catch (e, st) {
      _logger.e('Failed to abandon game', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Get game by ID
  Future<OnlineGame?> getGame(String gameId) async {
    try {
      final doc =
          await _firestore.collection(_gamesCollection).doc(gameId).get();

      if (!doc.exists) {
        return null;
      }

      return OnlineGame.fromJson(doc.data()!);
    } catch (e, st) {
      _logger.e('Failed to get game', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Get all moves for a game
  Future<List<GameMove>> getGameMoves(String gameId) async {
    try {
      final snapshot = await _firestore
          .collection(_gamesCollection)
          .doc(gameId)
          .collection(_gameMovesSubcollection)
          .orderBy('moveNumber')
          .get();

      return snapshot.docs.map((doc) => GameMove.fromJson(doc.data())).toList();
    } catch (e, st) {
      _logger.e('Failed to get game moves', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Stream real-time game updates
  Stream<OnlineGame> watchGame(String gameId) => _firestore
          .collection(_gamesCollection)
          .doc(gameId)
          .snapshots()
          .map((snapshot) {
        if (!snapshot.exists) {
          throw Exception('Game not found');
        }
        return OnlineGame.fromJson(snapshot.data()!);
      });

  /// Get player's active games
  Future<List<OnlineGame>> getPlayerActiveGames(String playerId) async {
    try {
      final snapshot = await _firestore
          .collection(_gamesCollection)
          .where('status', isEqualTo: 'active')
          .where('whitePlayerId', isEqualTo: playerId)
          .get();

      final blackGames = await _firestore
          .collection(_gamesCollection)
          .where('status', isEqualTo: 'active')
          .where('blackPlayerId', isEqualTo: playerId)
          .get();

      final allDocs = [...snapshot.docs, ...blackGames.docs];
      return allDocs.map((doc) => OnlineGame.fromJson(doc.data())).toList();
    } catch (e, st) {
      _logger.e('Failed to get player active games', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Get player's recent games
  Future<List<OnlineGame>> getPlayerRecentGames(String playerId,
      {int limit = 10}) async {
    try {
      final whiteGames = await _firestore
          .collection(_gamesCollection)
          .where('whitePlayerId', isEqualTo: playerId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      final blackGames = await _firestore
          .collection(_gamesCollection)
          .where('blackPlayerId', isEqualTo: playerId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      final allDocs = [...whiteGames.docs, ...blackGames.docs];

      // Sort by date and take top limit
      allDocs.sort((a, b) {
        final gameA = OnlineGame.fromJson(a.data());
        final gameB = OnlineGame.fromJson(b.data());
        return gameB.createdAt.compareTo(gameA.createdAt);
      });

      return allDocs
          .take(limit)
          .map((doc) => OnlineGame.fromJson(doc.data()))
          .toList();
    } catch (e, st) {
      _logger.e('Failed to get player recent games', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Parse time control string to milliseconds
  int _parseTimeControl(String timeControl) {
    switch (timeControl) {
      case '3min':
        return 3 * 60 * 1000;
      case '5min':
        return 5 * 60 * 1000;
      case '10min':
        return 10 * 60 * 1000;
      default:
        return 5 * 60 * 1000; // Default to 5 minutes
    }
  }

  /// Calculate rating change based on ELO formula
  Map<String, int> _calculateRatingChange(
      int whiteRating, int blackRating, String result) {
    const double K = 32; // K-factor (can be adjusted)
    const double D = 400; // Rating difference divisor

    // Calculate expected scores
    final whiteExpected =
        1.0 / (1.0 + pow(10, (blackRating - whiteRating) / D).toDouble());
    final blackExpected = 1.0 - whiteExpected;

    // Determine actual score
    late double whiteScore;
    late double blackScore;

    switch (result) {
      case 'white_win':
        whiteScore = 1.0;
        blackScore = 0.0;
        break;
      case 'black_win':
        whiteScore = 0.0;
        blackScore = 1.0;
        break;
      case 'draw':
        whiteScore = 0.5;
        blackScore = 0.5;
        break;
      default:
        whiteScore = 0.5;
        blackScore = 0.5;
    }

    // Calculate rating changes
    final whiteChange = (K * (whiteScore - whiteExpected)).round();
    final blackChange = (K * (blackScore - blackExpected)).round();

    return {
      'whiteChange': whiteChange,
      'blackChange': blackChange,
    };
  }
}
