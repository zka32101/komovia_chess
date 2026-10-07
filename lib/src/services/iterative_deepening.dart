/// Iterative Deepening for Chess AI
///
/// Implements iterative deepening search that progressively deepens until
/// a time limit is reached. This improves AI strength by using available
/// time more effectively than fixed-depth search.

import 'dart:async';
import 'package:chess/chess.dart' as chess_lib;
import 'chess_engine_service.dart';
import 'ai_opponent_engine.dart';

/// Result of iterative deepening search
class IterativeDeepeningResult {
  IterativeDeepeningResult({
    required this.bestMove,
    required this.score,
    required this.depthReached,
    required this.timeSpentMs,
    required this.nodesEvaluated,
    required this.timeLimit,
  });

  /// Best move found (in UCI notation)
  final String? bestMove;

  /// Score of best move (positive = better for white)
  final int score;

  /// Depth reached before time limit
  final int depthReached;

  /// Actual time spent searching (in milliseconds)
  final int timeSpentMs;

  /// Number of nodes evaluated
  final int nodesEvaluated;

  /// Whether search was interrupted by time limit
  final bool timeLimit;
}

/// Iterative Deepening Search Engine
class IterativeDeepeningEngine {
  IterativeDeepeningEngine(this.chess, this.difficulty) {
    _baseEngine = AIOpponentEngine(chess, difficulty);
  }
  final ChessEngineService chess;
  final AIDifficulty difficulty;
  late final AIOpponentEngine _baseEngine;

  // Search state
  bool _isSearching = false;
  late DateTime _searchStart;
  int _totalNodesEvaluated = 0;

  /// Get best move using iterative deepening
  /// Searches progressively deeper until timeLimit is reached
  Future<IterativeDeepeningResult> getBestMove({
    int? timeLimit,
  }) async {
    _isSearching = true;
    _searchStart = DateTime.now();
    _totalNodesEvaluated = 0;

    // Use difficulty's thinking time if not specified
    final timeLimitMs = timeLimit ?? difficulty.thinkingTimeMs;

    String? bestMove;
    int bestScore = chess.isWhiteTurn() ? -9999 : 9999;
    int depthReached = 1;
    bool hitTimeLimit = false;

    try {
      // Iteratively deepen the search
      for (int depth = 1; depth <= 10; depth++) {
        // Check if we've exceeded time limit
        final elapsedMs =
            DateTime.now().difference(_searchStart).inMilliseconds;
        if (elapsedMs > timeLimitMs && depth > 1) {
          hitTimeLimit = true;
          break;
        }

        // Search at this depth
        final result = _searchAtDepth(depth);

        if (result != null) {
          bestMove = result['move'] as String?;
          bestScore = result['score'] as int;
          depthReached = depth;

          // Check if move is clearly winning (can stop early)
          if (_isWinningPosition(bestScore)) {
            break;
          }
        }

        // Allow UI updates
        await Future.delayed(const Duration(milliseconds: 1));
      }
    } finally {
      _isSearching = false;
    }

    final elapsedMs = DateTime.now().difference(_searchStart).inMilliseconds;

    return IterativeDeepeningResult(
      bestMove: bestMove,
      score: bestScore,
      depthReached: depthReached,
      timeSpentMs: elapsedMs,
      nodesEvaluated: _totalNodesEvaluated,
      timeLimit: hitTimeLimit,
    );
  }

  /// Search the position at a specific depth
  /// Returns {move: String, score: int} or null if search fails
  Map<String, dynamic>? _searchAtDepth(int depth) {
    final legalMoves = chess.getLegalMoves();
    if (legalMoves.isEmpty) {
      return null;
    }

    // Single move: play it immediately
    if (legalMoves.length == 1) {
      return {
        'move': _moveToUCI(legalMoves.first),
        'score': 0,
      };
    }

    chess_lib.Move? bestMove;
    int bestScore = chess.isWhiteTurn() ? -9999 : 9999;

    // Try each move and evaluate to the specified depth
    for (final move in legalMoves) {
      chess.makeMove(move.fromAlgebraic, move.toAlgebraic,
          promotion: move.promotion?.name);

      final score = _minimax(
        depth - 1,
        -9999,
        9999,
        !chess.isWhiteTurn(),
      );

      chess.undoMove();

      // Update best move
      if (chess.isWhiteTurn()) {
        if (score > bestScore) {
          bestScore = score;
          bestMove = move;
        }
      } else {
        if (score < bestScore) {
          bestScore = score;
          bestMove = move;
        }
      }

      // Early exit if we've exceeded time limit significantly
      final elapsedMs = DateTime.now().difference(_searchStart).inMilliseconds;
      if (elapsedMs > (difficulty.thinkingTimeMs * 1.5)) {
        break;
      }
    }

    if (bestMove == null) return null;

    return {
      'move': _moveToUCI(bestMove),
      'score': bestScore,
    };
  }

  /// Minimax with alpha-beta pruning (simplified version)
  int _minimax(
    int depth,
    int alpha,
    int beta,
    bool isMaximizing,
  ) {
    _totalNodesEvaluated++;

    // Terminal conditions
    if (depth == 0) {
      return _evaluatePosition();
    }

    if (chess.isCheckmate()) {
      return isMaximizing ? -9000 + (4 - depth) : 9000 - (4 - depth);
    }

    if (chess.isStalemate()) {
      return 0;
    }

    final legalMoves = chess.getLegalMoves();
    if (legalMoves.isEmpty) {
      return chess.isCheck() ? (isMaximizing ? -9000 : 9000) : 0;
    }

    if (isMaximizing) {
      var maxEval = -9999;
      for (final move in legalMoves) {
        chess.makeMove(move.fromAlgebraic, move.toAlgebraic,
            promotion: move.promotion?.name);
        final eval = _minimax(depth - 1, alpha, beta, false);
        chess.undoMove();

        maxEval = maxEval > eval ? maxEval : eval;
        alpha = alpha > eval ? alpha : eval;
        if (beta <= alpha) break;
      }
      return maxEval;
    } else {
      var minEval = 9999;
      for (final move in legalMoves) {
        chess.makeMove(move.fromAlgebraic, move.toAlgebraic,
            promotion: move.promotion?.name);
        final eval = _minimax(depth - 1, alpha, beta, true);
        chess.undoMove();

        minEval = minEval < eval ? minEval : eval;
        beta = beta < eval ? beta : eval;
        if (beta <= alpha) break;
      }
      return minEval;
    }
  }

  /// Evaluate the current position
  int _evaluatePosition() {
    if (chess.isCheckmate()) {
      return chess.isWhiteTurn() ? -9000 : 9000;
    }

    if (chess.isStalemate()) {
      return 0;
    }

    // Material count
    int score = 0;
    const files = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
    for (final file in files) {
      for (var rank = 1; rank <= 8; rank++) {
        final piece = chess.getPieceAt('$file$rank');
        if (piece != null) {
          final value = _getPieceValue(piece.type);
          score += piece.color == chess_lib.Color.WHITE ? value : -value;
        }
      }
    }

    return score;
  }

  /// Get material value of a piece type
  int _getPieceValue(chess_lib.PieceType type) {
    // PieceType is a plain class with static const instances, not a real
    // Dart enum, so the analyzer can't prove this switch is exhaustive.
    switch (type) {
      case chess_lib.PieceType.PAWN:
        return 1;
      case chess_lib.PieceType.KNIGHT:
      case chess_lib.PieceType.BISHOP:
        return 3;
      case chess_lib.PieceType.ROOK:
        return 5;
      case chess_lib.PieceType.QUEEN:
        return 9;
      case chess_lib.PieceType.KING:
        return 0;
      default:
        throw ArgumentError('Unknown piece type: $type');
    }
  }

  /// Check if position is winning (can stop searching)
  bool _isWinningPosition(int score) {
    // Consider position winning if advantage > 3 pawns
    return score.abs() > 3;
  }

  /// Convert move to UCI notation
  String _moveToUCI(chess_lib.Move move) {
    String promotion = '';
    if (move.promotion != null) {
      promotion = move.promotion!.name;
    }
    return '${move.fromAlgebraic}${move.toAlgebraic}$promotion';
  }

  /// Get search statistics
  Map<String, dynamic> getSearchStats() => {
        'isSearching': _isSearching,
        'totalNodesEvaluated': _totalNodesEvaluated,
      };

  /// Cancel ongoing search
  void cancelSearch() {
    _isSearching = false;
  }
}
