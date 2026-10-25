import 'dart:async' show unawaited;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:chess/chess.dart' as chess_lib;
import '../models/cpu_game_state.dart';
import '../services/chess_engine_service.dart';
import '../services/ai_opponent_engine.dart';
import '../services/stockfish_engine_service.dart';
import '../services/season_challenge_service.dart';
import '../services/season_management_service.dart';
import '../services/seasonal_event_service.dart';
import '../services/battle_pass_service.dart';
import '../services/achievement_service.dart';
import '../services/match_history_service.dart';
import '../services/analytics_dashboard_service_impl.dart';
import '../services/rating_calculation_service.dart';
import '../models/match_record.dart';


// ============================================================================
// NEW: Simple State-Based CPU Game Provider (for offline play)
// ============================================================================

/// Game state notifier for CPU play (local state)
class CpuGameNotifier extends StateNotifier<CpuGameState> {
  CpuGameNotifier()
      : super(
          CpuGameState(
            gameState: chess_lib.Chess(),
            difficulty: AIDifficulty.medium,
            startTime: DateTime.now(),
            playerIsWhite: true,
          ),
        ) {
    _chess = ChessEngineService();
    _aiEngine = AIOpponentEngine(_chess, state.difficulty);
  }
  late ChessEngineService _chess;
  late AIOpponentEngine _aiEngine;

  /// Initialize a new game.
  ///
  /// [startingFen], when given, begins the game from that position
  /// instead of the standard starting array - e.g. a curated midgame/
  /// endgame practice position (see CPUGameSelectionScreen). Move
  /// generation, check/checkmate/stalemate detection, undo, and the
  /// end-of-game rating/match-history recording in [_recordResult] all
  /// already operate purely on the current `chess_lib.Chess` position
  /// with no assumption about how the game began, so no other change is
  /// needed to support this.
  void initGame({
    AIDifficulty difficulty = AIDifficulty.medium,
    bool playerIsWhite = true,
    String? startingFen,
  }) {
    _chess.initGame(fen: startingFen);
    _aiEngine = AIOpponentEngine(_chess, difficulty);
    // cpuGameProvider has no autoDispose, so this notifier (and
    // _stockfishFailed) persists for the whole app session, not just
    // one game - without resetting it here, a single transient
    // Stockfish error (e.g. a one-off init race) would permanently
    // downgrade every future CPU game this session to the much weaker
    // pure-Dart fallback engine, regardless of difficulty, forever.
    // Starting a fresh game is the natural point to give Stockfish
    // another chance.
    _stockfishFailed = false;

    state = CpuGameState(
      gameState: _chess.rawChess,
      difficulty: difficulty,
      moves: [],
      startTime: DateTime.now(),
      playerIsWhite: playerIsWhite,
      startingFen: startingFen,
    );
  }

  /// Make a player move
  void makePlayerMove(String from, String to, {String? promotion}) {
    if (!state.isPlayerTurn || state.isGameOver) return;

    final success = _chess.makeMove(from, to, promotion: promotion);
    if (!success) return;

    final newMoves = List<chess_lib.Move>.from(state.moves);
    final allMoves = _chess.getLegalMoves();
    if (allMoves.isNotEmpty) {
      // Get the last move from legal moves (the one we just made)
      final lastMove = allMoves
          .where((m) => m.fromAlgebraic == from && m.toAlgebraic == to)
          .firstOrNull;
      if (lastMove != null) {
        newMoves.add(lastMove);
      }
    }

    _updateGameState(newMoves);

    // Check if game is over after player move
    if (_isGameOver()) {
      _endGame();
    }
  }

  bool _stockfishFailed = false;

  /// Request AI to make a move
  Future<void> makeAIMove() async {
    if (state.isPlayerTurn || state.isGameOver || state.isAIThinking) return;

    state = state.copyWith(isAIThinking: true);

    // Prefer the native Stockfish engine: it's far stronger and runs off
    // the UI thread (no jank), falling back to the built-in minimax engine
    // if Stockfish isn't available on this platform (e.g. web) or errors.
    String? bestMove;
    if (!_stockfishFailed) {
      try {
        final stockfish = StockfishEngineService.instance;
        await stockfish.configureDifficulty(state.difficulty);
        bestMove = await stockfish.getBestMove(
          _chess.getCurrentFen(),
          moveTimeMs: state.difficulty.stockfishMoveTimeMs,
        );
      } catch (e) {
        _stockfishFailed = true;
        bestMove = null;
      }
    }

    // Fallback: hand-rolled minimax/alpha-beta engine.
    bestMove ??= _aiEngine.getBestMove();

    if (bestMove == null) {
      _endGame();
      state = state.copyWith(isAIThinking: false);
      return;
    }

    // Apply the move
    _chess.makeMoveUCI(bestMove);
    final newMoves = List<chess_lib.Move>.from(state.moves);
    final allMoves = _chess.getLegalMoves();
    if (allMoves.isNotEmpty) {
      // Find the move we just made
      final parts = bestMove.split('');
      if (parts.length >= 4) {
        final from = bestMove.substring(0, 2);
        final to = bestMove.substring(2, 4);
        final lastMove = allMoves
            .where((m) => m.fromAlgebraic == from && m.toAlgebraic == to)
            .firstOrNull;
        if (lastMove != null) {
          newMoves.add(lastMove);
        }
      }
    }

    _updateGameState(newMoves);
    state = state.copyWith(isAIThinking: false);

    // Check if game is over after AI move
    if (_isGameOver()) {
      _endGame();
    }
  }

  /// Undo the last move
  void undoMove() {
    // Also refuses while the AI's move is still in flight - without
    // this, undoing mid-think reverts _chess's position out from under
    // makeAIMove()'s pending async engine call, which later resolves
    // and plays its (now-stale) best move against the reverted
    // position, desyncing state.moves from _chess's actual position.
    if (state.moves.isEmpty || state.isGameOver || state.isAIThinking) {
      return;
    }

    _chess.undoMove();
    if (state.moves.isNotEmpty) {
      _chess.undoMove(); // Undo both player and AI move
    }

    final newMoves = state.moves.length >= 2
        ? state.moves.sublist(0, state.moves.length - 2)
        : <chess_lib.Move>[];

    _updateGameState(newMoves);
  }

  /// Resign the game
  void resign() {
    if (state.isGameOver) return;

    final result = state.playerIsWhite ? 'black_win' : 'white_win';
    state = state.copyWith(
      isGameOver: true,
      result: result,
      endReason: 'resignation',
      endTime: DateTime.now(),
    );
    _recordResult('loss');
  }

  /// Offer a draw (simplified - auto-accept)
  void offerDraw() {
    if (state.isGameOver) return;

    state = state.copyWith(
      isGameOver: true,
      result: 'draw',
      endReason: 'draw_agreement',
      endTime: DateTime.now(),
    );
    _recordResult('draw');
  }

  /// Reset the game - back to [CpuGameState.startingFen] when the current
  /// game began from a custom practice position, otherwise the standard
  /// starting array.
  void reset() {
    if (state.startingFen != null) {
      _chess.loadFromFen(state.startingFen!);
    } else {
      _chess.reset();
    }
    _aiEngine = AIOpponentEngine(_chess, state.difficulty);

    state = CpuGameState(
      gameState: _chess.rawChess,
      difficulty: state.difficulty,
      moves: [],
      startTime: DateTime.now(),
      playerIsWhite: state.playerIsWhite,
      startingFen: state.startingFen,
    );
  }

  /// Helper: Update game state after a move
  void _updateGameState(List<chess_lib.Move> newMoves) {
    state = state.copyWith(
      gameState: _chess.rawChess,
      moves: newMoves,
    );
  }

  /// Helper: Check if game is over
  ///
  /// Previously only checked checkmate/stalemate, reimplementing a
  /// narrower subset of what ChessEngineService.isGameOver() already
  /// covers - a CPU game reaching a draw by insufficient material,
  /// threefold repetition, or the 50-move rule (e.g. bare kings after
  /// trading down) never actually ended: no result dialog, no history
  /// recorded, with no legal path to end the game short of a checkmate/
  /// stalemate that may never occur with insufficient material on the
  /// board at all.
  bool _isGameOver() => _chess.isGameOver();

  /// Helper: End the game and determine result
  void _endGame() {
    String? result;
    String? endReason;

    if (_chess.isCheckmate()) {
      endReason = 'checkmate';
      result = _chess.isWhiteTurn() ? 'black_win' : 'white_win';
    } else if (_chess.isStalemate()) {
      endReason = 'stalemate';
      result = 'draw';
    } else {
      // Any other isGameOver() case is one of the draw reasons
      // ChessEngineService.getDrawReasons()/DrawDetectionService already
      // distinguish (insufficient material / threefold repetition /
      // fifty-move rule) - the first one reported is used as the
      // specific endReason so GameResult can show the real cause rather
      // than a generic "Draw".
      final drawReasons = _chess.getDrawReasons();
      endReason =
          drawReasons.isNotEmpty ? drawReasons.first : 'insufficient_material';
      result = 'draw';
    }

    state = state.copyWith(
      isGameOver: true,
      result: result,
      endReason: endReason,
      endTime: DateTime.now(),
    );

    if (result != null) {
      final playerWon = (result == 'white_win') == state.playerIsWhite;
      _recordResult(result == 'draw' ? 'draw' : (playerWon ? 'win' : 'loss'));
    }
  }

  /// Updates the signed-in user's rating/win-loss-draw stats after a CPU
  /// game, via [RatingCalculationService] against the difficulty's virtual
  /// rating (the same scale as [AIDifficultyStockfishExt.stockfishElo]) -
  /// the same tiered-K-factor Elo engine online_game_service.dart uses for
  /// PvP games, rather than a separately hand-inlined flat-K=32 formula
  /// this method previously had (so a CPU-only player and a PvP-only
  /// player's rating moved by inconsistent amounts for an equally
  /// surprising win/loss, even though both write the same `rating` field).
  /// Best-effort: CPU games aren't otherwise persisted anywhere, so a
  /// failure here is swallowed rather than surfaced to the player.
  Future<void> _recordResult(String playerResult) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(
            user.uid,
          );
      final userDoc = await userRef.get();
      final currentRating =
          (userDoc.data()?['rating'] as num?)?.toInt() ?? 1500;

      final actualScore = switch (playerResult) {
        'win' => 1.0,
        'draw' => 0.5,
        _ => 0.0,
      };
      final opponentElo = state.difficulty.stockfishElo;
      final newRating = RatingCalculationService.calculateNewRating(
        currentRating.clamp(
          RatingCalculationService.minRating,
          RatingCalculationService.maxRating,
        ),
        opponentElo.clamp(
          RatingCalculationService.minRating,
          RatingCalculationService.maxRating,
        ),
        actualScore,
      );
      final ratingDelta = newRating - currentRating;

      await userRef.update({
        'rating': FieldValue.increment(ratingDelta),
        'gamesPlayed': FieldValue.increment(1),
        if (playerResult == 'win') 'wins': FieldValue.increment(1),
        if (playerResult == 'loss') 'losses': FieldValue.increment(1),
        if (playerResult == 'draw') 'draws': FieldValue.increment(1),
      });

      // AnalyticsDashboardService.getPlayerDashboard caches its result
      // for up to an hour, with no caller anywhere in the app ever
      // invalidating it after a real game - AnalyticsDashboardScreen kept
      // showing pre-game Win Rate/Streak/Trend numbers until that TTL
      // happened to expire. Clearing it here means the dashboard's own
      // provider.family just needs re-invalidating (its AppBar refresh
      // button does this) to see fresh numbers immediately after a game.
      AnalyticsDashboardService().invalidatePlayerAnalytics(user.uid);

      // Best-effort: record this match for Match History / comparison -
      // previously nothing anywhere ever called MatchHistoryService.
      // recordMatch, so those screens always showed an empty history
      // regardless of games played. Uses the rating/wins/etc. already
      // just incremented above rather than a second increment (which
      // recordMatch used to also do internally - see its own doc
      // comment on why that would have double-counted every game).
      unawaited(MatchHistoryService().recordMatch(
        MatchRecord(
          matchId: '${user.uid}_${DateTime.now().millisecondsSinceEpoch}',
          playerId: user.uid,
          opponentId: 'cpu_${state.difficulty.name}',
          opponentName: state.difficulty.displayName,
          playerRatingBefore: currentRating,
          playerRatingAfter: currentRating + ratingDelta,
          opponentRatingBefore: opponentElo,
          opponentRatingAfter: opponentElo,
          result: playerResult,
          timeControl: 'unrated',
          playedAt: DateTime.now(),
        ),
        // OpeningExplorerService replays a match's recorded `movesUci`
        // against the STANDARD starting position to build per-position
        // statistics - a game that began from a custom midgame/endgame
        // practice position (state.startingFen != null) has a move list
        // that is meaningless, or even illegal, from move 1 of a normal
        // game, and would corrupt that replay. Recording the match's
        // rating/win-loss-draw/match-history entry itself is unaffected
        // either way - only the move list is withheld here.
        moves: state.startingFen != null
            ? null
            : state.moves
                .map((m) => {
                      'from': m.fromAlgebraic,
                      'to': m.toAlgebraic,
                      'promotion': m.promotion?.name,
                    })
                .toList(),
      ));

      // Best-effort: advance any active seasonal challenge tracking wins/
      // draws/games-played - previously nothing in the app ever called
      // into SeasonChallengeService from a real game ending, so no
      // seasonal challenge could progress through actual play.
      final season = await SeasonManagementService().getCurrentSeason();
      if (season != null) {
        final challengeService = SeasonChallengeService();
        await challengeService.recordMetricProgress(
          playerId: user.uid,
          seasonId: season.seasonId,
          metric: GameplayMetric.playGames,
        );
        if (playerResult == 'win') {
          await challengeService.recordMetricProgress(
            playerId: user.uid,
            seasonId: season.seasonId,
            metric: GameplayMetric.winGames,
          );
        } else if (playerResult == 'draw') {
          await challengeService.recordMetricProgress(
            playerId: user.uid,
            seasonId: season.seasonId,
            metric: GameplayMetric.drawGames,
          );
        }

        // Best-effort: BattlePassService.addBattlePassExperience was
        // fully built (transaction, level-up loop, reward-claim UI
        // already wired on the seasonal hub) but nothing anywhere ever
        // called it - every player's battle pass level was permanently
        // stuck at 1 regardless of how much they played.
        try {
          await BattlePassService().addBattlePassExperience(
            playerId: user.uid,
            seasonId: season.seasonId,
            experienceAmount: playerResult == 'win' ? 50 : 20,
          );
        } catch (e) {
          debugPrint('Error awarding battle pass experience: $e');
        }

        // Best-effort: same dead-wiring gap - SeasonalEventService.
        // updateEventScore was never called from anywhere, so every
        // seasonal event's leaderboard/rank-gated rewards stayed frozen
        // at currentScore: 0 for every participant regardless of play.
        try {
          await SeasonalEventService().recordEventScoreProgress(
            playerId: user.uid,
            seasonId: season.seasonId,
            scoreIncrease: playerResult == 'win' ? 20 : 5,
          );
        } catch (e) {
          debugPrint('Error recording event score progress: $e');
        }
      }

      // Best-effort: a win may have just satisfied an achievement
      // (first_win/five_wins) - this was previously only wired up for
      // online PvP wins (see OnlineGameService._endGameWithResult), so a
      // player who only ever played CPU games could never unlock either
      // one despite their `wins` field incrementing correctly above.
      if (playerResult == 'win') {
        unawaited(AchievementService().checkAndUnlockAchievements(user.uid));
      }
    } catch (_) {
      // Best-effort; don't block the UI on a stats-persistence failure.
    }
  }
}

/// Riverpod provider for CPU game state (local/offline play)
final cpuGameProvider = StateNotifierProvider<CpuGameNotifier, CpuGameState>(
    (ref) => CpuGameNotifier());
