import '../models/game_analysis.dart';
import '../models/online_game.dart' show GameMove;
import 'chess_engine_service.dart';
import 'stockfish_engine_service.dart';

/// Exposed so callers that only have an optional/nullable starting FEN
/// can fall back to it explicitly instead of a second hardcoded copy -
/// same convention as GameGifService.standardStartingFen.
const standardStartingFen =
    'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

/// Runs the already-integrated Stockfish engine over every position of a
/// finished game to classify each move's quality. This is the "real"
/// slice of what the family's docs once called AI game analysis - no LLM
/// involved, just the engine eval already wired up for GameReviewScreen's
/// live eval bar, applied move-by-move instead of position-by-position.
class ChessAnalysisService {
  /// [onProgress] is called after each move is evaluated with
  /// (movesAnalyzed, totalMoves), for a progress indicator - evaluating a
  /// full game is one engine call per move and can take several seconds.
  Future<GameAnalysis> analyzeGame(
    List<GameMove> moves, {
    String startingFen = standardStartingFen,
    int moveTimeMs = 200,
    void Function(int done, int total)? onProgress,
  }) async {
    await StockfishEngineService.instance.initialize();

    final chess = ChessEngineService()..initGame(fen: startingFen);
    final analyses = <MoveAnalysis>[];

    final firstRaw = await StockfishEngineService.instance
        .evaluatePosition(chess.getCurrentFen(), moveTimeMs: moveTimeMs);
    int evalBefore =
        firstRaw == null ? 0 : (chess.isWhiteTurn() ? firstRaw : -firstRaw);

    for (var i = 0; i < moves.length; i++) {
      final move = moves[i];
      final isWhiteMove = i.isEven;

      final legalMoveCountBefore = chess.getLegalMoves().length;

      // Pass moves (sentinel row/col -1 encoded elsewhere in this app)
      // never reach here since GameMove.from/to are always real squares
      // for a recorded chess move; a malformed entry is skipped rather
      // than aborting the whole analysis.
      if (!chess.makeMove(move.from, move.to, promotion: move.promotion)) {
        continue;
      }

      // The verbose history entry chess_lib just recorded for the move
      // we made above - carries its real SAN (with capture/check/mate
      // suffixes already resolved) so MoveCommentaryService doesn't need
      // to re-derive move classification from scratch.
      final historyEntry = chess.getMoveHistory().last;
      final san = historyEntry['san'] as String?;
      final capturedPieceType = historyEntry['captured']?.toString();
      final isCapture = capturedPieceType != null;
      final isCheckmate = chess.isCheckmate();
      final isCheck = chess.isCheck();

      final fenAfter = chess.getCurrentFen();
      final evalAfterRaw = await StockfishEngineService.instance
          .evaluatePosition(fenAfter, moveTimeMs: moveTimeMs);

      // evaluatePosition is always from the side-to-move's perspective -
      // normalize both readings to "White's perspective" so a single
      // signed centipawn-loss calculation works regardless of whose turn
      // it was (same normalization GameReviewScreen's eval bar already
      // does).
      final evalAfterWhite = evalAfterRaw == null
          ? evalBefore
          : (chess.isWhiteTurn() ? evalAfterRaw : -evalAfterRaw);

      final lossFromMover = isWhiteMove
          ? evalBefore - evalAfterWhite
          : evalAfterWhite - evalBefore;
      final centipawnLoss = lossFromMover < 0 ? 0 : lossFromMover;

      analyses.add(MoveAnalysis(
        moveIndex: i,
        notation: move.notation,
        isWhiteMove: isWhiteMove,
        evalBeforeCp: evalBefore,
        evalAfterCp: evalAfterWhite,
        centipawnLoss: centipawnLoss,
        quality: classifyMoveQuality(centipawnLoss.toDouble()),
        san: san,
        isCapture: isCapture,
        isCheck: isCheck,
        isCheckmate: isCheckmate,
        capturedPieceType: capturedPieceType,
        legalMoveCountBefore: legalMoveCountBefore,
        fenAfter: fenAfter,
      ));

      evalBefore = evalAfterWhite;
      onProgress?.call(i + 1, moves.length);
    }

    return GameAnalysis(
      moves: analyses,
      whiteAccuracy: _accuracyFor(analyses, isWhite: true),
      blackAccuracy: _accuracyFor(analyses, isWhite: false),
    );
  }

  double _accuracyFor(List<MoveAnalysis> analyses, {required bool isWhite}) {
    final sideMoves =
        analyses.where((m) => m.isWhiteMove == isWhite).toList();
    if (sideMoves.isEmpty) return 100;

    final goodCount = sideMoves
        .where((m) =>
            m.quality == MoveQuality.best || m.quality == MoveQuality.good)
        .length;
    return goodCount / sideMoves.length * 100;
  }
}
