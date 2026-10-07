/// Killer Move Heuristic for Chess AI
///
/// Tracks moves that cause beta cutoffs (killer moves) during search.
/// These moves can be highly effective in similar positions at the same depth,
/// allowing better move ordering and improved alpha-beta pruning efficiency.

import 'package:chess/chess.dart' as chess_lib;

/// Killer Move Heuristic Table
///
/// Stores killer moves (moves that cause cutoffs) for each depth.
/// Two killer moves are tracked per depth level (best and second-best).
class KillerMoveHeuristic {
  KillerMoveHeuristic({int maxDepth = 12}) : _maxDepth = maxDepth {
    _killerMoves = List.generate(
      maxDepth,
      (i) => [null, null],
    );
  }

  /// Maximum search depth to track (typical: 10-20)
  final int _maxDepth;

  /// Killer moves table: [depth][killer_index (0-1)]
  /// Each depth stores up to 2 killer moves
  late final List<List<String?>> _killerMoves;

  /// Move ordering scores (how many times moved caused cutoff)
  final Map<String, int> _moveScores = {};

  /// Statistics
  int _totalCutoffs = 0;
  int _killerMovesCutoffs = 0;

  /// Record a killer move (move that caused a beta cutoff)
  void recordKiller(int depth, String moveUci) {
    if (depth >= _maxDepth || depth < 0) return;

    // Don't record captures or checks as killers (they're handled separately)
    // Only quiet moves benefit from killer heuristic

    final killers = _killerMoves[depth];

    // If this move is already the primary killer, no need to update
    if (killers[0] == moveUci) {
      _incrementScore(moveUci);
      return;
    }

    // Shift secondary killer to depth+1 (or discard)
    if (depth + 1 < _maxDepth) {
      if (killers[1] != null && killers[0] != null) {
        _killerMoves[depth + 1][1] = _killerMoves[depth + 1][0];
      }
    }

    // Move primary killer to secondary
    if (killers[0] != null) {
      killers[1] = killers[0];
    }

    // Set new primary killer
    killers[0] = moveUci;

    _incrementScore(moveUci);
    _totalCutoffs++;
  }

  /// Get killer moves for a specific depth (ordered by strength)
  List<String> getKillers(int depth) {
    if (depth >= _maxDepth || depth < 0) return [];

    final killers = _killerMoves[depth];
    return killers.whereType<String>().toList();
  }

  /// Check if a move is a killer move at this depth
  bool isKiller(int depth, String moveUci) {
    if (depth >= _maxDepth || depth < 0) return false;
    final killers = _killerMoves[depth];
    return killers.contains(moveUci);
  }

  /// Get priority/score for move ordering
  /// Higher score = should be tried earlier
  int getMoveScore(String moveUci) => _moveScores[moveUci] ?? 0;

  /// Clear all killer move history (useful for new search)
  void clear() {
    for (int i = 0; i < _maxDepth; i++) {
      _killerMoves[i][0] = null;
      _killerMoves[i][1] = null;
    }
    _moveScores.clear();
    _totalCutoffs = 0;
    _killerMovesCutoffs = 0;
  }

  /// Clear killer moves for a specific depth range
  void clearDepthRange(int startDepth, int endDepth) {
    for (int i = startDepth; i <= endDepth && i < _maxDepth; i++) {
      _killerMoves[i][0] = null;
      _killerMoves[i][1] = null;
    }
  }

  /// Increment score for a killer move
  void _incrementScore(String moveUci) {
    _moveScores[moveUci] = (_moveScores[moveUci] ?? 0) + 1;
    _killerMovesCutoffs++;
  }

  /// Get statistics about killer moves
  Map<String, dynamic> getStatistics() => {
        'totalCutoffs': _totalCutoffs,
        'killerCutoffs': _killerMovesCutoffs,
        'cutoffRate': _totalCutoffs > 0
            ? (_killerMovesCutoffs / _totalCutoffs * 100)
            : 0.0,
        'uniqueKillers': _moveScores.length,
        'topKiller':
            _moveScores.isEmpty ? null : _getTopMoves(1).firstOrNull?['move'],
        'topKillers': _getTopMoves(5),
      };

  /// Get top killer moves by score
  List<Map<String, dynamic>> _getTopMoves(int count) {
    final entries = _moveScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return entries
        .take(count)
        .map((e) => {
              'move': e.key,
              'score': e.value,
            })
        .toList();
  }
}

/// Move Ordering Manager
///
/// Combines multiple heuristics for optimal move ordering:
/// 1. Captures (MVV/LVA)
/// 2. Checks
/// 3. Killer moves
/// 4. History heuristic (move frequency)
class MoveOrderingManager {
  MoveOrderingManager({KillerMoveHeuristic? killerMoves})
      : killerMoves = killerMoves ?? KillerMoveHeuristic();
  final KillerMoveHeuristic killerMoves;
  final Map<String, int> _moveHistory = {};

  /// Order moves for better search efficiency
  /// Returns moves sorted by estimated strength (captures first, then killers, etc.)
  List<chess_lib.Move> orderMoves(
    List<chess_lib.Move> moves,
    chess_lib.Chess chess, {
    int depth = 0,
  }) {
    // Create list of (move, score) pairs
    final scoredMoves = moves.map((move) {
      final score = _scoreMoveForOrdering(move, chess, depth);
      return (move, score);
    }).toList();

    // Sort by score (descending - higher scores first)
    scoredMoves.sort((a, b) => b.$2.compareTo(a.$2));

    return scoredMoves.map((p) => p.$1).toList();
  }

  /// Score a move for move ordering heuristic
  /// Higher score = try this move earlier
  int _scoreMoveForOrdering(
    chess_lib.Move move,
    chess_lib.Chess chess,
    int depth,
  ) {
    int score = 0;
    final moveUci = _moveToUci(move);

    // MVV/LVA for captures (highest priority)
    if ((move.flags & chess_lib.Chess.BITS_CAPTURE) != 0) {
      score += 10000; // Captures have highest priority
      // TODO: Add piece value difference (MVV/LVA refinement)
    }

    // Checks (high priority, can discover tactics). Move.flags has no
    // "gives check" bit, so this has to be detected by playing the move.
    chess.move(move);
    final givesCheck = chess.in_check;
    chess.undo_move();
    if (givesCheck) {
      score += 5000;
    }

    // Killer moves (medium priority)
    if (killerMoves.isKiller(depth, moveUci)) {
      score += 1000;
      // Primary killer > secondary killer
      final killers = killerMoves.getKillers(depth);
      if (killers.isNotEmpty && killers[0] == moveUci) {
        score += 500;
      }
    }

    // History heuristic (lower priority)
    final historyScore = _moveHistory[moveUci] ?? 0;
    score += historyScore;

    return score;
  }

  /// Record a move as part of search history
  /// Used for history heuristic
  void recordMove(String moveUci, int bonus) {
    _moveHistory[moveUci] = (_moveHistory[moveUci] ?? 0) + bonus;
  }

  /// Update move history after successful move
  void updateHistoryOnCutoff(List<chess_lib.Move> searchedMoves, int depth) {
    // Assign bonus inversely to search order
    // Moves tried later (after cutoff) get bonus credit
    for (int i = 0; i < searchedMoves.length; i++) {
      final moveUci = _moveToUci(searchedMoves[i]);
      final bonus = (searchedMoves.length - i) * (depth + 1);
      recordMove(moveUci, bonus);
    }
  }

  /// Clear history for new search
  void clear() {
    _moveHistory.clear();
    killerMoves.clear();
  }

  /// Get statistics about move ordering
  Map<String, dynamic> getStatistics() => {
        'killerMoveStats': killerMoves.getStatistics(),
        'uniqueMovesInHistory': _moveHistory.length,
        'totalHistoryScore':
            _moveHistory.values.fold<int>(0, (sum, val) => sum + val),
      };

  /// Convert move to UCI notation
  String _moveToUci(chess_lib.Move move) {
    String promotion = '';
    if (move.promotion != null) {
      promotion = move.promotion!.name;
    }
    return '${move.fromAlgebraic}${move.toAlgebraic}$promotion';
  }
}

/// Butterfly Heuristic (Alternative to Killer Moves)
///
/// Tracks all moves that caused cutoffs regardless of depth.
/// Simpler than killer moves but can be effective.
class ButterflyHeuristic {
  final Map<String, int> _cutoffCounts = {};
  final Map<String, int> _totalAttempts = {};

  /// Record move attempt
  void recordAttempt(String moveUci) {
    _totalAttempts[moveUci] = (_totalAttempts[moveUci] ?? 0) + 1;
  }

  /// Record successful cutoff
  void recordCutoff(String moveUci) {
    _cutoffCounts[moveUci] = (_cutoffCounts[moveUci] ?? 0) + 1;
  }

  /// Get cutoff rate for move
  double getCutoffRate(String moveUci) {
    final attempts = _totalAttempts[moveUci] ?? 0;
    if (attempts == 0) return 0;
    final cutoffs = _cutoffCounts[moveUci] ?? 0;
    return cutoffs / attempts;
  }

  /// Get top moves by cutoff rate
  List<Map<String, dynamic>> getTopMoves(int count) {
    final entries = _totalAttempts.entries
        .where((e) => e.value >= 5) // Minimum attempts for reliability
        .map((e) {
      final moveUci = e.key;
      final rate = getCutoffRate(moveUci);
      return {
        'move': moveUci,
        'attempts': e.value,
        'cutoffs': _cutoffCounts[moveUci] ?? 0,
        'rate': (rate * 100).toStringAsFixed(2),
      };
    }).toList()
      ..sort((a, b) => double.parse(b['rate']! as String)
          .compareTo(double.parse(a['rate']! as String)));

    return entries.take(count).toList();
  }

  /// Clear statistics
  void clear() {
    _cutoffCounts.clear();
    _totalAttempts.clear();
  }

  /// Get statistics
  Map<String, dynamic> getStatistics() => {
        'totalAttempts':
            _totalAttempts.values.fold<int>(0, (sum, val) => sum + val),
        'totalCutoffs':
            _cutoffCounts.values.fold<int>(0, (sum, val) => sum + val),
        'uniqueMoves': _totalAttempts.length,
        'topMoves': getTopMoves(10),
      };
}
