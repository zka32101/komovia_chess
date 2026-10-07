import 'dart:math' show Random;
import 'package:chess/chess.dart' as chess_lib;
import 'chess_engine_service.dart';
import 'opening_book.dart';

/// Enumeration for AI difficulty levels
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
}

/// Material values for position evaluation
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

/// Position evaluator for chess positions
class PositionEvaluator {
  PositionEvaluator(this.chess, this.difficulty);
  final ChessEngineService chess;
  final AIDifficulty difficulty;

  /// Evaluate the current position
  /// Positive score = better for white, negative = better for black
  int evaluate() {
    // Check game-over conditions
    if (chess.isCheckmate()) {
      return chess.isWhiteTurn() ? -9999 : 9999;
    }

    if (chess.isStalemate()) {
      return 0;
    }

    int score = 0;

    // Material count (most important)
    score += _evaluateMaterial();

    // Positional factors (if not easy)
    if (difficulty != AIDifficulty.easy) {
      score += _evaluatePosition();
    }

    return score;
  }

  /// Evaluate material balance
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

  /// Evaluate positional factors (for Medium and Hard)
  int _evaluatePosition() {
    int score = 0;

    // Piece activity (simplified)
    score += _evaluatePieceActivity();

    // Pawn structure
    score += _evaluatePawnStructure();

    // Center control
    score += _evaluateCenterControl();

    // King safety
    score += _evaluateKingSafety();

    return score;
  }

  /// Evaluate piece activity and mobility
  int _evaluatePieceActivity() {
    int score = 0;
    final allMoves = chess.getLegalMoves();

    // More legal moves = better position (simplified evaluation)
    // Count moves for white (positive) and black (negative). Move.piece is
    // the PieceType that moved (no color); Move.color is the side to move.
    for (final move in allMoves) {
      if (move.color == chess_lib.Color.WHITE) {
        score += 1;
      } else {
        score -= 1;
      }
    }

    return (score / 10).round(); // Normalize
  }

  /// Evaluate pawn structure
  int _evaluatePawnStructure() {
    int score = 0;
    final board = chess.getBoard();

    // Simple pawn evaluation
    // Doubled pawns = bad, passed pawns = good
    for (int rank = 0; rank < 8; rank++) {
      for (int file = 0; file < 8; file++) {
        final piece = board[rank][file];
        if (piece?.type != chess_lib.PieceType.PAWN) continue;

        // Bonus for advanced pawns
        if (piece!.color == chess_lib.Color.WHITE && rank < 4) {
          score += 1;
        } else if (piece.color == chess_lib.Color.BLACK && rank > 3) {
          score -= 1;
        }
      }
    }

    return score;
  }

  /// Evaluate center control
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

  /// Evaluate king safety
  int _evaluateKingSafety() {
    int score = 0;

    // Simple heuristic: king in center = bad, king on side = good
    // This is a very simplified evaluation
    if (chess.isCheck()) {
      score = chess.isWhiteTurn() ? -2 : 2;
    }

    return score;
  }
}

/// AI opponent engine using minimax with alpha-beta pruning
class AIOpponentEngine {
  AIOpponentEngine(this.chess, this.difficulty) {
    _evaluator = PositionEvaluator(chess, difficulty);
  }
  final ChessEngineService chess;
  final AIDifficulty difficulty;
  late final PositionEvaluator _evaluator;

  // Transposition table for caching evaluated positions
  final Map<String, int> _transpositionTable = {};
  int _nodesEvaluated = 0;

  // Random number generator for opening book move selection
  final Random _random = Random();

  /// Get the best move for the current position
  /// Returns move in UCI notation (e.g., "e2e4")
  String? getBestMove() {
    _nodesEvaluated = 0;
    _transpositionTable.clear();

    final legalMoves = chess.getLegalMoves();
    if (legalMoves.isEmpty) {
      return null;
    }

    // If only one move available, play it
    if (legalMoves.length == 1) {
      return _moveToUCI(legalMoves.first);
    }

    // Check opening book for known good moves
    final bookMoves = OpeningBook.getRecommendedMoves(chess.getCurrentFen());
    if (bookMoves.isNotEmpty) {
      // Filter book moves to only legal moves
      final legalBookMoves = bookMoves
          .where((uciMove) => _isLegalMove(legalMoves, uciMove))
          .toList();

      if (legalBookMoves.isNotEmpty) {
        // Use the first (strongest) book move, with some randomness for variety
        if (difficulty == AIDifficulty.easy) {
          // Easy: pick randomly from first 3 moves (more variety)
          final moveIndex = _random
              .nextInt(legalBookMoves.length < 3 ? legalBookMoves.length : 3);
          return legalBookMoves[moveIndex];
        } else {
          // Medium/Hard: mostly play the best move, sometimes alternatives
          final shouldPlayBest = _random.nextDouble() > 0.1; // 90% best move
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

    chess_lib.Move? bestMove;
    int bestScore = chess.isWhiteTurn() ? -9999 : 9999;

    // Try each move and evaluate resulting position
    for (final move in _orderMoves(legalMoves)) {
      chess.makeMove(move.fromAlgebraic, move.toAlgebraic,
          promotion: move.promotion?.name);

      final score = _minimax(
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

  /// Check if a UCI move is legal
  bool _isLegalMove(List<chess_lib.Move> legalMoves, String uciMove) {
    for (final move in legalMoves) {
      if (_moveToUCI(move) == uciMove) {
        return true;
      }
    }
    return false;
  }

  /// Minimax algorithm with alpha-beta pruning
  int _minimax(
    int depth,
    int alpha,
    int beta,
    bool isWhiteToMove,
  ) {
    _nodesEvaluated++;

    // Check transposition table
    final fen = chess.getCurrentFen();
    if (_transpositionTable.containsKey(fen)) {
      return _transpositionTable[fen]!;
    }

    // Terminal node evaluation
    if (depth == 0) {
      final evaluation = _evaluator.evaluate();
      _transpositionTable[fen] = evaluation;
      return evaluation;
    }

    // Check for checkmate or stalemate
    if (chess.isGameOver()) {
      final evaluation = _evaluator.evaluate();
      _transpositionTable[fen] = evaluation;
      return evaluation;
    }

    final legalMoves = chess.getLegalMoves();

    if (isWhiteToMove) {
      // Maximizing player (white)
      int maxEval = -9999;

      for (final move in _orderMoves(legalMoves)) {
        chess.makeMove(move.fromAlgebraic, move.toAlgebraic,
            promotion: move.promotion?.name);

        final eval = _minimax(depth - 1, alpha, beta, false);

        chess.undoMove();

        maxEval = maxEval > eval ? maxEval : eval;
        alpha = alpha > eval ? alpha : eval;

        // Beta cutoff
        if (beta <= alpha) {
          break;
        }
      }

      _transpositionTable[fen] = maxEval;
      return maxEval;
    } else {
      // Minimizing player (black)
      int minEval = 9999;

      for (final move in _orderMoves(legalMoves)) {
        chess.makeMove(move.fromAlgebraic, move.toAlgebraic,
            promotion: move.promotion?.name);

        final eval = _minimax(depth - 1, alpha, beta, true);

        chess.undoMove();

        minEval = minEval < eval ? minEval : eval;
        beta = beta < eval ? beta : eval;

        // Alpha cutoff
        if (beta <= alpha) {
          break;
        }
      }

      _transpositionTable[fen] = minEval;
      return minEval;
    }
  }

  /// Order moves for better pruning
  /// Captures and checks are searched first
  List<chess_lib.Move> _orderMoves(List<chess_lib.Move> moves) {
    final scored = moves.map((move) {
      int score = 0;

      // Captures first (MVV/LVA ordering)
      if ((move.flags & chess_lib.Chess.BITS_CAPTURE) != 0) {
        score += 100;
      }

      // Checks second
      chess.makeMove(move.fromAlgebraic, move.toAlgebraic,
          promotion: move.promotion?.name);
      if (chess.isCheck()) {
        score += 50;
      }
      chess.undoMove();

      return MapEntry(move, score);
    }).toList();

    // Sort by score descending
    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.map((e) => e.key).toList();
  }

  /// Convert move to UCI notation
  String _moveToUCI(chess_lib.Move move) {
    String uci = move.fromAlgebraic + move.toAlgebraic;
    if (move.promotion != null) {
      uci += move.promotion!.name;
    }
    return uci;
  }

  /// Get debug info about the search
  Map<String, dynamic> getSearchStats() => {
        'nodesEvaluated': _nodesEvaluated,
        'depth': difficulty.searchDepth,
        'difficulty': difficulty.displayName,
      };

  /// Clear transposition table
  void clearCache() {
    _transpositionTable.clear();
  }
}
