import 'package:chess/chess.dart' as chess_lib;
import 'draw_detection_service.dart';
import 'move_validation_service.dart';

/// Service for chess game logic and move validation
class ChessEngineService {
  ChessEngineService() {
    _chess = chess_lib.Chess();
  }
  late chess_lib.Chess _chess;
  final List<Map<String, dynamic>> _moveHistory = [];

  /// The underlying chess_lib.Chess instance, for callers (e.g. Zobrist
  /// hashing) that need to operate on the raw position directly.
  chess_lib.Chess get rawChess => _chess;

  /// Initialize a new game with optional FEN string
  void initGame({String? fen}) {
    if (fen != null) {
      _chess = chess_lib.Chess.fromFEN(fen);
    } else {
      _chess = chess_lib.Chess();
    }
  }

  /// Get current FEN string
  String getCurrentFen() => _chess.fen;

  /// Get current board as an 8x8 array (row 0 = rank 8, column 0 = file a).
  List<List<chess_lib.Piece?>> getBoard() => List.generate(
        8,
        (rank) => List.generate(
          8,
          (file) => _chess.get(indicesToSquare(rank, file)),
        ),
      );

  /// Get all legal moves for current position
  List<chess_lib.Move> getLegalMoves() =>
      _chess.moves({'asObjects': true}).cast<chess_lib.Move>();

  /// Get legal moves for a specific square with detailed information
  List<LegalMove> getLegalMovesForSquareDetailed(String square) =>
      MoveValidationService.getLegalMovesFromSquare(_chess, square);

  /// Get legal moves for a specific square (e.g., "e2")
  List<chess_lib.Move> getLegalMovesForSquare(String square) =>
      getLegalMoves().where((move) => move.fromAlgebraic == square).toList();

  /// Analyze current position for tactical patterns and material balance
  PositionAnalysis analyzePosition() =>
      MoveValidationService.analyzePosition(_chess);

  /// Validate if a move is legal with detailed error reporting
  bool isLegalMove(String from, String to, {String? promotion}) {
    final result = MoveValidationService.validateMove(_chess, from, to,
        promotion: promotion);
    return result.isValid;
  }

  /// Validate move and get detailed error information
  MoveValidationResult validateMoveDetailed(String from, String to,
          {String? promotion}) =>
      MoveValidationService.validateMove(_chess, from, to,
          promotion: promotion);

  /// Make a move (returns true if successful)
  bool makeMove(String from, String to, {String? promotion}) {
    try {
      final result = _chess.move({
        'from': from,
        'to': to,
        if (promotion != null) 'promotion': promotion,
      });
      if (result) {
        // Track move in history for draw detection
        _moveHistory.add({
          'from': from,
          'to': to,
          'promotion': promotion,
        });
      }
      return result;
    } catch (e) {
      return false;
    }
  }

  /// Make a move using standard notation (e.g., "e2e4")
  bool makeMoveUCI(String uci) {
    try {
      if (uci.length < 4) return false;
      final from = uci.substring(0, 2);
      final to = uci.substring(2, 4);
      final promotion = uci.length > 4 ? uci[4] : null;
      return makeMove(from, to, promotion: promotion);
    } catch (e) {
      return false;
    }
  }

  /// Undo the last move
  bool undoMove() {
    try {
      if (_moveHistory.isEmpty) return false;
      final undone = _chess.undo_move();
      if (undone == null) return false;
      _moveHistory.removeLast();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Check if the current position is checkmate
  bool isCheckmate() => _chess.in_checkmate;

  /// Check if the current position is stalemate
  bool isStalemate() => _chess.in_stalemate;

  /// Check if the current position is check
  bool isCheck() => _chess.in_check;

  /// Check if the game is over
  bool isGameOver() => _chess.game_over;

  /// Get game result (white win, black win, draw)
  String? getGameResult() {
    if (!isGameOver()) return null;

    if (isCheckmate()) {
      return _chess.turn == chess_lib.Color.WHITE ? 'black_win' : 'white_win';
    } else if (DrawDetectionService.canClaimDraw(
        _chess, _chess.fen, _moveHistory)) {
      return 'draw';
    }
    return null;
  }

  /// Get draw reasons if game is a draw
  List<String> getDrawReasons() =>
      DrawDetectionService.getDrawReasons(_chess, _chess.fen, _moveHistory);

  /// Check if player can claim draw
  bool canClaimDraw() =>
      DrawDetectionService.canClaimDraw(_chess, _chess.fen, _moveHistory);

  /// Get whose turn it is (true = white, false = black)
  bool isWhiteTurn() => _chess.turn == chess_lib.Color.WHITE;

  /// Get piece at a specific square
  chess_lib.Piece? getPieceAt(String square) {
    try {
      return _chess.get(square);
    } catch (e) {
      return null;
    }
  }

  /// Get move history as PGN
  String getPgnMoves() => _chess.moves().toString();

  /// Get detailed move information
  List<Map<String, dynamic>> getMoveHistory() =>
      _chess.moves({'verbose': true}).cast<Map<String, dynamic>>().toList();

  /// Get best moves for CPU (simple evaluation)
  List<chess_lib.Move> getBestMoves({int depth = 2}) {
    final allMoves = getLegalMoves();
    if (allMoves.isEmpty) return [];

    // Simple evaluation: prefer captures and checks
    final scoredMoves = allMoves.map((move) {
      int score = 0;

      // Bonus for captures, scaled by the captured piece's value
      final captured = move.captured;
      if (captured == chess_lib.PieceType.PAWN) score += 1;
      if (captured == chess_lib.PieceType.KNIGHT) score += 3;
      if (captured == chess_lib.PieceType.BISHOP) score += 3;
      if (captured == chess_lib.PieceType.ROOK) score += 5;
      if (captured == chess_lib.PieceType.QUEEN) score += 9;

      // Apply move temporarily to check if it gives check
      _chess.move(move);
      if (isCheck()) score += 2;
      _chess.undo_move();

      return MapEntry(move, score);
    }).toList();

    // Sort by score and return top moves
    scoredMoves.sort((a, b) => b.value.compareTo(a.value));
    return scoredMoves.take(3).map((e) => e.key).toList();
  }

  /// Get a random legal move
  chess_lib.Move? getRandomMove() {
    final moves = getLegalMoves();
    if (moves.isEmpty) return null;
    moves.shuffle();
    return moves.first;
  }

  /// Reset the game
  void reset() {
    _chess = chess_lib.Chess();
    _moveHistory.clear();
  }

  /// Load position from FEN
  bool loadFromFen(String fen) {
    try {
      _chess = chess_lib.Chess.fromFEN(fen);
      _moveHistory.clear();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Load position from FEN and move history
  bool loadFromFenAndMoves(
      String startingFen, List<Map<String, dynamic>> moves) {
    try {
      _chess = chess_lib.Chess.fromFEN(startingFen);
      _moveHistory.clear();

      for (final moveData in moves) {
        final from = moveData['from'] as String;
        final to = moveData['to'] as String;
        final promotion = moveData['promotion'] as String?;

        final moveMap = <String, String>{
          'from': from,
          'to': to,
          if (promotion != null) 'promotion': promotion,
        };

        if (!_chess.move(moveMap)) {
          return false;
        }
        _moveHistory.add(moveData);
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Convert square name to board indices
  static Map<String, int> squareToIndices(String square) => {
        'file': square.codeUnitAt(0) - 'a'.codeUnitAt(0),
        'rank': 8 - (int.parse(square[1])),
      };

  /// Convert board indices to square name
  static String indicesToSquare(int rank, int file) =>
      String.fromCharCode('a'.codeUnitAt(0) + file) + (8 - rank).toString();
}
