import 'dart:async' show unawaited;
import 'dart:math' show pow;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:chess/chess.dart' as chess_lib;
import 'package:logger/logger.dart';
import '../models/online_game.dart';
import '../models/match_record.dart';
import 'achievement_service.dart';
import 'friend_service.dart';
import 'match_history_service.dart';
import 'season_challenge_service.dart';
import 'season_management_service.dart';

/// Manages online multiplayer games in real-time
class OnlineGameService {
  OnlineGameService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    SeasonChallengeService? seasonChallengeService,
    SeasonManagementService? seasonManagementService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance,
        _seasonChallengeService =
            seasonChallengeService ?? SeasonChallengeService(),
        _seasonManagementService =
            seasonManagementService ?? SeasonManagementService();
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final Logger _logger = Logger();
  final SeasonChallengeService _seasonChallengeService;
  final SeasonManagementService _seasonManagementService;

  // Game collection paths
  static const String _gamesCollection = 'games';
  static const String _gameMovesSubcollection = 'moves';

  /// How long the player whose turn it is must go silent before the other
  /// player may claim the game by forfeit. Generous on purpose — this is
  /// for truly-dead games, not impatience (distinct from the per-move
  /// clock, which is about not rushing an individual move).
  static const Duration abandonmentThreshold = Duration(hours: 48);

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
  ///
  /// Previously this wrote `currentFen`/`pgn`/`moves` straight to
  /// Firestore from whatever the client computed locally, and
  /// firestore.rules never validated move legality at all - any
  /// participant could set their own game's board to an arbitrary (even
  /// illegal) position. The actual move application, legality check, and
  /// FEN/PGN recomputation now all happen server-side in the `recordMove`
  /// Cloud Function (functions/src/index.js, via chess.js in
  /// functions/src/game-validation.js) - firestore.rules no longer allows
  /// a client to change these fields directly (see `games/{gameId}`'s
  /// update rule).
  ///
  /// [updatedFen]/[updatedPgn] are accepted here only to keep this
  /// method's signature stable for existing callers (both compute them
  /// for their own optimistic local legality pre-check); the server
  /// ignores them and recomputes its own authoritative values.
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
      final callable = _functions.httpsCallable('recordMove');
      await callable.call<Map<String, dynamic>>({
        'gameId': gameId,
        'from': from,
        'to': to,
        'promotion': promotion,
        'playerId': playerId,
      });

      _logger.i('Move recorded in game $gameId: $from$to');
    } on FirebaseFunctionsException catch (e, st) {
      _logger.e('Failed to record move: ${e.code} ${e.message}',
          error: e, stackTrace: st);
      rethrow;
    } catch (e, st) {
      _logger.e('Failed to record move', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Record player activity (for detecting timeouts)
  ///
  /// [playerId] is the caller's real Firebase uid (not the literal string
  /// 'white'/'black') - the game doc is read first to resolve which side
  /// that uid actually plays, since comparing uid == 'white' would always
  /// be false and silently write to the wrong (black) activity field.
  Future<void> recordActivity(String gameId, String playerId) async {
    try {
      final docRef = _firestore.collection(_gamesCollection).doc(gameId);
      final snapshot = await docRef.get();
      final data = snapshot.data();
      if (data == null) return;

      final String fieldName;
      if (data['whitePlayerId'] == playerId) {
        fieldName = 'whiteLastActivityTimestamp';
      } else if (data['blackPlayerId'] == playerId) {
        fieldName = 'blackLastActivityTimestamp';
      } else {
        _logger.w('recordActivity: $playerId is not a player in $gameId');
        return;
      }

      await docRef.update({
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

      // Update game with results. Also clears drawOfferedBy/
      // takebackRequestedBy as part of this same write - acceptDraw used
      // to do this as a separate, later .update() call, which could
      // leave a completed game with a stale drawOfferedBy if the app
      // died or the network dropped between the two writes (the
      // draw-offer banner in online_game_screen.dart isn't gated on
      // status == 'active', only on drawOfferedBy != null). Every path
      // through here (resign/claimDraw/abandon/forfeit/acceptDraw/
      // timeout) can equally leave either flag stale, so clearing both
      // unconditionally here is simpler and safer than fixing each
      // caller individually.
      await _firestore.collection(_gamesCollection).doc(gameId).update({
        'status': 'completed',
        'endedAt': FieldValue.serverTimestamp(),
        'result': result,
        'resultReason': resultReason,
        'whiteRatingDelta': whiteRatingDelta,
        'blackRatingDelta': blackRatingDelta,
        'whiteNewRating': whiteNewRating,
        'blackNewRating': blackNewRating,
        'drawOfferedBy': null,
        'takebackRequestedBy': null,
      });

      // Persist the new rating to each player's own record - previously
      // the computed whiteNewRating/blackNewRating only ever landed on
      // the game document above, never on the user themselves, so an
      // online game's rating change was silently lost: it showed nowhere
      // (not on the profile, not on any leaderboard) after the game
      // ended. `onlineRating` is this app's separate PvP rating track,
      // distinct from the CPU-game `rating` field.
      //
      // wins/losses/draws/gamesPlayed are the same shared stat fields
      // CpuGameProvider already increments for CPU games (see
      // cpu_game_provider.dart) - AchievementService._calculateCurrentProgress
      // reads `wins` off this exact user doc for first_win/five_wins, but
      // until this fix an online win never moved it, so those achievements
      // could only ever be unlocked by playing CPU games.
      final String whiteResult =
          result == 'white_win' ? 'win' : (result == 'draw' ? 'draw' : 'loss');
      final String blackResult =
          result == 'black_win' ? 'win' : (result == 'draw' ? 'draw' : 'loss');

      await _firestore.collection('users').doc(game.whitePlayerId).update({
        'onlineRating': whiteNewRating,
        'gamesPlayed': FieldValue.increment(1),
        if (whiteResult == 'win') 'wins': FieldValue.increment(1),
        if (whiteResult == 'loss') 'losses': FieldValue.increment(1),
        if (whiteResult == 'draw') 'draws': FieldValue.increment(1),
      });
      await _firestore.collection('users').doc(game.blackPlayerId).update({
        'onlineRating': blackNewRating,
        'gamesPlayed': FieldValue.increment(1),
        if (blackResult == 'win') 'wins': FieldValue.increment(1),
        if (blackResult == 'loss') 'losses': FieldValue.increment(1),
        if (blackResult == 'draw') 'draws': FieldValue.increment(1),
      });

      // Best-effort: record this match for both players' Match History /
      // comparison screens - previously nothing anywhere ever called
      // MatchHistoryService.recordMatch, so those screens always showed
      // an empty history regardless of games played. One record per
      // player, from that player's own perspective (opponent = the
      // other side), using the ratings already just computed above
      // rather than a second increment (recordMatch only writes the
      // match_history entry itself - see its own doc comment).
      final matchHistoryService = MatchHistoryService();
      final movesUci = game.moves
          .where((m) => m.from.isNotEmpty && m.to.isNotEmpty) // skip passes
          .map((m) => {
                'from': m.from,
                'to': m.to,
                'promotion': m.promotion,
              })
          .toList();
      unawaited(matchHistoryService.recordMatch(
        MatchRecord(
          matchId: '${gameId}_white',
          playerId: game.whitePlayerId,
          opponentId: game.blackPlayerId,
          opponentName: game.blackPlayerName,
          playerRatingBefore: game.whiteRating,
          playerRatingAfter: whiteNewRating,
          opponentRatingBefore: game.blackRating,
          opponentRatingAfter: blackNewRating,
          result: whiteResult,
          timeControl: game.timeControl,
          playedAt: DateTime.now(),
        ),
        moves: movesUci,
      ));
      unawaited(matchHistoryService.recordMatch(
        MatchRecord(
          matchId: '${gameId}_black',
          playerId: game.blackPlayerId,
          opponentId: game.whitePlayerId,
          opponentName: game.whitePlayerName,
          playerRatingBefore: game.blackRating,
          playerRatingAfter: blackNewRating,
          opponentRatingBefore: game.whiteRating,
          opponentRatingAfter: whiteNewRating,
          result: blackResult,
          timeControl: game.timeControl,
          playedAt: DateTime.now(),
        ),
        moves: movesUci,
      ));

      _logger.i('Game completed: $gameId - $result ($resultReason)');

      await _logGameEndActivity(
        gameId: gameId,
        game: game,
        result: result,
        resultReason: resultReason,
      );

      // Best-effort: a win may have just satisfied an achievement
      // (first_win/five_wins). Swallows its own errors internally and
      // never blocks the game from ending.
      final winnerId = result == 'white_win'
          ? game.whitePlayerId
          : result == 'black_win'
              ? game.blackPlayerId
              : null;
      if (winnerId != null) {
        unawaited(AchievementService().checkAndUnlockAchievements(winnerId));
      }

      // Best-effort: advance any active seasonal challenge tracking wins/
      // draws/games-played for both players. Previously nothing in the
      // app ever called into SeasonChallengeService from a real game
      // ending, so no seasonal challenge could progress through actual
      // play.
      unawaited(_recordSeasonChallengeProgress(
        playerId: game.whitePlayerId,
        playerResult: whiteResult,
      ));
      unawaited(_recordSeasonChallengeProgress(
        playerId: game.blackPlayerId,
        playerResult: blackResult,
      ));
    } catch (e, st) {
      _logger.e('Failed to end game', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> _recordSeasonChallengeProgress({
    required String playerId,
    required String playerResult, // win, loss, draw
  }) async {
    try {
      final season = await _seasonManagementService.getCurrentSeason();
      if (season == null) return;

      await _seasonChallengeService.recordMetricProgress(
        playerId: playerId,
        seasonId: season.seasonId,
        metric: GameplayMetric.playGames,
      );
      if (playerResult == 'win') {
        await _seasonChallengeService.recordMetricProgress(
          playerId: playerId,
          seasonId: season.seasonId,
          metric: GameplayMetric.winGames,
        );
      } else if (playerResult == 'draw') {
        await _seasonChallengeService.recordMetricProgress(
          playerId: playerId,
          seasonId: season.seasonId,
          metric: GameplayMetric.drawGames,
        );
      }
    } catch (_) {
      // Best-effort; never block the game from ending.
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
      // _endGameWithResult now clears drawOfferedBy atomically as part
      // of its own single write - no separate update needed here.
      await _endGameWithResult(
        gameId: gameId,
        result: 'draw',
        resultReason: 'draw_agreement',
      );

      _logger.i('Draw accepted in game $gameId');
    } catch (e, st) {
      _logger.e('Failed to accept draw', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Claim a draw under the threefold-repetition or 50-move rule.
  /// `chess_lib.Chess.fromFEN(currentFen)` alone has no memory of earlier
  /// positions, so threefold repetition can only be detected by replaying
  /// every recorded move from the start; the 50-move rule (`half_moves`
  /// reaching 100 half-moves) falls out of that same replay. Throws
  /// (no-op on the game itself) if neither condition actually holds, so a
  /// mistaken or stale claim can't end the game.
  Future<void> claimDraw(String gameId) async {
    final gameDoc =
        await _firestore.collection(_gamesCollection).doc(gameId).get();
    if (!gameDoc.exists) {
      throw StateError('Game not found');
    }
    final game = OnlineGame.fromJson(gameDoc.data()!);

    final replay = chess_lib.Chess();
    for (final move in game.moves) {
      replay.move({
        'from': move.from,
        'to': move.to,
        if (move.promotion != null) 'promotion': move.promotion,
      });
    }

    final isThreefold = replay.in_threefold_repetition;
    final isFiftyMove = replay.half_moves >= 100;
    if (!isThreefold && !isFiftyMove) {
      throw StateError(
          'Draw claim is not valid - no threefold repetition or 50-move rule');
    }

    await _endGameWithResult(
      gameId: gameId,
      result: 'draw',
      resultReason: isThreefold ? 'draw_claim_threefold' : 'draw_claim_fifty_move',
    );

    _logger.i('Draw claimed in game $gameId '
        '(${isThreefold ? "threefold repetition" : "50-move rule"})');
  }

  /// Abandon game (player disconnected/timeout)
  Future<void> abandonGame(String gameId, String playerId) async {
    try {
      final gameDoc =
          await _firestore.collection(_gamesCollection).doc(gameId).get();
      final game = OnlineGame.fromJson(gameDoc.data()!);

      final result = playerId == game.whitePlayerId ? 'black_win' : 'white_win';

      // Previously this wrote 'abandoned'/'abandonment' directly to the
      // game doc and returned, bypassing _endGameWithResult entirely -
      // unlike resignGame/acceptDraw/claimDraw/claimAbandonmentForfeit,
      // which all route through it. That meant neither player's wins/
      // losses/onlineRating/gamesPlayed ever updated, no achievement
      // check ran, and no seasonal challenge progressed when a game
      // ended by abandonment.
      await _endGameWithResult(
        gameId: gameId,
        result: result,
        resultReason: 'abandonment',
      );
      await _firestore.collection(_gamesCollection).doc(gameId).update({
        'abandonedBy': playerId,
      });

      _logger.i('Player $playerId abandoned game $gameId');
    } catch (e, st) {
      _logger.e('Failed to abandon game', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Claim victory by forfeit when the opponent (whoever's turn it
  /// currently is) has gone silent for at least [threshold]. Re-checks
  /// every condition server-side (via a fresh read) so a stale client
  /// can't exploit a race, and is a no-op rather than throwing if the
  /// claim no longer holds (e.g. the opponent moved in the meantime, or
  /// the game already ended some other way).
  Future<void> claimAbandonmentForfeit(
    String gameId,
    String claimantPlayerId, {
    Duration threshold = abandonmentThreshold,
  }) async {
    try {
      final gameDoc =
          await _firestore.collection(_gamesCollection).doc(gameId).get();
      if (!gameDoc.exists) return;
      final game = OnlineGame.fromJson(gameDoc.data()!);

      if (!game.canClaimAbandonmentForfeit(claimantPlayerId,
          threshold: threshold)) {
        _logger.w(
            'Abandonment forfeit claim rejected for game $gameId by $claimantPlayerId');
        return;
      }

      final result =
          claimantPlayerId == game.whitePlayerId ? 'white_win' : 'black_win';

      await _endGameWithResult(
        gameId: gameId,
        result: result,
        resultReason: 'abandonment_forfeit',
      );

      _logger.i(
          'Abandonment forfeit claimed in game $gameId by $claimantPlayerId');
    } catch (e, st) {
      _logger.e('Failed to claim abandonment forfeit',
          error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Create a same-opponent rematch of [previousGame] with colors swapped
  /// (whoever was white becomes black). Unlike a fresh matchmaking game, a
  /// rematch needs no separate "start" step since both players just
  /// finished playing each other, so it goes straight to 'active'.
  /// Notifies the other player the same way a fresh match does.
  Future<OnlineGame> createRematch({
    required OnlineGame previousGame,
    required String requestedByUid,
  }) async {
    final newWhiteId = previousGame.blackPlayerId;
    final newWhiteName = previousGame.blackPlayerName;
    final newWhiteRating =
        previousGame.blackNewRating ?? previousGame.blackRating;
    final newBlackId = previousGame.whitePlayerId;
    final newBlackName = previousGame.whitePlayerName;
    final newBlackRating =
        previousGame.whiteNewRating ?? previousGame.whiteRating;

    final game = await createGame(
      whitePlayerId: newWhiteId,
      whitePlayerName: newWhiteName,
      whiteRating: newWhiteRating,
      blackPlayerId: newBlackId,
      blackPlayerName: newBlackName,
      blackRating: newBlackRating,
      gameType: previousGame.type,
      timeControl: previousGame.timeControl,
    );
    await startGame(game.gameId);

    final isRequesterWhite = requestedByUid == previousGame.whitePlayerId;
    final opponentId = isRequesterWhite
        ? previousGame.blackPlayerId
        : previousGame.whitePlayerId;
    final requesterName = isRequesterWhite
        ? previousGame.whitePlayerName
        : previousGame.blackPlayerName;

    try {
      final notificationId = '${DateTime.now().millisecondsSinceEpoch}_rematch';
      await _firestore
          .collection('users')
          .doc(opponentId)
          .collection('notifications')
          .doc(notificationId)
          .set({
        'uid': opponentId,
        'type': 'game_matched',
        'title': 'Rematch!',
        'body': '$requesterName started a rematch',
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
        'data': {
          'gameId': game.gameId,
          'actionUrl': '/online-game/${game.gameId}',
          'priority': 'normal',
        },
      });
    } catch (e) {
      _logger.w('Failed to send rematch notification: $e');
    }

    return game;
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

  /// Parse time control string to milliseconds.
  ///
  /// '1day'/'3day'/'7day' are correspondence-style controls (⑤ from the
  /// feature survey this round) - a much larger time bank than the live
  /// controls above, meant to let two players make a move every so often
  /// over several days rather than sit through a live clock. They reuse
  /// the exact same recordMove/handleTimeout clock machinery as every
  /// other time control (whiteTimeRemainingMs/blackTimeRemainingMs only
  /// ever tick down while it's that side's turn, same as a real chess
  /// clock - see index.js's recordMove), so no new backend architecture
  /// was needed. This is a real limitation worth being explicit about:
  /// it's a single shared time bank for the whole game, not a per-move
  /// allowance that replenishes after each move the way some other
  /// correspondence chess implementations work - a player who makes
  /// several fast moves early still draws down the same bank they'll
  /// need later in the game.
  int _parseTimeControl(String timeControl) {
    switch (timeControl) {
      case '3min':
        return 3 * 60 * 1000;
      case '5min':
        return 5 * 60 * 1000;
      case '10min':
        return 10 * 60 * 1000;
      case '1day':
        return 1 * 24 * 60 * 60 * 1000;
      case '3day':
        return 3 * 24 * 60 * 60 * 1000;
      case '7day':
        return 7 * 24 * 60 * 60 * 1000;
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
