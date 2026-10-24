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
      // code, e.g. 'k', 'n', 'b' — see chess_lib.PieceType), and each
      // bishop's own square color (needed below - same-colored bishops
      // can never force mate, opposite-colored ones can).
      final pieces = <String>[];
      final bishopSquaresAreLight = <bool>[];
      for (var fileIndex = 0; fileIndex < _files.length; fileIndex++) {
        for (var rank = 1; rank <= 8; rank++) {
          final piece = chess.get('${_files[fileIndex]}$rank');
          if (piece != null) {
            pieces.add(piece.type.name);
            if (piece.type.name == 'b') {
              // Standard light/dark square parity: (file + rank) even
              // = dark, odd = light (a1 is dark: file 0 + rank 1 = 1,
              // odd -> light... a1 is actually dark in real chess, so
              // this is just an internal, self-consistent parity label
              // - what matters is that two bishops compare equal here
              // iff they're genuinely on the same color square).
              bishopSquaresAreLight.add((fileIndex + rank).isOdd);
            }
          }
        }
      }

      // Insufficient material: K vs K, K+N vs K, K+B vs K. The
      // `pieces.length == 3` guard on the knight check is load-bearing,
      // not redundant with the "every piece is k or n" check further
      // up: without it, a position like K+N+B vs K (a real forced-mate
      // endgame) passed the knight-count-1 check too (which only
      // counted knights, never checking that no OTHER piece - the
      // bishop - was also on the board), so it was wrongly declared
      // insufficient material. A player reaching that genuinely-winning
      // position against the CPU had the game auto-declared a draw
      // instead of being able to continue toward checkmate.
      if (pieces.every((p) => p == 'k' || p == 'n')) {
        return true;
      }

      // K+bishops vs K (any number of bishops, on either side) is only
      // automatically drawn when every bishop present shares the same
      // square color - opposite-colored bishops (even just K+B vs K+B)
      // can force mate and are NOT insufficient material. The previous
      // version treated ANY all-kings-and-bishops position as a draw
      // regardless of color, wrongly auto-drawing e.g. K+B+B vs K with
      // the two bishops on opposite colors (also a real forced-mate
      // endgame).
      if (pieces.every((p) => p == 'k' || p == 'b') &&
          bishopSquaresAreLight.toSet().length <= 1) {
        return true;
      }

      // King and knight vs king
      if (pieces.length == 3 &&
          pieces.where((p) => p == 'k').length == 2 &&
          pieces.where((p) => p == 'n').length == 1) {
        return true;
      }

      // King and bishop vs king
      if (pieces.length == 3 &&
          pieces.where((p) => p == 'k').length == 2 &&
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

  /// The first 4 space-separated FEN fields (piece placement, side to
  /// move, castling rights, en passant target) - the actual "position"
  /// for repetition purposes. The 5th/6th fields (halfmove clock,
  /// fullmove number) strictly increase every move and can never repeat
  /// even when the same position genuinely recurs, so comparing full
  /// FEN strings (as this function used to) meant currentFenCount could
  /// essentially never reach 3 - the feature was dead in practice.
  static String _positionKey(String fen) {
    final parts = fen.split(' ');
    return parts.length >= 4 ? parts.sublist(0, 4).join(' ') : fen;
  }

  /// Check if threefold repetition draw is applicable.
  ///
  /// [startingFen] is the position [moves] were played from - defaults
  /// to the standard starting array for callers that always start
  /// there (e.g. online games). Replaying from a brand-new
  /// `chess_lib.Chess()` regardless of the game's real start (the
  /// previous behavior) is wrong for any game started from a custom
  /// position - cpu_game_provider.dart's `initGame({startingFen})`
  /// supports curated midgame/endgame practice positions, and the
  /// recorded moves are legal against that position, not the default
  /// array, so replaying them from the wrong start made `chess.move()`
  /// fail immediately and silently truncated positionHistory - making
  /// threefold repetition effectively undetectable for any such game.
  static bool isThreefoldRepetition(
      List<Map<String, dynamic>> moves, String currentFen,
      {String? startingFen}) {
    try {
      if (moves.isEmpty) return false;

      // Count position occurrences by replaying game
      final positionHistory = <String>[];
      final chess = startingFen != null
          ? chess_lib.Chess.fromFEN(startingFen)
          : chess_lib.Chess();
      positionHistory.add(_positionKey(chess.fen));

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
        positionHistory.add(_positionKey(chess.fen));
      }

      // Count occurrences of the current position
      final currentPositionCount = positionHistory
          .where((p) => p == _positionKey(currentFen))
          .length;
      return currentPositionCount >= 3;
    } catch (e) {
      return false;
    }
  }

  /// Get all applicable draw reasons for current position
  static List<String> getDrawReasons(
    chess_lib.Chess chess,
    String fen,
    List<Map<String, dynamic>> moves, {
    String? startingFen,
  }) {
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

    if (isThreefoldRepetition(moves, fen, startingFen: startingFen)) {
      reasons.add('threefold_repetition');
    }

    return reasons;
  }

  /// Check if game ends in draw based on rules
  static bool canClaimDraw(
    chess_lib.Chess chess,
    String fen,
    List<Map<String, dynamic>> moves, {
    String? startingFen,
  }) {
    // Stalemate is automatic draw
    if (isStalemate(chess)) return true;

    // Insufficient material is automatic draw
    if (isInsufficientMaterial(chess)) return true;

    // 50-move rule: draw can be claimed after 50 full moves
    if (isFiftyMoveRuleDraw(fen)) return true;

    // Threefold repetition: draw can be claimed
    if (isThreefoldRepetition(moves, fen, startingFen: startingFen)) {
      return true;
    }

    return false;
  }
}
