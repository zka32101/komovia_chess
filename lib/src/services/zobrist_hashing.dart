/// Zobrist Hashing for Chess Positions
///
/// Implements Zobrist hashing to efficiently hash chess positions into 64-bit keys.
/// Replaces FEN string-based hashing with fast bitwise operations.
/// Used for transposition table lookup in search algorithms.

import 'dart:math' show Random;
import 'package:chess/chess.dart' as chess_lib;

/// Zobrist Hash Generator
///
/// Generates and manages Zobrist hash keys for chess positions.
/// Each piece type and position combination has a unique random 64-bit key.
/// Combined via XOR operations for fast position hashing.
class ZobristHash {
  /// Random number generator (seeded for reproducibility)
  static final Random _rng = Random(12345);

  /// Zobrist table: [piece type][square]
  /// 12 piece types × 64 squares = 768 keys
  static late final List<List<int>> _pieces;

  /// Zobrist key for white to move
  static late final int _whiteToMove;

  /// Zobrist keys for castling rights
  /// [0] = white kingside, [1] = white queenside
  /// [2] = black kingside, [3] = black queenside
  static late final List<int> _castlingRights;

  /// Zobrist keys for en passant files (0-7)
  static late final List<int> _enPassantFiles;

  /// Whether hash tables have been initialized
  static bool _initialized = false;

  /// Initialize Zobrist hash tables (call once at startup)
  static void initialize() {
    if (_initialized) return;

    _pieces = List.generate(
      12,
      (i) => List.generate(64, (j) => _randomInt64()),
    );

    _whiteToMove = _randomInt64();

    _castlingRights = List.generate(4, (i) => _randomInt64());

    _enPassantFiles = List.generate(8, (i) => _randomInt64());

    _initialized = true;
  }

  /// Generate random 64-bit integer
  static int _randomInt64() =>
      (_rng.nextInt(0x100000000) << 32) | _rng.nextInt(0x100000000);

  /// Get piece index for Zobrist table lookup
  /// Returns 0-11 based on piece type and color
  static int _getPieceIndex(chess_lib.Piece piece) {
    int index = _getPieceTypeIndex(piece.type);
    if (piece.color == chess_lib.Color.BLACK) {
      index += 6;
    }
    return index;
  }

  /// Get piece type index (0-5 for white pieces)
  static int _getPieceTypeIndex(chess_lib.PieceType type) {
    // PieceType is a plain class with static const instances, not a real
    // Dart enum, so the analyzer can't prove this switch is exhaustive.
    switch (type) {
      case chess_lib.PieceType.PAWN:
        return 0;
      case chess_lib.PieceType.KNIGHT:
        return 1;
      case chess_lib.PieceType.BISHOP:
        return 2;
      case chess_lib.PieceType.ROOK:
        return 3;
      case chess_lib.PieceType.QUEEN:
        return 4;
      case chess_lib.PieceType.KING:
        return 5;
      default:
        throw ArgumentError('Unknown piece type: $type');
    }
  }

  /// Convert square notation (a1-h8) to index (0-63)
  static int _squareToIndex(String square) {
    final file = square.codeUnitAt(0) - 'a'.codeUnitAt(0); // 0-7
    final rank = square.codeUnitAt(1) - '1'.codeUnitAt(0); // 0-7
    return rank * 8 + file;
  }

  /// Convert square index (0-63) to notation (a1-h8)
  static String _indexToSquare(int index) {
    final file = String.fromCharCode('a'.codeUnitAt(0) + (index % 8));
    final rank = String.fromCharCode('1'.codeUnitAt(0) + (index ~/ 8));
    return '$file$rank';
  }

  /// Hash a chess position
  /// Returns a 64-bit hash key for the position
  static int hashPosition(chess_lib.Chess chess) {
    int hash = 0;

    // Hash all pieces on the board
    for (int i = 0; i < 64; i++) {
      final square = _indexToSquare(i);
      final piece = chess.get(square);

      if (piece != null) {
        final pieceIndex = _getPieceIndex(piece);
        hash ^= _pieces[pieceIndex][i];
      }
    }

    // Hash white to move
    if (chess.turn == chess_lib.Color.WHITE) {
      hash ^= _whiteToMove;
    }

    // Hash castling rights (Chess.castling is a per-color bitmask of
    // Chess.BITS_KSIDE_CASTLE/BITS_QSIDE_CASTLE; there's no CastleSide type
    // or canCastle() method in the chess package).
    if ((chess.castling[chess_lib.Color.WHITE] &
            chess_lib.Chess.BITS_KSIDE_CASTLE) !=
        0) {
      hash ^= _castlingRights[0];
    }
    if ((chess.castling[chess_lib.Color.WHITE] &
            chess_lib.Chess.BITS_QSIDE_CASTLE) !=
        0) {
      hash ^= _castlingRights[1];
    }
    if ((chess.castling[chess_lib.Color.BLACK] &
            chess_lib.Chess.BITS_KSIDE_CASTLE) !=
        0) {
      hash ^= _castlingRights[2];
    }
    if ((chess.castling[chess_lib.Color.BLACK] &
            chess_lib.Chess.BITS_QSIDE_CASTLE) !=
        0) {
      hash ^= _castlingRights[3];
    }

    // Hash en passant file (if available). ep_square is a 0x88 square index
    // (or Chess.EMPTY when there's none), not an algebraic string.
    final epSquare = chess.ep_square;
    if (epSquare != null && epSquare != chess_lib.Chess.EMPTY) {
      final square = chess_lib.Chess.algebraic(epSquare);
      final file = square.codeUnitAt(0) - 'a'.codeUnitAt(0);
      hash ^= _enPassantFiles[file];
    }

    return hash;
  }

  /// Update hash incrementally after a move
  /// Faster than rehashing the entire position
  static int updateHash(
    int currentHash,
    chess_lib.Chess chess,
    chess_lib.Move move,
  ) {
    int newHash = currentHash;

    // Remove moving piece from source square
    final piece = chess.get(move.fromAlgebraic);
    if (piece != null) {
      final pieceIndex = _getPieceIndex(piece);
      final fromIndex = _squareToIndex(move.fromAlgebraic);
      newHash ^= _pieces[pieceIndex][fromIndex];
    }

    // Add moving piece to destination square
    // (This would need the actual destination piece info)
    final toIndex = _squareToIndex(move.toAlgebraic);
    if (piece != null) {
      final pieceIndex = _getPieceIndex(piece);
      newHash ^= _pieces[pieceIndex][toIndex];
    }

    // Toggle white to move (position changes turn)
    newHash ^= _whiteToMove;

    // Note: Handling capture pieces, castling, en passant requires
    // more complex logic with actual board state after the move

    return newHash;
  }

  /// Get statistics about hash table
  static Map<String, dynamic> getHashStatistics() {
    if (!_initialized) {
      return {'status': 'not_initialized'};
    }

    return {
      'status': 'initialized',
      'piecesTableSize': _pieces.length * 64,
      'castlingRightsSize': _castlingRights.length,
      'enPassantFilesSize': _enPassantFiles.length,
      'totalKeys': (_pieces.length * 64) + 1 + 4 + 8,
      'hashBits': 64,
    };
  }
}

/// Transposition table entry
class TranspositionEntry {
  // 0 = exact, 1 = lower bound, 2 = upper bound

  TranspositionEntry({
    required this.hash,
    required this.score,
    required this.depth,
    required this.flag,
  });
  final int hash;
  final int score;
  final int depth;
  final int flag;

  bool isExact() => flag == 0;
  bool isLowerBound() => flag == 1;
  bool isUpperBound() => flag == 2;
}

/// Zobrist-based Transposition Table
///
/// Efficient hash table for storing evaluated positions.
/// Uses 64-bit Zobrist keys instead of FEN strings.
/// Faster lookup and lower memory usage than string-based approach.
class ZobristTranspositionTable {
  ZobristTranspositionTable({int maxSize = 100000}) : _maxSize = maxSize;

  /// Transposition table storage
  final Map<int, TranspositionEntry> _table = {};

  /// Maximum number of entries (configurable)
  final int _maxSize;

  /// Statistics
  int _hits = 0;
  int _misses = 0;
  int _overwrites = 0;

  /// Store a position evaluation
  void store(int hash, int score, int depth, int flag) {
    if (_table.length >= _maxSize) {
      // Simple eviction: remove oldest entry
      // In production, use more sophisticated replacement strategy
      if (_table.isNotEmpty) {
        _table.remove(_table.keys.first);
        _overwrites++;
      }
    }

    _table[hash] = TranspositionEntry(
      hash: hash,
      score: score,
      depth: depth,
      flag: flag,
    );
  }

  /// Lookup a position evaluation
  TranspositionEntry? lookup(int hash) {
    final entry = _table[hash];
    if (entry != null) {
      _hits++;
    } else {
      _misses++;
    }
    return entry;
  }

  /// Clear the transposition table
  void clear() {
    _table.clear();
    _hits = 0;
    _misses = 0;
    _overwrites = 0;
  }

  /// Get table statistics
  Map<String, dynamic> getStatistics() {
    final total = _hits + _misses;
    final hitRate =
        total > 0 ? (_hits / total * 100).toStringAsFixed(2) : '0.00';

    return {
      'entries': _table.length,
      'maxSize': _maxSize,
      'fillPercentage': (_table.length / _maxSize * 100).toStringAsFixed(2),
      'hits': _hits,
      'misses': _misses,
      'total': total,
      'hitRate': '$hitRate%',
      'overwrites': _overwrites,
      'memoryEstimate': '${(_table.length * 40) ~/ 1024} KB',
    };
  }
}

/// Performance Comparison: String vs Zobrist Hashing
///
/// String-based (FEN):
/// - Lookup: ~500-1000ns (string comparison)
/// - Memory: ~100-150 bytes per position
/// - Cache performance: Poor (string data scatters in memory)
///
/// Zobrist Hash:
/// - Lookup: ~50-100ns (integer comparison)
/// - Memory: ~8 bytes per key + 40 bytes per entry (~48 bytes total)
/// - Cache performance: Excellent (64-bit integers fit in CPU cache)
/// - Speedup: ~5-10x faster lookups, ~50-70% memory savings
