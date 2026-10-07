/// Countermove Heuristic for Chess AI
///
/// Tracks effective moves that follow specific opponent moves.
/// If opponent plays move X, and move Y is a strong response,
/// move Y becomes a countermove to X and gets prioritized.
///
/// More specific than killer moves: X→Y relationship vs just Y at depth

import 'package:chess/chess.dart' as chess_lib;

/// Countermove Heuristic Table
///
/// Maps (from_square, to_square) of opponent moves to effective counter-moves.
/// More memory than killer moves but more precise positioning information.
class CountermoveHeuristic {
  /// Countermove table: Map of (from,to) → best counter-moves
  /// Key: "e7e5" (opponent move in UCI)
  /// Value: List of counter-moves in priority order
  final Map<String, List<String>> _countermoves = {};

  /// Score tracking for each counter-move pair
  final Map<String, int> _pairScores = {};

  /// Statistics
  int _totalCutoffs = 0;
  int _countermoveCutoffs = 0;

  /// Record a counter-move (response to opponent move)
  /// Call when a move Y causes cutoff after opponent played move X
  void recordCountermove(String opponentMove, String counterMove) {
    if (!_countermoves.containsKey(opponentMove)) {
      _countermoves[opponentMove] = [];
    }

    final counters = _countermoves[opponentMove]!;

    // If already in list, move to front
    if (counters.contains(counterMove)) {
      counters.remove(counterMove);
      counters.insert(0, counterMove);
    } else {
      // Add new counter-move to front
      counters.insert(0, counterMove);
      // Keep only top 4 counter-moves per position
      if (counters.length > 4) {
        counters.removeLast();
      }
    }

    // Increment pair score
    final pairKey = '$opponentMove→$counterMove';
    _pairScores[pairKey] = (_pairScores[pairKey] ?? 0) + 1;

    _totalCutoffs++;
    _countermoveCutoffs++;
  }

  /// Get counter-moves for a specific opponent move
  List<String> getCountermoves(String opponentMove) =>
      _countermoves[opponentMove] ?? [];

  /// Check if a move is a known counter-move
  bool isCountermove(String opponentMove, String counterMove) {
    final counters = _countermoves[opponentMove];
    return counters != null && counters.contains(counterMove);
  }

  /// Get score for a counter-move pair
  int getCountermoveScore(String opponentMove, String counterMove) {
    final pairKey = '$opponentMove→$counterMove';
    return _pairScores[pairKey] ?? 0;
  }

  /// Get priority of counter-move (0 = highest priority)
  int getCountermovePriority(String opponentMove, String counterMove) {
    final counters = getCountermoves(opponentMove);
    final index = counters.indexOf(counterMove);
    return index >= 0 ? index : 999; // 999 = not a known counter-move
  }

  /// Clear all counter-move history
  void clear() {
    _countermoves.clear();
    _pairScores.clear();
    _totalCutoffs = 0;
    _countermoveCutoffs = 0;
  }

  /// Get statistics
  Map<String, dynamic> getStatistics() {
    final total = _totalCutoffs;
    final rate = total > 0 ? (_countermoveCutoffs / total * 100) : 0.0;

    return {
      'totalCutoffs': total,
      'countermoveCutoffs': _countermoveCutoffs,
      'cutoffRate': rate,
      'uniquePositions': _countermoves.length,
      'totalCountermovePairs': _pairScores.length,
      'topPositions': _getTopPositions(5),
    };
  }

  /// Get top opponent moves by counter-move effectiveness
  List<Map<String, dynamic>> _getTopPositions(int count) {
    final entries = _countermoves.entries
        .map((e) => {
              'opponentMove': e.key,
              'counterCount': e.value.length,
              'topCounter': e.value.isNotEmpty ? e.value[0] : null,
              'score': e.value.fold<int>(
                  0,
                  (sum, counter) =>
                      sum + (_pairScores['${e.key}→$counter'] ?? 0)),
            })
        .toList()
      ..sort((a, b) => (b['score']! as int).compareTo(a['score']! as int));

    return entries.take(count).toList();
  }
}

/// Advanced Move Ordering with Countermoves
///
/// Integrates killer moves, countermoves, and history into unified system
class AdvancedMoveOrderer {
  AdvancedMoveOrderer({CountermoveHeuristic? countermoves})
      : countermoves = countermoves ?? CountermoveHeuristic();
  final CountermoveHeuristic countermoves;
  final Map<String, int> _moveHistory = {};
  final Map<String, int> _killerMoves = {};

  String? _lastOpponentMove;

  /// Set the last opponent move (for countermove heuristic)
  void setLastOpponentMove(String moveUci) {
    _lastOpponentMove = moveUci;
  }

  /// Order moves using all heuristics
  List<chess_lib.Move> orderMoves(
    List<chess_lib.Move> moves,
    chess_lib.Chess chess, {
    int depth = 0,
  }) {
    // Score all moves
    final scoredMoves = moves.map((move) {
      final score = _scoreMoveAdvanced(move, chess, depth);
      return (move, score);
    }).toList();

    // Sort by score (descending)
    scoredMoves.sort((a, b) => b.$2.compareTo(a.$2));

    return scoredMoves.map((p) => p.$1).toList();
  }

  /// Score move using all available heuristics
  int _scoreMoveAdvanced(
    chess_lib.Move move,
    chess_lib.Chess chess,
    int depth,
  ) {
    int score = 0;
    final moveUci = _moveToUci(move);

    // 1. Captures (highest priority)
    if ((move.flags & chess_lib.Chess.BITS_CAPTURE) != 0) {
      score += 10000;
    }

    // 2. Checks. Move.flags has no "gives check" bit, so this has to be
    // detected by playing the move.
    chess.move(move);
    final givesCheck = chess.in_check;
    chess.undo_move();
    if (givesCheck) {
      score += 5000;
    }

    // 3. Counter-moves (medium-high)
    if (_lastOpponentMove != null &&
        countermoves.isCountermove(_lastOpponentMove!, moveUci)) {
      score += 3000;
      // Primary counter-move gets bonus
      if (countermoves.getCountermovePriority(_lastOpponentMove!, moveUci) ==
          0) {
        score += 500;
      }
    }

    // 4. Killer moves (medium)
    if (_killerMoves.containsKey(moveUci)) {
      score += 1000;
    }

    // 5. History heuristic (low)
    score += _moveHistory[moveUci] ?? 0;

    return score;
  }

  /// Record a killer move
  void recordKiller(String moveUci) {
    _killerMoves[moveUci] = (_killerMoves[moveUci] ?? 0) + 1;
  }

  /// Record move in history
  void recordHistory(String moveUci, int bonus) {
    _moveHistory[moveUci] = (_moveHistory[moveUci] ?? 0) + bonus;
  }

  /// Record counter-move (response to opponent)
  void recordCountermove(String counterMove) {
    if (_lastOpponentMove != null) {
      countermoves.recordCountermove(_lastOpponentMove!, counterMove);
    }
  }

  /// Clear all history
  void clear() {
    _moveHistory.clear();
    _killerMoves.clear();
    countermoves.clear();
    _lastOpponentMove = null;
  }

  /// Get combined statistics
  Map<String, dynamic> getStatistics() => {
        'countermoveStats': countermoves.getStatistics(),
        'killerMoves': _killerMoves.length,
        'historyMoves': _moveHistory.length,
        'lastOpponentMove': _lastOpponentMove,
      };

  /// Convert move to UCI
  String _moveToUci(chess_lib.Move move) {
    String promotion = '';
    if (move.promotion != null) {
      promotion = move.promotion!.name;
    }
    return '${move.fromAlgebraic}${move.toAlgebraic}$promotion';
  }
}

/// Principal Variation and Counter-Move Refinement
///
/// Tracks the principal variation (best line) and uses it to guide search
class PrincipalVariationCache {
  /// Main variation: sequence of moves that represent best play
  final List<String> _principalVariation = [];

  /// PV at each depth
  final Map<int, String> _pvMoves = {};

  /// Statistics
  int _pvCutoffs = 0;
  int _pvSearches = 0;

  /// Set principal variation for a depth
  void setPVMove(int depth, String moveUci) {
    _pvMoves[depth] = moveUci;
  }

  /// Get PV move at depth
  String? getPVMove(int depth) => _pvMoves[depth];

  /// Record PV cutoff (when PV move caused cutoff)
  void recordPVCutoff() {
    _pvCutoffs++;
  }

  /// Record PV search attempt
  void recordPVSearch() {
    _pvSearches++;
  }

  /// Get PV cutoff rate
  double getPVCutoffRate() {
    if (_pvSearches == 0) return 0;
    return _pvCutoffs / _pvSearches;
  }

  /// Update principal variation
  void updatePrincipalVariation(List<String> moves) {
    _principalVariation.clear();
    _principalVariation.addAll(moves);
  }

  /// Get principal variation
  List<String> getPrincipalVariation() => List.from(_principalVariation);

  /// Clear cache
  void clear() {
    _principalVariation.clear();
    _pvMoves.clear();
    _pvCutoffs = 0;
    _pvSearches = 0;
  }

  /// Get statistics
  Map<String, dynamic> getStatistics() => {
        'pvLength': _principalVariation.length,
        'pvCutoffs': _pvCutoffs,
        'pvSearches': _pvSearches,
        'pvCutoffRate': getPVCutoffRate(),
      };
}
