/// Chess's implementation of komovia_core's `Game`/`Engine`/
/// `BoardRenderer`/puzzle-conversion interfaces, adapting komovia_chess's
/// existing chess rules (the `chess` pub package, via `ChessEngineService`/
/// `CpuGameState`), AI (`StockfishEngineService`), and puzzle data
/// (`PuzzleModel`) — mirroring komovia_go's `komovia_go_engine.dart` and
/// komovia_shogi's `komovia_shogi.dart` barrels for Go and Shogi.
///
/// This is an adapter layer only: komovia_chess's actual rules/AI/
/// rendering code is unchanged. Nothing in the app imports this yet — it
/// exists so Chess can be treated the same way Go and Shogi already are
/// through `komovia_core`'s generic interfaces (a shared matching/rating
/// service, a cross-game puzzle-of-the-day, ...), none of which is built
/// here.
///
/// `HandicapRule<ChessPosition>` is deliberately not implemented: unlike
/// shogi's 駒落ち and go's 置き石, komovia_chess has no existing "odds"
/// (removing material / granting extra moves to balance a mismatch)
/// feature anywhere in the app (confirmed by grepping the whole codebase
/// for "handicap"/"odds" — no hits). Following the same precedent
/// go/shogi already set for features genuinely absent elsewhere, this
/// adapter skips the interface rather than inventing a new odds system
/// nobody asked for.
library;

export 'src/core_engine/chess_board_renderer.dart';
export 'src/core_engine/chess_engine.dart';
export 'src/core_engine/chess_game.dart';
export 'src/core_engine/chess_position.dart';
export 'src/core_engine/chess_puzzle.dart';
