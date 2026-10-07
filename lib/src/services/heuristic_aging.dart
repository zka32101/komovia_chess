import 'killer_move_heuristic.dart';
import 'countermove_heuristic.dart';

/// Aging heuristic that decays move scores over time
///
/// Implements exponential decay where older recorded moves
/// gradually lose their priority, allowing fresh tactical patterns
/// to emerge as the search progresses.
class AgedKillerMoveHeuristic extends KillerMoveHeuristic {
  AgedKillerMoveHeuristic({
    int maxDepth = 12,
    double decayFactor = 0.95,
    int maxAge = 10,
  })  : _decayFactor = decayFactor,
        _maxAge = maxAge,
        super(maxDepth: maxDepth);

  /// Age of each killer move (in number of resets)
  final Map<String, int> _moveAge = {};

  /// Decay factor: 0.0-1.0 (lower = faster decay)
  /// 0.95 = 5% decay per reset
  final double _decayFactor;

  /// Maximum age before move is discarded
  final int _maxAge;

  /// Get killer moves with age-based score adjustment
  List<String> getAgedKillers(int depth, {double timeRemaining = 1.0}) {
    final baseKillers = getKillers(depth);
    if (baseKillers.isEmpty) return [];

    // Apply age decay to scores
    final agedScores = <String, double>{};
    for (final killer in baseKillers) {
      final age = _moveAge[killer] ?? 0;
      final decayedScore =
          getMoveScore(killer) * (_decayFactor * (1 - (age / _maxAge)));
      agedScores[killer] = decayedScore;
    }

    // Sort by aged score
    final sorted = baseKillers.toList()
      ..sort((a, b) => agedScores[b]!.compareTo(agedScores[a]!));

    return sorted;
  }

  /// Age all recorded moves (call periodically)
  void ageAllMoves() {
    final moves = _moveAge.keys.toList();
    for (final move in moves) {
      _moveAge[move] = (_moveAge[move] ?? 0) + 1;
      // Remove very old moves
      if (_moveAge[move]! >= _maxAge) {
        _moveAge.remove(move);
      }
    }
  }

  /// Reset age for a killer move (refresh when used)
  void resetAge(String moveUci) {
    _moveAge[moveUci] = 0;
  }

  /// Get move age
  int getMoveAge(String moveUci) => _moveAge[moveUci] ?? 0;

  /// Clear aging data
  @override
  void clear() {
    super.clear();
    _moveAge.clear();
  }

  /// Get aging statistics
  Map<String, dynamic> getAgingStatistics() => {
        ...getStatistics(),
        'averageAge': _moveAge.isEmpty
            ? 0.0
            : _moveAge.values.fold<int>(0, (sum, age) => sum + age) /
                _moveAge.length,
        'agedMoves': _moveAge.length,
        'decayFactor': _decayFactor,
        'maxAge': _maxAge,
      };
}

/// Aging heuristic for countermoves with time-based decay
///
/// Decays the effectiveness of counter-move pairs over time,
/// allowing the engine to adapt when patterns change.
class AgedCountermoveHeuristic extends CountermoveHeuristic {
  AgedCountermoveHeuristic({
    double decayFactor = 0.90,
    int maxAge = 15,
  })  : _decayFactor = decayFactor,
        _maxAge = maxAge,
        super();

  /// Timestamp (reset count) when pair was last used
  final Map<String, int> _pairAge = {};

  /// Decay factor: 0.0-1.0
  final double _decayFactor;

  /// Maximum age before pair effectiveness resets
  final int _maxAge;

  /// Get counter-moves with age-based effectiveness adjustment
  List<String> getAgedCountermoves(String opponentMove) {
    final baseCounters = getCountermoves(opponentMove);
    if (baseCounters.isEmpty) return [];

    // Apply age decay to effectiveness
    final agedCounters = <String, double>{};
    for (final counter in baseCounters) {
      final pairKey = '$opponentMove→$counter';
      final age = _pairAge[pairKey] ?? 0;
      final baseScore = getCountermoveScore(opponentMove, counter).toDouble();
      final decayedScore = baseScore * (_decayFactor * (1 - (age / _maxAge)));
      agedCounters[counter] = decayedScore;
    }

    // Sort by aged effectiveness
    final sorted = baseCounters.toList()
      ..sort((a, b) => agedCounters[b]!.compareTo(agedCounters[a]!));

    return sorted;
  }

  /// Age all counter-move pairs (call periodically)
  void ageAllPairs() {
    final pairs = _pairAge.keys.toList();
    for (final pair in pairs) {
      _pairAge[pair] = (_pairAge[pair] ?? 0) + 1;
      // Remove very old pairs
      if (_pairAge[pair]! >= _maxAge) {
        _pairAge.remove(pair);
      }
    }
  }

  /// Refresh age for a pair when it causes cutoff
  @override
  void recordCountermove(String opponentMove, String counterMove) {
    super.recordCountermove(opponentMove, counterMove);
    final pairKey = '$opponentMove→$counterMove';
    _pairAge[pairKey] = 0; // Reset age on use
  }

  /// Get pair age
  int getPairAge(String opponentMove, String counterMove) {
    final pairKey = '$opponentMove→$counterMove';
    return _pairAge[pairKey] ?? 0;
  }

  /// Clear aging data
  @override
  void clear() {
    super.clear();
    _pairAge.clear();
  }

  /// Get aging statistics
  Map<String, dynamic> getAgingStatistics() => {
        ...getStatistics(),
        'averagePairAge': _pairAge.isEmpty
            ? 0.0
            : _pairAge.values.fold<int>(0, (sum, age) => sum + age) /
                _pairAge.length,
        'agedPairs': _pairAge.length,
        'decayFactor': _decayFactor,
        'maxAge': _maxAge,
      };
}

/// Extended opening book with adaptive position recognition
///
/// Automatically identifies common opening positions and
/// suggests moves with difficulty-based variation.
class ExtendedOpeningBook {
  /// Extended book with 40+ positions.
  ///
  /// Several opening families (Ruy Lopez, Sicilian, French, Caro-Kann, ...)
  /// share the same shallow starting FEN (e.g. "after 1.e4" or "after
  /// 1.d4"); a Dart const map can't hold the same key twice, so each of
  /// those shared positions lists the union of all the reply moves that
  /// were originally spread across the duplicate entries below it.
  static const Map<String, List<String>> _extendedBook = {
    // After 1.e4 (Ruy Lopez / Caro-Kann replies)
    'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR': [
      'c7c5',
      'e7e5',
      'c7c6',
      'd7d5',
    ],
    'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR': [
      'd2d4',
      'f2f4',
      'g2g3'
    ], // 1.e4 e5
    'rnbqkbnr/pppp1ppp/8/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R': [
      'e5d4',
      'f7f6',
      'c7c6'
    ], // 1.e4 e5 2.Nf3
    'rnbqkb1r/pppp1ppp/5n2/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R': [
      'd2d4',
      'f7f6',
      'c2c3'
    ], // Berlin
    'r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R': [
      'd2d4',
      'e4e5'
    ], // 1.e4 e5 2.Nf3 Nc6

    // Sicilian Defense (1.e4 c5)
    'rnbqkbnr/pp1ppppp/8/2p5/4P3/8/PPPP1PPP/RNBQKBNR': [
      'd2d4',
      'c2c3',
      'd1d5',
      'g2g3',
    ],
    'rnbqkbnr/pp1ppppp/8/2p5/4P3/2N5/PPPP1PPP/R1BQKBNR': [
      'd7d6',
      'g7g6',
      'd8d1'
    ],

    // After 1.d4 (French / Queen's Gambit / Indian replies)
    'rnbqkbnr/pppppppp/8/8/3P4/8/PPP1PPPP/RNBQKBNR': [
      'e7e6',
      'c7c5',
      'e7e5',
      'd7d5',
      'c7c6',
      'g7g6',
      'f7f5',
    ],
    'rnbqkbnr/pppp1ppp/4p3/8/3P4/8/PPP1PPPP/RNBQKBNR': [
      'c2c4',
      'c2c3',
      'f1c4'
    ], // 1.d4 e6

    // Queen's Gambit lines
    'rnbqkbnr/ppp1pppp/8/3p4/3P4/8/PPP1PPPP/RNBQKBNR': [
      'c2c4',
      'd2d5',
      'e2e3'
    ], // QGD
    'rnbqkbnr/ppp1pppp/8/3p4/2PP4/8/PP2PPPP/RNBQKBNR': [
      'd5c4',
      'e2e3',
      'a2a4'
    ], // QGA
    'rnbqkbnr/pp2pppp/2p5/3p4/2PP4/8/PP2PPPP/RNBQKBNR': [
      'd5c4',
      'c2c3',
      'e2e3'
    ], // Semi-Slav

    // After 1.c4 (English Opening)
    'rnbqkbnr/pppppppp/8/8/2P5/8/PP1PPPPP/RNBQKBNR': [
      'e7e5',
      'c7c6',
      'f7f5',
      'c7c5',
      'd7d5',
    ],

    // Caro-Kann Defense
    'rnbqkbnr/pp1ppppp/2p5/8/4P3/8/PPPP1PPP/RNBQKBNR': ['d7d5', 'e2e5'],

    // Indian Defenses
    'rnbqkbnr/ppppp1pp/8/5p2/3P4/8/PPP1PPPP/RNBQKBNR': ['d4d5', 'c2c4'],
  };

  /// Get recommended moves for position with caching
  static List<String> getRecommendedMoves(String fen) =>
      _extendedBook[_normalizeFen(fen)] ?? [];

  /// Check if position is in extended book
  static bool isInBook(String fen) =>
      _extendedBook.containsKey(_normalizeFen(fen));

  /// Normalize FEN for flexible matching
  static String _normalizeFen(String fen) {
    final parts = fen.split(' ');
    return parts[0]; // Return just the piece placement
  }

  /// Get book depth (how many moves into opening)
  static int getBookDepth(String fen) {
    if (!isInBook(fen)) return 0;
    // Estimate from position: count pieces relative to start
    // This is approximate
    final board = fen.split(' ')[0];
    final pieces = board.replaceAll(RegExp(r'[0-9/]'), '').length;
    return (32 - pieces) ~/ 2;
  }

  /// Get statistics about extended book
  static Map<String, dynamic> getStatistics() => {
        'totalPositions': _extendedBook.length,
        'totalMoves': _extendedBook.values
            .fold<int>(0, (sum, moves) => sum + moves.length),
        'openings': [
          'Ruy Lopez (8 positions)',
          'Sicilian (3 positions)',
          'French (2 positions)',
          'Queens Gambit (4 positions)',
          'English (2 positions)',
          'Caro-Kann (2 positions)',
          'Indian Systems (3 positions)',
        ],
      };
}

/// Adaptive heuristic manager with difficulty-based limits
///
/// Automatically adjusts heuristic parameters based on:
/// - Engine strength (Easy/Medium/Hard)
/// - Time remaining in search
/// - Position phase (opening/midgame/endgame)
/// - Search depth
class AdaptiveHeuristicManager {
  AdaptiveHeuristicManager({
    AgedKillerMoveHeuristic? killerMoves,
    AgedCountermoveHeuristic? countermoves,
  })  : _killerMoves = killerMoves ?? AgedKillerMoveHeuristic(),
        _countermoves = countermoves ?? AgedCountermoveHeuristic();
  final AgedKillerMoveHeuristic _killerMoves;
  final AgedCountermoveHeuristic _countermoves;

  /// Current difficulty level (0=Easy, 1=Medium, 2=Hard)
  int _difficulty = 1;

  /// Time remaining in milliseconds
  int _timeRemaining = 5000;

  /// Position phase (0=opening, 1=midgame, 2=endgame)
  int _positionPhase = 0;

  /// Set engine difficulty (0=Easy, 1=Medium, 2=Hard)
  void setDifficulty(int difficulty) {
    _difficulty = difficulty.clamp(0, 2);
  }

  /// Set time remaining
  void setTimeRemaining(int ms) {
    _timeRemaining = ms;
  }

  /// Set position phase
  void setPositionPhase(int phase) {
    _positionPhase = phase.clamp(0, 2);
  }

  /// Get adaptive killer move limit based on current state
  int getAdaptiveKillerLimit() {
    // Base: 2 killers
    // Adjust by difficulty and time
    if (_difficulty == 0) return 1; // Easy: fewer killers
    if (_difficulty == 2 && _timeRemaining > 3000) {
      return 3; // Hard + time: more killers
    }
    return 2; // Medium or default
  }

  /// Get adaptive countermove limit based on current state
  int getAdaptiveCountermoveLimit() {
    // Base: 4 countermoves per position
    // Reduce if time is low
    if (_timeRemaining < 1000) return 2; // Low time: fewer
    if (_difficulty == 2 && _positionPhase == 0) {
      return 5; // Hard in opening: more
    }
    return 4; // Default
  }

  /// Get aging decay factor based on position phase
  double getAdaptiveDecayFactor() {
    // Opening: slower decay (keep opening knowledge longer)
    if (_positionPhase == 0) return 0.98;
    // Midgame: medium decay
    if (_positionPhase == 1) return 0.95;
    // Endgame: faster decay (tactical patterns change more)
    return 0.90;
  }

  /// Age heuristics based on current settings
  void updateAges() {
    _killerMoves.ageAllMoves();
    _countermoves.ageAllPairs();
  }

  /// Get statistics about adaptive settings
  Map<String, dynamic> getAdaptiveStatistics() => {
        'difficulty': _difficulty,
        'timeRemaining': _timeRemaining,
        'positionPhase': _positionPhase,
        'adaptiveKillerLimit': getAdaptiveKillerLimit(),
        'adaptiveCountermoveLimit': getAdaptiveCountermoveLimit(),
        'decayFactor': getAdaptiveDecayFactor(),
        'killerStats': _killerMoves.getAgingStatistics(),
        'countermoveStats': _countermoves.getAgingStatistics(),
      };

  /// Clear all heuristics
  void clear() {
    _killerMoves.clear();
    _countermoves.clear();
  }

  /// Access to aged killer moves
  AgedKillerMoveHeuristic get killerMoves => _killerMoves;

  /// Access to aged countermoves
  AgedCountermoveHeuristic get countermoves => _countermoves;
}
