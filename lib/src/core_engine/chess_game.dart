import 'package:chess/chess.dart' as chess_lib;
import 'package:komovia_core/komovia_core.dart';

import 'chess_position.dart';

/// Chess, implementing komovia_core's [Game] over the `chess` pub package
/// (`chess_lib.Chess`) that `ChessEngineService`/`CpuGameState` already
/// build the entire app's rules/move-generation on top of — this adapter
/// is a thin wrapper around the same library, not a new rules
/// implementation.
///
/// The only [Move] kind chess ever produces is [BoardMove] — chess has no
/// drop (see `move.dart`'s own doc comment: "shogi has no pass" and
/// implicitly, chess has no drop either) and no pass; [ResignMove] is
/// supported like every other game, per `Game.apply`'s own contract.
class ChessGame implements Game<ChessPosition> {
  @override
  String get id => 'chess';

  /// [options] is currently unused — chess has no established "setup
  /// variant" equivalent to go's board size or shogi/go's handicap (see
  /// `ChessHandicapRule`'s absence, explained in this package's barrel
  /// doc comment), so every key is ignored and the standard starting
  /// position is always returned, matching
  /// `Game.initialPosition`'s own "ignore keys they don't recognize"
  /// contract.
  @override
  ChessPosition initialPosition({Map<String, Object?> options = const {}}) {
    return const ChessPosition(fen: chess_lib.Chess.DEFAULT_POSITION);
  }

  /// A cheap key for repetition: FEN's first four space-separated fields
  /// (piece placement, side to move, castling rights, en-passant target)
  /// — deliberately excluding the halfmove clock and fullmove number
  /// (FEN fields 5-6), which must NOT affect "is this the same position"
  /// for threefold-repetition purposes. See [result] below, which counts
  /// occurrences of this key in `historyKeys` exactly the way
  /// `ShogiGame.result` counts occurrences of its own `positionKey` for
  /// 千日手.
  @override
  Object positionKey(ChessPosition position) {
    final fields = position.fen.split(' ');
    return fields.sublist(0, 4).join(' ');
  }

  @override
  List<Move> legalMoves(
    ChessPosition position, {
    List<Object> historyKeys = const [],
  }) {
    if (!result(position, historyKeys: historyKeys).isOngoing) return const [];

    final chess = position.toChess();
    final moves = <Move>[];
    // chess_lib.generate_moves() emits 4 separate Move objects per
    // promotable pawn move (one per promotion piece: Q/R/B/N — see
    // chess.dart's own `add_move`), but core's BoardMove.promote is only
    // a bool, with no slot for which piece. Dedupe to one BoardMove per
    // (from, to): see this file's class comment on [apply] for how the
    // promotion piece itself is then chosen.
    final seen = <String>{};
    for (final m in chess.generate_moves()) {
      final key = '${m.fromAlgebraic}${m.toAlgebraic}';
      if (!seen.add(key)) continue;
      moves.add(BoardMove(
        from: squareFromAlgebraic(m.fromAlgebraic),
        to: squareFromAlgebraic(m.toAlgebraic),
        promote: m.promotion != null,
      ));
    }
    return moves;
  }

  /// Known gap: [BoardMove.promote] is a bool, so it cannot carry *which*
  /// piece a pawn promotes to — chess is the first of the three sibling
  /// games (shogi/go/chess) that needs underpromotion choice at all, and
  /// komovia_core's [Move] shape (shared across all three) has no slot
  /// for it. Every promotion here defaults to queen ("auto-queen"), the
  /// standard simplification used when a UI doesn't ask for a choice.
  /// This is purely a limitation of this thin adapter layer — the app's
  /// own real board/puzzle screens (`GameBoard._showPromotionDialog`)
  /// already let a player choose any of Q/R/B/N and are completely
  /// unaffected, since nothing in the app imports this adapter yet.
  @override
  ChessPosition apply(
    ChessPosition position,
    Move move, {
    List<Object> historyKeys = const [],
  }) {
    switch (move) {
      case ResignMove(side: final side):
        return position.copyWith(resignedBy: side);

      case BoardMove(from: final from, to: final to, promote: final promote):
        final chess = position.toChess();
        final ok = chess.move({
          'from': algebraicFromSquare(from),
          'to': algebraicFromSquare(to),
          if (promote) 'promotion': 'q',
        });
        if (!ok) {
          throw ArgumentError('Illegal move $move on $position');
        }
        return ChessPosition(fen: chess.fen, resignedBy: position.resignedBy);

      case DropMove():
        throw ArgumentError('Chess has no drop move: $move');

      case PassMove():
        throw ArgumentError('Chess has no pass move: $move');
    }
  }

  /// Threefold-repetition threshold: a position (per [positionKey],
  /// i.e. ignoring move counters) recurring 3 times ends the game as an
  /// automatic draw. This is the FIDE rule as an *automatic* outcome
  /// (matching how `ShogiGame.result` treats 千日手 and how
  /// `DrawDetectionService.canClaimDraw`/`isThreefoldRepetition` already
  /// treat it in the real app — see this package's barrel doc comment
  /// for the full WinReason mapping rationale) rather than a draw a
  /// player must separately claim.
  static const _repetitionThreshold = 3;

  @override
  GameResult result(
    ChessPosition position, {
    List<Object> historyKeys = const [],
  }) {
    if (position.resignedBy != null) {
      return GameResult.win(position.resignedBy!.opponent, WinReason.resignation);
    }

    final chess = position.toChess();

    if (chess.in_checkmate) {
      return GameResult.win(position.sideToMove.opponent, WinReason.checkmate);
    }
    if (chess.in_stalemate) {
      return const GameResult.draw(WinReason.stalemate);
    }
    // Insufficient material and the fifty-move rule are both automatic
    // draws with no dedicated WinReason case in komovia_core (unlike
    // go/shogi, which never needed one) — see the barrel doc comment for
    // the full reasoning on why WinReason.agreement is reused here rather
    // than WinReason.repetition or .stalemate.
    if (chess.insufficient_material) {
      return const GameResult.draw(WinReason.agreement);
    }
    if (chess.half_moves >= 100) {
      return const GameResult.draw(WinReason.agreement);
    }

    final key = positionKey(position);
    if (historyKeys.where((k) => k == key).length >= _repetitionThreshold) {
      return const GameResult.draw(WinReason.repetition);
    }

    return GameResult.ongoing;
  }

  /// A single-position FEN snapshot — chess's standard notation, and
  /// exactly what `ChessPosition.fen` already stores, so this is an
  /// identity projection (see [decode] for the inverse, which re-validates
  /// rather than trusting the string blindly).
  @override
  String encode(ChessPosition position) => position.fen;

  @override
  ChessPosition decode(String notation) {
    final validation = chess_lib.Chess.validate_fen(notation);
    if (validation['valid'] != true) {
      throw FormatException('Invalid FEN (${validation['error']}): $notation');
    }
    return ChessPosition(fen: chess_lib.Chess.fromFEN(notation).fen);
  }

  /// Real PGN (Portable Game Notation, chess's standard kifu format),
  /// built by replaying [record]'s moves through a fresh `chess_lib.Chess`
  /// so its own `pgn()` (numbered SAN move text) comes out correct. The
  /// `Result` header is the standard PGN result token (`1-0`/`0-1`/
  /// `1/2-1/2`); a non-standard `Termination` header additionally carries
  /// [GameResult.reason]'s own name (e.g. `checkmate`, `agreement`) so
  /// [importRecord] can round-trip the *exact* [GameResult] rather than
  /// just the win/lose/draw outcome a bare PGN Result tag can express —
  /// the same "round-trip the whole GameResult through one extra property
  /// in the game's own notation" approach `GoGame.exportRecord` takes
  /// with SGF's `RE[...]`, using PGN's own native arbitrary-tag mechanism
  /// instead of SGF's bracket-append hack.
  @override
  String exportRecord(GameRecord record) {
    final chess = record.initialPositionNotation != null
        ? chess_lib.Chess.fromFEN(record.initialPositionNotation!)
        : chess_lib.Chess();

    for (final recorded in record.moves) {
      switch (recorded.move) {
        case BoardMove(from: final from, to: final to, promote: final promote):
          final ok = chess.move({
            'from': algebraicFromSquare(from),
            'to': algebraicFromSquare(to),
            if (promote) 'promotion': 'q',
          });
          if (!ok) {
            throw ArgumentError('Illegal recorded move to export: $recorded');
          }
        case ResignMove():
        case PassMove():
        case DropMove():
          throw ArgumentError('Unsupported move to export for chess: $recorded');
      }
    }

    final resultToken = _resultToken(record.result);
    if (resultToken != null) {
      chess.set_header(['Result', resultToken]);
      final reason = record.result.reason;
      if (reason != null) {
        chess.set_header(['Termination', reason.name]);
      }
    }

    return chess.pgn();
  }

  static String? _resultToken(GameResult result) {
    switch (result.kind) {
      case ResultKind.ongoing:
        return null;
      case ResultKind.draw:
        return '1/2-1/2';
      case ResultKind.win:
        return result.winner == Side.first ? '1-0' : '0-1';
    }
  }

  static WinReason? _winReasonFromToken(String? token) {
    if (token == null) return null;
    for (final reason in WinReason.values) {
      if (reason.name == token) return reason;
    }
    return null;
  }

  @override
  GameRecord importRecord(String notation) {
    final chess = chess_lib.Chess();
    if (!chess.load_pgn(notation)) {
      throw FormatException('Not a valid PGN game record: $notation');
    }

    final moves = <RecordedMove>[];
    for (var i = 0; i < chess.history.length; i++) {
      final halfMove = chess.history[i].move;
      final side = halfMove.color == chess_lib.Color.WHITE ? Side.first : Side.second;
      final move = BoardMove(
        from: squareFromAlgebraic(halfMove.fromAlgebraic),
        to: squareFromAlgebraic(halfMove.toAlgebraic),
        promote: halfMove.promotion != null,
      );
      moves.add(RecordedMove(number: i + 1, side: side, move: move));
    }

    final resultToken = chess.header['Result'] as String?;
    final reasonToken = chess.header['Termination'] as String?;
    GameResult result;
    switch (resultToken) {
      case null:
        // No Result tag at all: fall back to reading it straight off the
        // final replayed position, same as GoGame.importRecord's own
        // fallback (without historyKeys — a PGN file alone carries no
        // ancestor-position list, so repetition can't be re-detected
        // this way; this only affects a record that ended specifically
        // by repetition and was re-imported with no Result tag, which
        // this adapter's own [exportRecord] never produces).
        result = this.result(ChessPosition(fen: chess.fen));
      case '1/2-1/2':
        result = GameResult.draw(_winReasonFromToken(reasonToken) ?? WinReason.agreement);
      case '1-0':
        result = GameResult.win(Side.first, _winReasonFromToken(reasonToken) ?? WinReason.checkmate);
      case '0-1':
        result = GameResult.win(Side.second, _winReasonFromToken(reasonToken) ?? WinReason.checkmate);
      default:
        // '*' (unknown/ongoing) or anything unrecognized.
        result = GameResult.ongoing;
    }

    return GameRecord(gameId: id, moves: moves, result: result);
  }
}

/// Converts a `chess_lib` algebraic square (e.g. `'e4'`) to komovia_core's
/// [Square]. `Square`'s own doc comment says coordinates are "zero-indexed
/// from the top-left corner" with no fixed orientation of its own, so this
/// simply reuses `chess_lib`'s own 0x88-derived file/rank numbering
/// (`Chess.file`/`Chess.rank`: file 0 = the a-file, rank 0 = the 8th rank)
/// rather than inventing a different convention — rank 0 at the top
/// matches every other board screen in this app, which always draws the
/// 8th rank at the top regardless of which side is "down".
Square squareFromAlgebraic(String algebraic) => Square(
      algebraic.codeUnitAt(0) - 'a'.codeUnitAt(0),
      8 - int.parse(algebraic[1]),
    );

/// The inverse of [squareFromAlgebraic].
String algebraicFromSquare(Square square) =>
    String.fromCharCode('a'.codeUnitAt(0) + square.file) + (8 - square.rank).toString();
