import 'package:komovia_core/komovia_core.dart';

import '../services/ai_opponent_engine.dart' show AIDifficulty;
import '../services/stockfish_engine_service.dart';
import 'chess_game.dart';
import 'chess_position.dart';

/// Chess's `Engine<ChessPosition>`, wrapping `StockfishEngineService` —
/// the real native Stockfish binary (via the `stockfish` pub package)
/// every CPU game in the app already plays against. Both of
/// `StockfishEngineService`'s own calls (`getBestMove`/`evaluatePosition`)
/// already run off the UI thread and operate on a plain FEN string, which
/// is exactly what [ChessPosition] already is — no translation layer
/// needed beyond UCI move-string parsing.
class ChessEngine implements Engine<ChessPosition> {
  final StockfishEngineService _stockfish;

  ChessEngine([StockfishEngineService? stockfish])
      : _stockfish = stockfish ?? StockfishEngineService.instance;

  /// No separate downloadable model/evaluation data: the bundled
  /// Stockfish binary is compiled in, like komovia_go's `GoEngine` (which
  /// likewise reports `'builtin'` for the same reason). The engine's own
  /// internal version string isn't surfaced anywhere in
  /// `StockfishEngineService` (it never reads Stockfish's `id name ...`
  /// UCI handshake line), so `'stockfish'` is used as a stable, honest
  /// identifier rather than inventing false precision.
  @override
  String get modelVersion => 'stockfish';

  /// [level] (1 weakest .. 10 strongest, per `Engine.bestMove`'s own
  /// contract) is bucketed onto the app's existing 3-tier
  /// [AIDifficulty] (`easy`/`medium`/`hard`), since that's the only
  /// granularity `StockfishEngineService.configureDifficulty` exposes
  /// (it maps each tier to a fixed `UCI_Elo`/move-time pair — see
  /// `stockfish_engine_service.dart`). [timeBudget], if given, overrides
  /// the difficulty tier's own default move time.
  @override
  Future<Move?> bestMove(
    ChessPosition position, {
    required int level,
    Duration? timeBudget,
  }) async {
    final difficulty = _difficultyForLevel(level);
    await _stockfish.configureDifficulty(difficulty);
    final moveTimeMs = timeBudget?.inMilliseconds ?? difficulty.stockfishMoveTimeMs;
    final uci = await _stockfish.getBestMove(position.fen, moveTimeMs: moveTimeMs);
    if (uci == null || uci.length < 4) return null;

    return BoardMove(
      from: squareFromAlgebraic(uci.substring(0, 2)),
      to: squareFromAlgebraic(uci.substring(2, 4)),
      promote: uci.length > 4,
    );
  }

  static AIDifficulty _difficultyForLevel(int level) {
    final clamped = level.clamp(1, 10);
    if (clamped <= 3) return AIDifficulty.easy;
    if (clamped <= 7) return AIDifficulty.medium;
    return AIDifficulty.hard;
  }

  /// `StockfishEngineService.evaluatePosition`'s centipawn score is
  /// already fixed to White's perspective (positive favors White — see
  /// that method's own doc comment), i.e. [Side.first]'s, matching this
  /// method's contract exactly with no sign flip needed — the same
  /// "no sign flip" situation `GoEngine.evaluate` found for
  /// `FuegoEngineService`.
  @override
  Future<double> evaluate(ChessPosition position) async {
    final centipawns = await _stockfish.evaluatePosition(position.fen);
    return (centipawns ?? 0) / 100.0;
  }

  /// No dedicated mate-search entry point is reachable through
  /// `StockfishEngineService`: it only ever sends `go movetime ...` to
  /// the underlying UCI process, never `go mate <N>` (the UCI command
  /// that would actually ask Stockfish for a forced mate specifically).
  /// `evaluatePosition` *parses* a `score mate N` line when the engine
  /// happens to report one during an ordinary search, but that's an
  /// incidental discovery, not a real mate search, and isn't exposed as
  /// a move anyway. Per `Engine.findForcedWin`'s own doc comment ("null
  /// does not mean none exists"), returning null here is the honest
  /// choice — matching `GoEngine.findForcedWin`'s identical conclusion
  /// for Fuego — rather than faking a search this adapter has no real
  /// access to.
  @override
  Future<Move?> findForcedWin(ChessPosition position, {required int maxPly}) async {
    return null;
  }
}
