/// Opening Book for Chess AI
///
/// Provides pre-computed optimal opening moves to improve early-game play
/// and reduce computation time in the opening phase.

class OpeningBook {
  /// Mapping of board positions (in FEN) to list of recommended moves
  /// Moves are ordered by strength/popularity
  static const Map<String, List<String>> _bookPositions = {
    // Starting position
    'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1': [
      'e2e4', // Ruy Lopez / Italian Game
      'd2d4', // Queen's Gambit / Slav
      'c2c4', // English Opening
      'g1f3', // Reti Opening
    ],

    // After 1. e4 - most popular white opening
    'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1': [
      'c7c5', // Sicilian Defense (most popular)
      'e7e5', // Open Game / Ruy Lopez
      'c7c6', // Caro-Kann Defense
      'd7d5', // Scandinavian Defense
      'e7e6', // French Defense
    ],

    // After 1. e4 e5 - Open Game
    'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2': [
      'g1f3', // Ruy Lopez
      'f2f4', // King's Gambit
      'b1c3', // Italian Game
      'd2d4', // Scotch Game
    ],

    // After 1. d4 - Queen's Gambit
    'rnbqkbnr/pppppppp/8/8/3P4/8/PPP1PPPP/RNBQKBNR b KQkq d3 0 1': [
      'd7d5', // Queen's Gambit Declined (most solid)
      'c7c6', // Slav Defense
      'e7e6', // Semi-Slav
      'g8f6', // Modern Approach
      'c7c5', // Benoni
    ],

    // After 1. c4 - English Opening
    'rnbqkbnr/pppppppp/8/8/2P5/8/PP1PPPPP/RNBQKBNR b KQkq c3 0 1': [
      'e7e5', // Symmetrical English
      'c7c5', // Reversed Sicilian
      'g8f6', // English Fianchetto
      'e7e6', // Positional
    ],

    // Ruy Lopez - After 1. e4 e5 2. Nf3 Nc6 3. Bb5
    'r1bqkbnr/pppp1ppp/2n5/1B2p3/4P3/5N2/PPPP1PPP/RNBQK2R b KQkq - 3 3': [
      'a7a6', // Most popular - Anti-Bishop move
      'g8f6', // Solid defense
      'd7d6', // Solid
    ],

    // Sicilian Defense - After 1. e4 c5 2. Nf3 d6 3. d4 cxd4 4. Nxd4
    'rnbqkbnr/pp2pppp/3p4/8/3NP3/8/PPP2PPP/RNBQKB1R b KQkq - 0 4': [
      'g8f6', // Najdorf / Sveshnikov lines
      'e7e5', // Classical Defense
      'a7a6', // Positional Sicilian
    ],

    // Sicilian Najdorf - after moves leading to it
    'rnbqkb1r/pp2pppp/3p1n2/8/3NP3/8/PPP2PPP/RNBQKB1R w KQkq - 1 5': [
      'f1c4', // English Attack
      'c1g5', // Classical
      'e1g1', // Solid
      'f1e2', // Positional
    ],
  };

  /// Get recommended moves for a given FEN position
  /// Returns a list of moves in UCI notation, ordered by strength
  static List<String> getRecommendedMoves(String fen) {
    // Normalize FEN for lookup (some positions might have minor FEN variations)
    final normalized = _normalizeFen(fen);

    if (_bookPositions.containsKey(normalized)) {
      return _bookPositions[normalized]!;
    }

    // Try matching without clock/move numbers (more flexible matching)
    for (final bookFen in _bookPositions.keys) {
      if (_areFenPositionsEquivalent(normalized, bookFen)) {
        return _bookPositions[bookFen]!;
      }
    }

    return [];
  }

  /// Check if a position is in the opening book
  static bool isInBook(String fen) => getRecommendedMoves(fen).isNotEmpty;

  /// Get the depth of the opening book line for a position
  /// Useful for determining when to exit book and start using AI search
  static int getBookDepth(String fen) {
    // Count the number of moves since start
    final parts = fen.split(' ');
    if (parts.length >= 6) {
      final moveNumber = int.tryParse(parts[5]) ?? 1;
      // Each full move (white + black) is 2 plies
      return (moveNumber - 1) * 2;
    }
    return 0;
  }

  /// Normalize FEN for consistent lookup
  /// Removes trailing move counters that might vary
  static String _normalizeFen(String fen) {
    final parts = fen.split(' ');
    if (parts.length >= 4) {
      // Return position, active color, castling, en passant
      // Normalize the move counter to standard values
      return '${parts[0]} ${parts[1]} ${parts[2]} ${parts[3]}';
    }
    return fen;
  }

  /// Check if two FEN positions represent the same board state
  static bool _areFenPositionsEquivalent(String fen1, String fen2) {
    final parts1 = fen1.split(' ');
    final parts2 = fen2.split(' ');

    if (parts1.isEmpty || parts2.isEmpty) return false;

    // Compare position (board state)
    if (parts1[0] != parts2[0]) return false;

    // Compare active color
    if (parts1.length > 1 && parts2.length > 1) {
      if (parts1[1] != parts2[1]) return false;
    }

    // Compare castling rights
    if (parts1.length > 2 && parts2.length > 2) {
      if (parts1[2] != parts2[2]) return false;
    }

    // Compare en passant square
    if (parts1.length > 3 && parts2.length > 3) {
      if (parts1[3] != parts2[3]) return false;
    }

    return true;
  }

  /// Statistical summary of opening book
  static Map<String, dynamic> getBookStatistics() => {
        'totalPositions': _bookPositions.length,
        'totalMoveEntries': _bookPositions.values
            .fold<int>(0, (sum, moves) => sum + moves.length),
        'maxMoves': _bookPositions.values
            .map((moves) => moves.length)
            .fold<int>(0, (max, length) => length > max ? length : max),
        'averageMoveOptions': _bookPositions.values.isNotEmpty
            ? (_bookPositions.values
                    .fold<int>(0, (sum, moves) => sum + moves.length) /
                _bookPositions.length)
            : 0,
      };
}
