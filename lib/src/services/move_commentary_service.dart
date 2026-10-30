import 'package:chess/chess.dart' as chess_lib;

import '../../l10n/app_localizations.dart';
import '../models/game_analysis.dart';

/// Turns a single [MoveAnalysis] into a plain-language sentence, in the
/// style of chess.com's "Game Review"/lichess's game analysis ("You missed
/// a fork", "This move hangs the rook") - but deterministic and templated,
/// not LLM-generated, since this app has no LLM backend at all (see
/// ChessAnalysisService's own doc comment). Every sentence is derived from
/// data [ChessAnalysisService.analyzeGame] already computed (the move's
/// [MoveQuality] tier, its centipawn loss, SAN/capture/check/checkmate
/// flags) plus one cheap extra check done here: whether the move left one
/// of the mover's own pieces hanging for free (see [_findHangingPiece]).
///
/// Pure/static so it's trivially unit-testable without a widget tree -
/// the only "context" it needs is the [AppLocalizations] instance a
/// caller already has from `AppLocalizations.of(context)`.
class MoveCommentaryService {
  const MoveCommentaryService._();

  /// Centipawn-loss sub-thresholds used to pick between e.g. "a small
  /// mistake" and "a game-changing blunder" within the same [MoveQuality]
  /// tier - chosen as round numbers roughly midway through each tier's
  /// own range (mistake: 100-299cp, blunder: 300+cp, per komovia_core's
  /// classifyMoveQuality thresholds).
  static const _mistakeCostlyThresholdCp = 180;
  static const _blunderHugeThresholdCp = 600;

  /// Generates the commentary sentence for [move]. [move.fenAfter] (the
  /// position right after the move, opponent to move) is required to
  /// attempt the "hangs a piece" detection in [_findHangingPiece]; when
  /// it's null (a [MoveAnalysis] built without that extra context) this
  /// falls back to the quality-tier template with no hung-piece naming,
  /// per the task's own fallback requirement.
  static String generate(AppLocalizations l10n, MoveAnalysis move) {
    final san = move.san ?? move.notation;

    if (move.isCheckmate) {
      return l10n.moveCommentaryCheckmate(san);
    }

    final buffer = StringBuffer(_tierSentence(l10n, move));

    if (move.quality == MoveQuality.best || move.quality == MoveQuality.good) {
      final capturedType = move.capturedPieceType;
      if (move.isCapture && capturedType != null) {
        buffer.write(' ');
        buffer.write(
          l10n.moveCommentaryCaptureClause(_pieceName(l10n, capturedType)),
        );
      } else if (move.isCheck) {
        buffer.write(l10n.moveCommentaryCheckClause);
      }
      return buffer.toString();
    }

    // Mistakes/blunders: try to name the exact hanging piece - this is
    // the highest-value case the task calls out, matching chess.com's
    // "This move hangs the rook" style, so it takes priority over the
    // generic tier template when it's cheaply detectable.
    final fenAfter = move.fenAfter;
    if (fenAfter != null &&
        (move.quality == MoveQuality.mistake ||
            move.quality == MoveQuality.blunder)) {
      final hanging = _findHangingPiece(fenAfter);
      if (hanging != null) {
        final pieceName = _pieceName(l10n, hanging.pieceType);
        return move.quality == MoveQuality.blunder
            ? l10n.moveCommentaryHangsPieceBlunder(pieceName, hanging.square)
            : l10n.moveCommentaryHangsPieceMistake(pieceName, hanging.square);
      }
    }

    return buffer.toString();
  }

  static String _tierSentence(AppLocalizations l10n, MoveAnalysis move) {
    switch (move.quality) {
      case MoveQuality.best:
        // A "forced" move (very few legal alternatives) is framed as the
        // only reasonable option rather than simply "best", since there
        // was nothing else to meaningfully compare it against - cheap to
        // detect since ChessAnalysisService already counted legal moves
        // before this one was played.
        final legalMoveCount = move.legalMoveCountBefore;
        if (legalMoveCount != null && legalMoveCount <= 2) {
          return l10n.moveCommentaryBestForced;
        }
        return l10n.moveCommentaryBest;
      case MoveQuality.good:
        return l10n.moveCommentaryGood;
      case MoveQuality.inaccuracy:
        return l10n.moveCommentaryInaccuracy;
      case MoveQuality.mistake:
        return move.centipawnLoss >= _mistakeCostlyThresholdCp
            ? l10n.moveCommentaryMistakeCostly
            : l10n.moveCommentaryMistakeSmall;
      case MoveQuality.blunder:
        return move.centipawnLoss >= _blunderHugeThresholdCp
            ? l10n.moveCommentaryBlunderHuge
            : l10n.moveCommentaryBlunderDecisive;
    }
  }

  static String _pieceName(AppLocalizations l10n, String pieceTypeLetter) {
    switch (pieceTypeLetter) {
      case 'p':
        return l10n.moveCommentaryPiecePawn;
      case 'n':
        return l10n.moveCommentaryPieceKnight;
      case 'b':
        return l10n.moveCommentaryPieceBishop;
      case 'r':
        return l10n.moveCommentaryPieceRook;
      case 'q':
        return l10n.moveCommentaryPieceQueen;
      case 'k':
      default:
        return l10n.moveCommentaryPieceKing;
    }
  }

  static const _pieceValues = <String, int>{
    'p': 1,
    'n': 3,
    'b': 3,
    'r': 5,
    'q': 9,
  };

  /// Cheap ("SEE depth 1") check for whether [fenAfter] - the position
  /// right after the mover's move, with the opponent to move - leaves any
  /// of the mover's own pieces attacked and genuinely undefended (no
  /// recapture available at all), rather than merely traded off evenly.
  ///
  /// This deliberately does NOT build a full tactic-detection engine (no
  /// deeper search, no discovered-attack/pin/fork classification) - it
  /// only answers "is there a free piece sitting there right now", which
  /// is exactly what "this move hangs the rook" means and is cheap enough
  /// to run on every mistake/blunder in a full-game analysis: at most one
  /// extra legal-move generation per opponent capture candidate (there are
  /// rarely more than a few).
  ///
  /// Returns the highest-value piece found hanging this way, or null if
  /// none is found (every attacked piece has a defender, or there is
  /// nothing new to capture) - callers fall back to the generic
  /// quality-tier template in that case.
  static _HangingPiece? _findHangingPiece(String fenAfter) {
    chess_lib.Chess position;
    try {
      position = chess_lib.Chess.fromFEN(fenAfter);
    } catch (_) {
      return null;
    }

    // It's the opponent's turn in fenAfter; their legal captures are the
    // candidates for "what did this move just hang".
    final opponentMoves =
        position.moves({'asObjects': true}).cast<chess_lib.Move>();
    final captures = opponentMoves.where((m) => m.captured != null).toList();
    if (captures.isEmpty) return null;

    _HangingPiece? best;
    for (final capture in captures) {
      final capturedType = capture.captured!;
      // The king is never "hanging" via a legal capture - if it could be
      // captured, the position would already be checkmate, which is
      // handled separately in generate().
      if (capturedType == chess_lib.PieceType.KING) continue;

      final afterCapture = chess_lib.Chess.fromFEN(fenAfter);
      if (!afterCapture.move(capture)) continue;

      // Now it's the original mover's turn again - if they have any
      // legal move that recaptures on the very same square, the piece
      // wasn't hanging for free (it was at least defended, even if the
      // trade isn't perfectly equal - a deeper SEE would be needed to
      // judge that, which is out of scope per the task's own "only if
      // cheap" guidance).
      final recaptureSquare = capture.toAlgebraic;
      final defenderMoves =
          afterCapture.moves({'asObjects': true}).cast<chess_lib.Move>();
      final isDefended =
          defenderMoves.any((m) => m.toAlgebraic == recaptureSquare);
      if (isDefended) continue;

      final value = _pieceValues[capturedType.name] ?? 0;
      if (best == null || value > best.value) {
        best = _HangingPiece(
          pieceType: capturedType.name,
          square: recaptureSquare,
          value: value,
        );
      }
    }

    return best;
  }
}

class _HangingPiece {
  const _HangingPiece({
    required this.pieceType,
    required this.square,
    required this.value,
  });

  final String pieceType;
  final String square;
  final int value;
}
