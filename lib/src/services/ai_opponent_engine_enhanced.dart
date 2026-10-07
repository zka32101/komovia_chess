import 'dart:math' show Random;
import 'package:chess/chess.dart' as chess_lib;
import 'chess_engine_service.dart';
import 'zobrist_hashing.dart';
import 'countermove_heuristic.dart';
import 'heuristic_aging.dart';

/// Enumeration for AI difficulty levels (same as original)
enum AIDifficulty {
  easy,
  medium,
  hard,
}

/// Extension to get AI parameters based on difficulty
extension AIDifficultyExt on AIDifficulty {
  int get searchDepth {
    switch (this) {
      case AIDifficulty.easy:
        return 2;
      case AIDifficulty.medium:
        return 3;
      case AIDifficulty.hard:
        return 4;
    }
  }

  int get thinkingTimeMs {
    switch (this) {
      case AIDifficulty.easy:
        return 500;
      case AIDifficulty.medium:
        return 1500;
      case AIDifficulty.hard:
        return 3000;
    }
  }

  String get displayName {
    switch (this) {
      case AIDifficulty.easy:
        return 'Easy';
      case AIDifficulty.medium:
        return 'Medium';
      case AIDifficulty.hard:
        return 'Hard';
    }
  }

  String get description {
    switch (this) {
      case AIDifficulty.easy:
        return 'Perfect for beginners. AI plays basic moves.';
      case AIDifficulty.medium:
        return 'Good challenge. AI plays with strategy.';
      case AIDifficulty.hard:
        return 'Very challenging. AI plays strongly.';
    }
  }

  double get estimatedWinRate {
    switch (this) {
      case AIDifficulty.easy:
        return 0.35;
      case AIDifficulty.medium:
        return 0.55;
      case AIDifficulty.hard:
        return 0.65;
    }
  }

  int get difficultyIndex {
    switch (this) {
      case AIDifficulty.easy:
        return 0;
      case AIDifficulty.medium:
        return 1;
      case AIDifficulty.hard:
        return 2;
    }
  }
}

/// Material values for position evaluation (same as original)
class MaterialValues {
  static const Map<String, int> values = {
    'p': 1, // Pawn
    'n': 3, // Knight
    'b': 3, // Bishop
    'r': 5, // Rook
    'q': 9, // Queen
    'k': 0, // King (not included in material count)
  };

  static int getValueBySymbol(String? symbol) {
    if (symbol == null) return 0;
    return values[symbol.toLowerCase()] ?? 0;
  }

  static int getValueByType(chess_lib.PieceType? type) {
    if (type == null) return 0;
    return values[type.name] ?? 0;
  }
}

/// Position evaluator (same as original)
class PositionEvaluator {
  PositionEvaluator(this.chess, this.difficulty);
  final ChessEngineService chess;
  final AIDifficulty difficulty;

  /// Evaluate the current position
  int evaluate() {
    if (chess.isCheckmate()) {
      return chess.isWhiteTurn() ? -9999 : 9999;
    }

    if (chess.isStalemate()) {
      return 0;
    }

    int score = 0;
    score += _evaluateMaterial();

    if (difficulty != AIDifficulty.easy) {
      score += _evaluatePosition();
    }

    return score;
  }

  int _evaluateMaterial() {
    int score = 0;
    final board = chess.getBoard();

    for (int rank = 0; rank < 8; rank++) {
      for (int file = 0; file < 8; file++) {
        final piece = board[rank][file];
        if (piece == null) continue;

        final value = MaterialValues.getValueByType(piece.type);
        if (piece.color == chess_lib.Color.WHITE) {
          score += value;
        } else {
          score -= value;
        }
      }
    }

    return score;
  }

  int _evaluatePosition() {
    int score = 0;
    score += _evaluatePieceActivity();
    score += _evaluatePawnStructure();
    score += _evaluateCenterControl();
    score += _evaluateKingSafety();
    return score;
  }

  int _evaluatePieceActivity() {
    int score = 0;
    final allMoves = chess.getLegalMoves();

    // Move.piece is the PieceType that moved (no color); Move.color is the
    // side that made the move.
    for (final move in allMoves) {
      if (move.color == chess_lib.Color.WHITE) {
        score += 1;
      } else {
        score -= 1;
      }
    }

    return (score / 10).round();
  }

  int _evaluatePawnStructure() {
    int score = 0;
    final board = chess.getBoard();

    for (int rank = 0; rank < 8; rank++) {
      for (int file = 0; file < 8; file++) {
        final piece = board[rank][file];
        if (piece?.type != chess_lib.PieceType.PAWN) continue;

        if (piece!.color == chess_lib.Color.WHITE && rank < 4) {
          score += 1;
        } else if (piece.color == chess_lib.Color.BLACK && rank > 3) {
          score -= 1;
        }
      }
    }

    return score;
  }

  int _evaluateCenterControl() {
    int score = 0;
    final centerSquares = ['d4', 'd5', 'e4', 'e5'];
    final board = chess.getBoard();

    for (final square in centerSquares) {
      final indices = ChessEngineService.squareToIndices(square);
      final piece = board[indices['rank']!][indices['file']!];

      if (piece?.color == chess_lib.Color.WHITE) {
        score += 1;
      } else if (piece?.color == chess_lib.Color.BLACK) {
        score -= 1;
      }
    }

    return score;
  }

  int _evaluateKingSafety() {
    int score = 0;

    if (chess.isCheck()) {
      score = chess.isWhiteTurn() ? -2 : 2;
    }

    return score;
  }
}

/// Enhanced AI opponent engine with all Phase III.1 optimizations
class AIOpponentEngineEnhanced {
  AIOpponentEngineEnhanced(this.chess, this.difficulty) {
    _evaluator = PositionEvaluator(chess, difficulty);

    // Initialize Phase III.1 components
    _killerMoves = AgedKillerMoveHeuristic(
      maxDepth: 12,
      decayFactor: 0.95,
      maxAge: 10,
    );

    _countermoves = AgedCountermoveHeuristic(
      decayFactor: 0.90,
      maxAge: 15,
    );

    _adaptiveManager = AdaptiveHeuristicManager(
      killerMoves: _killerMoves,
      countermoves: _countermoves,
    );

    _zobristTable = ZobristTranspositionTable(maxSize: 100000);
    _moveOrderer = AdvancedMoveOrderer(countermoves: _countermoves);

    // Set difficulty in adaptive manager
    _adaptiveManager.setDifficulty(difficulty.difficultyIndex);

    // Initialize Zobrist hashing
    ZobristHash.initialize();
  }
  final ChessEngineService chess;
  final AIDifficulty difficulty;
  late final PositionEvaluator _evaluator;

  // Phase III.1 Optimizations
  late final AgedKillerMoveHeuristic _killerMoves;
  late final AgedCountermoveHeuristic _countermoves;
  late final AdaptiveHeuristicManager _adaptiveManager;
  late final ZobristTranspositionTable _zobristTable;
  late final AdvancedMoveOrderer _moveOrderer;

  // Statistics
  int _nodesEvaluated = 0;
  int _zobristHits = 0;
  int _zobristMisses = 0;
  String? _lastOpponentMove;

  // Random for opening book variation
  final Random _random = Random();

  /// Get the best move for the current position (enhanced version)
  String? getBestMove() {
    _nodesEvaluated = 0;
    _zobristHits = 0;
    _zobristMisses = 0;

    final legalMoves = chess.getLegalMoves();
    if (legalMoves.isEmpty) {
      return null;
    }

    if (legalMoves.length == 1) {
      return _moveToUCI(legalMoves.first);
    }

    // Try extended opening book first (40+ positions)
    final bookMoves =
        ExtendedOpeningBook.getRecommendedMoves(chess.getCurrentFen());
    if (bookMoves.isNotEmpty) {
      final legalBookMoves = bookMoves
          .where((uciMove) => _isLegalMove(legalMoves, uciMove))
          .toList();

      if (legalBookMoves.isNotEmpty) {
        if (difficulty == AIDifficulty.easy) {
          final moveIndex = _random
              .nextInt(legalBookMoves.length < 3 ? legalBookMoves.length : 3);
          return legalBookMoves[moveIndex];
        } else {
          final shouldPlayBest = _random.nextDouble() > 0.1;
          if (shouldPlayBest && legalBookMoves.length > 1) {
            return legalBookMoves[0];
          } else if (legalBookMoves.length > 1) {
            return legalBookMoves[
                _random.nextInt(legalBookMoves.length - 1) + 1];
          } else {
            return legalBookMoves[0];
          }
        }
      }
    }

    // Set time remaining for adaptive manager
    _adaptiveManager.setTimeRemaining(difficulty.thinkingTimeMs);

    chess_lib.Move? bestMove;
    int bestScore = chess.isWhiteTurn() ? -9999 : 9999;

    // Order moves using enhanced heuristics
    final orderedMoves = _orderMovesEnhanced(legalMoves);

    for (final move in orderedMoves) {
      chess.makeMove(move.fromAlgebraic, move.toAlgebraic,
          promotion: move.promotion?.name);

      final score = _minimaxEnhanced(
        difficulty.searchDepth - 1,
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
    }

    return bestMove != null ? _moveToUCI(bestMove) : null;
  }

  /// Enhanced minimax with Zobrist hashing and killer moves
  int _minimaxEnhanced(
    int depth,
    int alpha,
    int beta,
    bool isMaximizing,
  ) {
    _nodesEvaluated++;

    // Zobrist hash lookup
    final hash = ZobristHash.hashPosition(chess.rawChess);
    final ttEntry = _zobristTable.lookup(hash);

    if (ttEntry != null && ttEntry.depth >= depth) {
      _zobristHits++;
      return ttEntry.score;
    }

    _zobristMisses++;

    // Terminal node
    if (depth == 0) {
      final evaluation = _evaluator.evaluate();
      _zobristTable.store(hash, evaluation, depth, 0); // 0 = exact
      return evaluation;
    }

    // Game over check
    if (chess.isGameOver()) {
      final evaluation = _evaluator.evaluate();
      _zobristTable.store(hash, evaluation, depth, 0);
      return evaluation;
    }

    final legalMoves = chess.getLegalMoves();
    if (legalMoves.isEmpty) {
      final evaluation = _evaluator.evaluate();
      _zobristTable.store(hash, evaluation, depth, 0);
      return evaluation;
    }

    // Order moves using enhanced heuristics
    final orderedMoves = _orderMovesEnhanced(legalMoves);

    if (isMaximizing) {
      int maxEval = -9999;

      for (final move in orderedMoves) {
        final moveUci = _moveToUCI(move);

        chess.makeMove(move.fromAlgebraic, move.toAlgebraic,
            promotion: move.promotion?.name);

        final eval = _minimaxEnhanced(depth - 1, alpha, beta, false);

        chess.undoMove();

        if (eval > maxEval) {
          maxEval = eval;
          // Record successful move for aging
          if (depth > 0) {
            _moveOrderer.recordHistory(moveUci, (depth + 1) * 10);
          }
        }

        alpha = alpha > eval ? alpha : eval;

        // Beta cutoff - record killer and countermove
        if (beta <= alpha) {
          if (depth > 0) {
            _killerMoves.recordKiller(depth, moveUci);
            if (_lastOpponentMove != null) {
              _countermoves.recordCountermove(_lastOpponentMove!, moveUci);
            }
          }
          break;
        }
      }

      _zobristTable.store(hash, maxEval, depth, 0);
      return maxEval;
    } else {
      int minEval = 9999;

      for (final move in orderedMoves) {
        final moveUci = _moveToUCI(move);
        _lastOpponentMove = moveUci;

        chess.makeMove(move.fromAlgebraic, move.toAlgebraic,
            promotion: move.promotion?.name);

        final eval = _minimaxEnhanced(depth - 1, alpha, beta, true);

        chess.undoMove();

        if (eval < minEval) {
          minEval = eval;
        }

        beta = beta < eval ? beta : eval;

        // Alpha cutoff
        if (beta <= alpha) {
          break;
        }
      }

      _zobristTable.store(hash, minEval, depth, 0);
      return minEval;
    }
  }

  /// Enhanced move ordering using all Phase III.1 heuristics
  List<chess_lib.Move> _orderMovesEnhanced(List<chess_lib.Move> moves) {
    // Periodic aging update
    if (_nodesEvaluated % 100 == 0) {
      _adaptiveManager.updateAges();
    }

    // Convert to scored moves
    final scored = moves.map((move) {
      int score = 0;
      final moveUci = _moveToUCI(move);

      // 1. Captures (highest priority)
      if ((move.flags & chess_lib.Chess.BITS_CAPTURE) != 0) {
        score += 10000;
      }

      // 2. Checks (high priority)
      chess.makeMove(move.fromAlgebraic, move.toAlgebraic,
          promotion: move.promotion?.name);
      if (chess.isCheck()) {
        score += 5000;
      }
      chess.undoMove();

      // 3. Aged countermoves (position-aware)
      if (_lastOpponentMove != null) {
        final agedCounters =
            _countermoves.getAgedCountermoves(_lastOpponentMove!);
        if (agedCounters.contains(moveUci)) {
          score += 3000;
          final priority =
              _countermoves.getCountermovePriority(_lastOpponentMove!, moveUci);
          score += (4 - priority) * 100; // Prioritize by order
        }
      }

      // 4. Aged killer moves (depth-specific)
      // Note: In root node, we don't have depth info, so skip here
      // This is only applied in minimax recursion

      // 5. History heuristic (lowest priority)
      // Would track move success rate

      return MapEntry(move, score);
    }).toList();

    // Sort by score descending
    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.map((e) => e.key).toList();
  }

  /// Check if a UCI move is legal
  bool _isLegalMove(List<chess_lib.Move> legalMoves, String uciMove) {
    for (final move in legalMoves) {
      if (_moveToUCI(move) == uciMove) {
        return true;
      }
    }
    return false;
  }

  /// Convert move to UCI notation
  String _moveToUCI(chess_lib.Move move) {
    String uci = move.fromAlgebraic + move.toAlgebraic;
    if (move.promotion != null) {
      uci += move.promotion!.name;
    }
    return uci;
  }

  /// Get comprehensive search statistics
  Map<String, dynamic> getSearchStats() => {
        'nodesEvaluated': _nodesEvaluated,
        'depth': difficulty.searchDepth,
        'difficulty': difficulty.displayName,
        'zobristHits': _zobristHits,
        'zobristMisses': _zobristMisses,
        'zobristHitRate': _zobristMisses + _zobristHits > 0
            ? (_zobristHits / (_zobristHits + _zobristMisses) * 100)
                .toStringAsFixed(1)
            : '0.0',
        'adaptiveSettings': _adaptiveManager.getAdaptiveStatistics(),
        'killerStats': _killerMoves.getStatistics(),
        'countermoveStats': _countermoves.getStatistics(),
      };

  /// Clear all caches and tables
  void clearCache() {
    _zobristTable.clear();
    _adaptiveManager.clear();
    _nodesEvaluated = 0;
    _zobristHits = 0;
    _zobristMisses = 0;
  }

  /// Get Zobrist table statistics
  Map<String, dynamic> getTableStats() => _zobristTable.getStatistics();
}
