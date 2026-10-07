import 'dart:math' show pow;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:chess/chess.dart' as chess_lib;
import '../models/game.dart';
import '../models/cpu_game_state.dart';
import '../services/chess_engine_service.dart';
import '../services/ai_opponent_engine.dart';
import '../services/stockfish_engine_service.dart';

/// CPU game state
class CPUGameState {
  CPUGameState({
    required this.gameId,
    required this.engine,
    required this.game,
    this.isThinking = false,
    this.error,
  });
  final String gameId;
  final ChessEngineService engine;
  final GameModel game;
  final bool isThinking;
  final String? error;

  CPUGameState copyWith({
    String? gameId,
    ChessEngineService? engine,
    GameModel? game,
    bool? isThinking,
    String? error,
  }) =>
      CPUGameState(
        gameId: gameId ?? this.gameId,
        engine: engine ?? this.engine,
        game: game ?? this.game,
        isThinking: isThinking ?? this.isThinking,
        error: error ?? this.error,
      );
}

/// CPU Game Service
class CPUGameService {
  CPUGameService(this._firestore);
  final FirebaseFirestore _firestore;

  /// Create a new CPU game
  Future<GameModel> createCPUGame({
    required String timeControl,
    required String difficulty, // 'easy', 'medium', 'hard'
  }) async {
    try {
      // Generate unique game ID
      final gameId = _firestore.collection('games').doc().id;

      // Parse time control
      final timeControlMs = _parseTimeControl(timeControl);

      // Determine user color (randomly)
      final isPlayerWhite = DateTime.now().millisecond % 2 == 0;

      final gameData = {
        'gameId': gameId,
        'type': 'cpu',
        'status': 'active',
        'difficulty': difficulty,
        'whitePlayerId': isPlayerWhite ? 'player' : 'cpu',
        'blackPlayerId': isPlayerWhite ? 'cpu' : 'player',
        'whitePlayerName': isPlayerWhite ? 'You' : 'Chess Engine',
        'blackPlayerName': isPlayerWhite ? 'Chess Engine' : 'You',
        'whiteRating': 1600,
        'blackRating': 1600,
        'currentFen':
            'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        'moves': [],
        'pgn': '',
        'timeControl': timeControl,
        'timeControlMs': timeControlMs,
        'whiteTimeRemainingMs': timeControlMs,
        'blackTimeRemainingMs': timeControlMs,
        'result': null,
        'resultReason': null,
        'createdAt': FieldValue.serverTimestamp(),
        'startedAt': FieldValue.serverTimestamp(),
        'endedAt': null,
      };

      // Save to Firestore
      await _firestore.collection('games').doc(gameId).set(gameData);

      return GameModel.fromJson({
        ...gameData,
        'createdAt': DateTime.now(),
        'startedAt': DateTime.now(),
      });
    } catch (e) {
      throw Exception('Failed to create CPU game: $e');
    }
  }

  /// Get CPU game by ID
  Future<GameModel?> getCPUGame(String gameId) async {
    try {
      final doc = await _firestore.collection('games').doc(gameId).get();

      if (doc.exists) {
        return GameModel.fromJson({
          ...doc.data()!,
          'gameId': doc.id,
        });
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get CPU game: $e');
    }
  }

  /// Make a move in CPU game
  Future<void> makePlayerMove({
    required String gameId,
    required String from,
    required String to,
    String? promotion,
  }) async {
    try {
      final gameDoc = await _firestore.collection('games').doc(gameId).get();

      if (!gameDoc.exists) throw Exception('Game not found');

      final gameData = gameDoc.data()!;
      final currentMoves =
          List<Map<String, dynamic>>.from(gameData['moves'] ?? []);

      // Create move record
      final moveRecord = {
        'from': from,
        'to': to,
        'promotion': promotion,
        'timestamp': FieldValue.serverTimestamp(),
        'playerId': 'player',
      };

      currentMoves.add(moveRecord);

      // Update game
      await _firestore.collection('games').doc(gameId).update({
        'moves': currentMoves,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to make move: $e');
    }
  }

  /// Make CPU move (auto-generated)
  Future<void> makeCPUMove({
    required String gameId,
    required ChessEngineService engine,
    required String difficulty,
  }) async {
    try {
      // Get best moves based on difficulty
      final bestMoves =
          engine.getBestMoves(depth: _getDifficultyDepth(difficulty));

      if (bestMoves.isEmpty) {
        // Game is over
        return;
      }

      // Select move based on difficulty
      final move = _selectMoveByDifficulty(bestMoves, difficulty);
      if (move == null) return;

      // Make the move
      engine.makeMove(move.fromAlgebraic, move.toAlgebraic,
          promotion: move.promotion?.toString());

      final gameDoc = await _firestore.collection('games').doc(gameId).get();

      if (!gameDoc.exists) throw Exception('Game not found');

      final gameData = gameDoc.data()!;
      final currentMoves =
          List<Map<String, dynamic>>.from(gameData['moves'] ?? []);

      // Create move record
      final moveRecord = {
        'from': move.fromAlgebraic,
        'to': move.toAlgebraic,
        'promotion': move.promotion?.toString(),
        'timestamp': FieldValue.serverTimestamp(),
        'playerId': 'cpu',
      };

      currentMoves.add(moveRecord);

      // Check game status
      String? result;
      String? resultReason;

      if (engine.isCheckmate()) {
        result = engine.isWhiteTurn() ? 'black_win' : 'white_win';
        resultReason = 'checkmate';
      } else if (engine.isStalemate()) {
        result = 'draw';
        resultReason = 'stalemate';
      }

      // Update game
      await _firestore.collection('games').doc(gameId).update({
        'moves': currentMoves,
        'currentFen': engine.getCurrentFen(),
        'result': result,
        'resultReason': resultReason,
        'status': result != null ? 'completed' : 'active',
        'endedAt': result != null ? FieldValue.serverTimestamp() : null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to make CPU move: $e');
    }
  }

  /// End CPU game with resignation
  Future<void> resignGame(String gameId) async {
    try {
      final gameDoc = await _firestore.collection('games').doc(gameId).get();

      if (!gameDoc.exists) throw Exception('Game not found');

      final gameData = gameDoc.data()!;

      // CPU wins by resignation
      await _firestore.collection('games').doc(gameId).update({
        'status': 'completed',
        'result': 'cpu_win',
        'resultReason': 'resignation',
        'endedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to resign game: $e');
    }
  }

  /// Helper: parse time control string to milliseconds
  int _parseTimeControl(String timeControl) {
    final value =
        int.tryParse(timeControl.replaceAll(RegExp(r'[^0-9]'), '')) ?? 5;

    if (timeControl.contains('h')) {
      return value * 60 * 60 * 1000;
    } else if (timeControl.contains('min')) {
      return value * 60 * 1000;
    } else if (timeControl.contains('s')) {
      return value * 1000;
    }

    return value * 60 * 1000;
  }

  /// Get search depth based on difficulty
  int _getDifficultyDepth(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return 1;
      case 'medium':
        return 2;
      case 'hard':
        return 3;
      default:
        return 2;
    }
  }

  /// Select move based on difficulty
  dynamic _selectMoveByDifficulty(List<dynamic> bestMoves, String difficulty) {
    if (bestMoves.isEmpty) return null;

    switch (difficulty.toLowerCase()) {
      case 'easy':
        // Pick random move from all available
        bestMoves.shuffle();
        return bestMoves.last;
      case 'medium':
        // Pick from top 50%
        final topHalf = (bestMoves.length / 2).ceil();
        bestMoves.shuffle();
        return bestMoves.sublist(0, topHalf).first;
      case 'hard':
        // Pick the best move
        return bestMoves.first;
      default:
        return bestMoves.first;
    }
  }
}

// Riverpod Providers
final cpuGameServiceProvider = Provider((ref) {
  final firestore = FirebaseFirestore.instance;
  return CPUGameService(firestore);
});

/// CPU game state provider
final cpuGameStateProvider =
    StateNotifierProvider.family<CPUGameStateNotifier, CPUGameState, String>(
        (ref, gameId) => CPUGameStateNotifier(gameId, ref));

/// CPU game state notifier
class CPUGameStateNotifier extends StateNotifier<CPUGameState> {
  CPUGameStateNotifier(this.gameId, this.ref)
      : super(CPUGameState(
          gameId: gameId,
          engine: ChessEngineService(),
          game: GameModel(
            gameId: gameId,
            type: 'cpu',
            status: 'active',
            whitePlayerId: '',
            blackPlayerId: '',
            whiteRating: 1600,
            blackRating: 1600,
            moves: [],
          ),
        ));
  final String gameId;
  final Ref ref;

  /// Make a player move
  Future<void> makeMove(String from, String to, {String? promotion}) async {
    try {
      state = state.copyWith(isThinking: true, error: null);

      final service = ref.read(cpuGameServiceProvider);
      final engine = state.engine;

      // Make player move
      final success = engine.makeMove(from, to, promotion: promotion);
      if (!success) {
        state = state.copyWith(
          isThinking: false,
          error: 'Invalid move',
        );
        return;
      }

      // Update game state
      await service.makePlayerMove(
        gameId: gameId,
        from: from,
        to: to,
        promotion: promotion,
      );

      // Check if game is over
      if (engine.isGameOver()) {
        final result = engine.getGameResult();
        state = state.copyWith(isThinking: false);
        return;
      }

      // Make CPU move
      await service.makeCPUMove(
        gameId: gameId,
        engine: engine,
        difficulty: 'medium',
      );

      state = state.copyWith(isThinking: false);
    } catch (e) {
      state = state.copyWith(
        isThinking: false,
        error: e.toString(),
      );
    }
  }

  /// Resign game
  Future<void> resign() async {
    try {
      final service = ref.read(cpuGameServiceProvider);
      await service.resignGame(gameId);
      state = state.copyWith(
        game: state.game.copyWith(status: 'completed'),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

/// Watch CPU game updates
final cpuGameStreamProvider =
    StreamProvider.family<GameModel?, String>((ref, gameId) {
  final firestore = FirebaseFirestore.instance;

  return firestore.collection('games').doc(gameId).snapshots().map((snapshot) {
    if (snapshot.exists) {
      return GameModel.fromJson({
        ...snapshot.data()!,
        'gameId': snapshot.id,
      });
    }
    return null;
  });
});

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

  /// Initialize a new game
  void initGame({
    AIDifficulty difficulty = AIDifficulty.medium,
    bool playerIsWhite = true,
  }) {
    _chess.initGame();
    _aiEngine = AIOpponentEngine(_chess, difficulty);

    state = CpuGameState(
      gameState: _chess.rawChess,
      difficulty: difficulty,
      moves: [],
      startTime: DateTime.now(),
      playerIsWhite: playerIsWhite,
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
    if (state.moves.isEmpty || state.isGameOver) return;

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

  /// Reset the game
  void reset() {
    _chess.reset();
    _aiEngine = AIOpponentEngine(_chess, state.difficulty);

    state = CpuGameState(
      gameState: _chess.rawChess,
      difficulty: state.difficulty,
      moves: [],
      startTime: DateTime.now(),
      playerIsWhite: state.playerIsWhite,
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
  bool _isGameOver() {
    if (_chess.isCheckmate()) return true;
    if (_chess.isStalemate()) return true;
    return false;
  }

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
  /// game, via a standard ELO update against the difficulty's virtual
  /// rating (the same scale as [AIDifficultyStockfishExt.stockfishElo]).
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
      final expectedScore =
          1 / (1 + pow(10, (opponentElo - currentRating) / 400));
      const kFactor = 32;
      final ratingDelta = (kFactor * (actualScore - expectedScore)).round();

      await userRef.update({
        'rating': FieldValue.increment(ratingDelta),
        'gamesPlayed': FieldValue.increment(1),
        if (playerResult == 'win') 'wins': FieldValue.increment(1),
        if (playerResult == 'loss') 'losses': FieldValue.increment(1),
        if (playerResult == 'draw') 'draws': FieldValue.increment(1),
      });
    } catch (_) {
      // Best-effort; don't block the UI on a stats-persistence failure.
    }
  }
}

/// Riverpod provider for CPU game state (local/offline play)
final cpuGameProvider = StateNotifierProvider<CpuGameNotifier, CpuGameState>(
    (ref) => CpuGameNotifier());
