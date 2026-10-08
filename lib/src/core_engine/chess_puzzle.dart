import 'package:komovia_core/komovia_core.dart';

import '../models/puzzle.dart';
import 'chess_game.dart';
import 'chess_position.dart';

/// Converts komovia_chess's existing tactics puzzles (`PuzzleModel`) into
/// `komovia_core`'s game-agnostic `Puzzle<ChessPosition>`.
///
/// Unlike komovia_go's `TsumeGoProblem` (a final-position-only snapshot —
/// see `GoPuzzle`'s own doc comment), `PuzzleModel.moves` is a REAL
/// move-by-move solution in UCI notation (its own field comment says so
/// explicitly: "Solution moves in UCI format"), and `puzzle_screen.dart`'s
/// `_handleMove`/the auto-played opponent reply confirm the exact
/// semantics: `moves[0]` is played directly from `puzzle.fen`'s side to
/// move (no opponent "setup" ply to skip), then sides alternate —
/// matching `Puzzle.solution`'s own contract ("alternating sides,
/// starting with position.sideToMove") exactly. [solution] is therefore
/// populated for real, unlike `GoPuzzle.solution`, which had to stay
/// empty for a genuine data-gap reason specific to go's puzzle source.
class ChessPuzzle {
  ChessPuzzle._();

  static final _game = ChessGame();

  static Puzzle<ChessPosition> fromPuzzleModel(
    PuzzleModel puzzle, {
    required String gameId,
  }) {
    final position = _game.decode(puzzle.fen);

    final solution = <Move>[];
    for (final uci in puzzle.moves) {
      if (uci.length < 4) {
        throw FormatException('Invalid UCI move "$uci" in puzzle ${puzzle.id}');
      }
      solution.add(BoardMove(
        from: squareFromAlgebraic(uci.substring(0, 2)),
        to: squareFromAlgebraic(uci.substring(2, 4)),
        // Same auto-queen limitation as ChessGame.apply: BoardMove.promote
        // is a bool and can't carry a specific underpromotion piece, so a
        // 5th UCI character other than 'q' (e.g. "e7e8n") is detected as
        // "this move promotes" but the specific piece is lost. See
        // chess_game.dart's doc comment on [ChessGame.apply].
        promote: uci.length > 4,
      ));
    }

    return Puzzle(
      id: puzzle.id,
      gameId: gameId,
      position: position,
      solution: solution,
      title: puzzle.themes.isNotEmpty ? puzzle.themes.join(', ') : null,
      metadata: {
        'rating': puzzle.rating,
        'themes': puzzle.themes,
        if (puzzle.handCount != null) 'handCount': puzzle.handCount,
      },
    );
  }
}
