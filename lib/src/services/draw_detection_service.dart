import 'package:chess/chess.dart' as chess_lib;

/// Service for detecting various draw conditions in chess
class DrawDetectionService {
  /// Check if position is in stalemate
  static bool isStalemate(chess_lib.Chess chess) => chess.in_stalemate;

  static const _files = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];

  /// Check if position has insufficient material for checkmate
  static bool isInsufficientMaterial(chess_lib.Chess chess) {
    try {
      // Count all pieces on the board (piece.type.name is the single-letter
      // code, e.g. 'k', 'n', 'b' — see chess_lib.PieceType).
      final pieces = <String>[];
      for (final file in _files) {
        for (var rank = 1; rank <= 8; rank++) {
          final piece = chess.get('$file$rank');
          if (piece != null) {
            pieces.add(piece.type.name);
          }
        }
      }

      // Insufficient material if only kings remain
      if (pieces.isEmpty) {
        return true;
      }

      // Insufficient material: K vs K, K+N vs K, K+B vs K
      if (pieces.every((p) => p == 'k' || p == 'n')) {
        return true;
      }

      if (pieces.every((p) => p == 'k' || p == 'b')) {
        return true;
      }

      // King and knight vs king
      if (pieces.where((p) => p == 'k').length == 2 &&
          pieces.where((p) => p == 'n').length == 1) {
        return true;
      }

      // King and bishop vs king
      if (pieces.where((p) => p == 'k').length == 2 &&
          pieces.where((p) => p == 'b').length == 1) {
        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Check if 50-move rule draw is applicable
  static bool isFiftyMoveRuleDraw(String fen) {
    try {
      // Extract halfmove clock from FEN (5th field)
      final parts = fen.split(' ');
      if (parts.length < 5) return false;

      final halfmoveClock = int.tryParse(parts[4]) ?? 0;
      return halfmoveClock >= 100; // 100 halfmoves = 50 full moves
    } catch (e) {
      return false;
    }
  }

  /// Check if threefold repetition draw is applicable
  static bool isThreefoldRepetition(
      List<Map<String, dynamic>> moves, String currentFen) {
    try {
      if (moves.isEmpty) return false;

      // Count FEN occurrences by replaying game
      final fenHistory = <String>[];
      final chess = chess_lib.Chess();
      fenHistory.add(chess.fen);

      for (final moveData in moves) {
        final from = moveData['from'] as String;
        final to = moveData['to'] as String;
        final promotion = moveData['promotion'] as String?;

        final moveMap = <String, String>{
          'from': from,
          'to': to,
          if (promotion != null) 'promotion': promotion,
        };

        if (!chess.move(moveMap)) {
          break;
        }
        fenHistory.add(chess.fen);
      }

      // Count occurrences of current FEN
      final currentFenCount = fenHistory.where((f) => f == currentFen).length;
      return currentFenCount >= 3;
    } catch (e) {
      return false;
    }
  }

  /// Get all applicable draw reasons for current position
  static List<String> getDrawReasons(
    chess_lib.Chess chess,
    String fen,
    List<Map<String, dynamic>> moves,
  ) {
    final reasons = <String>[];

    if (isStalemate(chess)) {
      reasons.add('stalemate');
    }

    if (isInsufficientMaterial(chess)) {
      reasons.add('insufficient_material');
    }

    if (isFiftyMoveRuleDraw(fen)) {
      reasons.add('fifty_move_rule');
    }

    if (isThreefoldRepetition(moves, fen)) {
      reasons.add('threefold_repetition');
    }

    return reasons;
  }

  /// Check if game ends in draw based on rules
  static bool canClaimDraw(
    chess_lib.Chess chess,
    String fen,
    List<Map<String, dynamic>> moves,
  ) {
    // Stalemate is automatic draw
    if (isStalemate(chess)) return true;

    // Insufficient material is automatic draw
    if (isInsufficientMaterial(chess)) return true;

    // 50-move rule: draw can be claimed after 50 full moves
    if (isFiftyMoveRuleDraw(fen)) return true;

    // Threefold repetition: draw can be claimed
    if (isThreefoldRepetition(moves, fen)) return true;

    return false;
  }
}
