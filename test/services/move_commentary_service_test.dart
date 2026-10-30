import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_chess/l10n/app_localizations_en.dart';
import 'package:komovia_chess/src/models/game_analysis.dart';
import 'package:komovia_chess/src/services/move_commentary_service.dart';

/// A position where it's Black's turn and White's rook on d4 (just played
/// there, hanging) is attacked by Black's bishop on g7 with nothing of
/// White's able to recapture on d4 - a genuine "hangs the rook for free"
/// fixture for [MoveCommentaryService]'s cheap hanging-piece detection.
const _hangsRookFen = '4k3/6b1/8/8/3R4/8/8/4K3 b - - 0 1';

/// Same idea, but White's king sits on d3 - adjacent to d4 - so after
/// ...Bxd4 White can recapture Kxd4. The rook trades evenly instead of
/// hanging for free, so this must NOT be reported as a hanging piece.
const _defendedRookFen = '4k3/6b1/8/8/3R4/3K4/8/8 b - - 0 1';

/// A quiet position with no captures available for Black at all - used
/// to confirm the hanging-piece check safely finds nothing rather than
/// false-positiving, so blunder/mistake commentary falls back to the
/// generic quality-tier template.
const _quietFen = '4k3/8/8/8/8/8/8/4K3 b - - 0 1';

void main() {
  final l10n = AppLocalizationsEn();

  MoveAnalysis move({
    required MoveQuality quality,
    int centipawnLoss = 0,
    bool isCapture = false,
    bool isCheck = false,
    bool isCheckmate = false,
    String? capturedPieceType,
    int? legalMoveCountBefore,
    String? fenAfter,
    String? san,
  }) =>
      MoveAnalysis(
        moveIndex: 10,
        notation: 'e4-e5',
        isWhiteMove: true,
        evalBeforeCp: 0,
        evalAfterCp: -centipawnLoss,
        centipawnLoss: centipawnLoss,
        quality: quality,
        san: san,
        isCapture: isCapture,
        isCheck: isCheck,
        isCheckmate: isCheckmate,
        capturedPieceType: capturedPieceType,
        legalMoveCountBefore: legalMoveCountBefore,
        fenAfter: fenAfter,
      );

  group('MoveCommentaryService.generate - quality tiers', () {
    test('best move with several alternatives reads as simply the best',
        () {
      final result = MoveCommentaryService.generate(
        l10n,
        move(quality: MoveQuality.best, legalMoveCountBefore: 20),
      );
      expect(result, l10n.moveCommentaryBest);
    });

    test('best move with only one or two legal options reads as forced',
        () {
      final result = MoveCommentaryService.generate(
        l10n,
        move(quality: MoveQuality.best, legalMoveCountBefore: 1),
      );
      expect(result, l10n.moveCommentaryBestForced);
    });

    test('good move (no capture/check) reads as a plain good move', () {
      final result = MoveCommentaryService.generate(
        l10n,
        move(quality: MoveQuality.good, centipawnLoss: 30),
      );
      expect(result, l10n.moveCommentaryGood);
    });

    test('inaccuracy reads as an inaccuracy', () {
      final result = MoveCommentaryService.generate(
        l10n,
        move(quality: MoveQuality.inaccuracy, centipawnLoss: 70),
      );
      expect(result, l10n.moveCommentaryInaccuracy);
    });

    test('a small mistake (just over the mistake threshold) is worded as'
        ' small', () {
      final result = MoveCommentaryService.generate(
        l10n,
        move(quality: MoveQuality.mistake, centipawnLoss: 110),
      );
      expect(result, l10n.moveCommentaryMistakeSmall);
    });

    test('a costly mistake (well into the mistake range) is worded as'
        ' costly', () {
      final result = MoveCommentaryService.generate(
        l10n,
        move(quality: MoveQuality.mistake, centipawnLoss: 250),
      );
      expect(result, l10n.moveCommentaryMistakeCostly);
    });

    test('a decisive blunder (just over the blunder threshold) is worded'
        ' as decisive, not game-changing', () {
      final result = MoveCommentaryService.generate(
        l10n,
        move(quality: MoveQuality.blunder, centipawnLoss: 350),
      );
      expect(result, l10n.moveCommentaryBlunderDecisive);
    });

    test('a huge blunder (far over the blunder threshold) is worded as'
        ' game-changing', () {
      final result = MoveCommentaryService.generate(
        l10n,
        move(quality: MoveQuality.blunder, centipawnLoss: 900),
      );
      expect(result, l10n.moveCommentaryBlunderHuge);
    });
  });

  group('MoveCommentaryService.generate - capture/check/checkmate', () {
    test('checkmate overrides everything else, including quality', () {
      final result = MoveCommentaryService.generate(
        l10n,
        move(
          quality: MoveQuality.best,
          isCheckmate: true,
          san: 'Qh7#',
        ),
      );
      expect(result, l10n.moveCommentaryCheckmate('Qh7#'));
    });

    test('a good capturing move names the captured piece', () {
      final result = MoveCommentaryService.generate(
        l10n,
        move(
          quality: MoveQuality.good,
          centipawnLoss: 20,
          isCapture: true,
          capturedPieceType: 'q',
        ),
      );
      expect(
        result,
        '${l10n.moveCommentaryGood} '
        '${l10n.moveCommentaryCaptureClause(l10n.moveCommentaryPieceQueen)}',
      );
    });

    test('a best, non-capturing move that gives check mentions the check',
        () {
      final result = MoveCommentaryService.generate(
        l10n,
        move(
          quality: MoveQuality.best,
          legalMoveCountBefore: 30,
          isCheck: true,
        ),
      );
      expect(
        result,
        '${l10n.moveCommentaryBest}${l10n.moveCommentaryCheckClause}',
      );
    });
  });

  group('MoveCommentaryService.generate - hangs-a-piece detection (#5)', () {
    test('a blunder that leaves a rook attacked and undefended is called'
        ' out by name and square', () {
      final result = MoveCommentaryService.generate(
        l10n,
        move(
          quality: MoveQuality.blunder,
          centipawnLoss: 450,
          fenAfter: _hangsRookFen,
        ),
      );
      expect(
        result,
        l10n.moveCommentaryHangsPieceBlunder(
          l10n.moveCommentaryPieceRook,
          'd4',
        ),
      );
    });

    test('a mistake that leaves a rook attacked and undefended uses the'
        ' mistake wording, not the blunder one', () {
      final result = MoveCommentaryService.generate(
        l10n,
        move(
          quality: MoveQuality.mistake,
          centipawnLoss: 150,
          fenAfter: _hangsRookFen,
        ),
      );
      expect(
        result,
        l10n.moveCommentaryHangsPieceMistake(
          l10n.moveCommentaryPieceRook,
          'd4',
        ),
      );
    });

    test('an attacked piece that can legally be recaptured is NOT reported'
        ' as hanging - falls back to the generic blunder template', () {
      final result = MoveCommentaryService.generate(
        l10n,
        move(
          quality: MoveQuality.blunder,
          centipawnLoss: 450,
          fenAfter: _defendedRookFen,
        ),
      );
      expect(result, l10n.moveCommentaryBlunderDecisive);
    });

    test('a quiet position with nothing to capture falls back to the'
        ' generic blunder template', () {
      final result = MoveCommentaryService.generate(
        l10n,
        move(
          quality: MoveQuality.blunder,
          centipawnLoss: 450,
          fenAfter: _quietFen,
        ),
      );
      expect(result, l10n.moveCommentaryBlunderDecisive);
    });

    test('with no fenAfter at all (older/minimal MoveAnalysis), falls back'
        ' to the generic mistake template rather than skipping commentary',
        () {
      final result = MoveCommentaryService.generate(
        l10n,
        move(quality: MoveQuality.mistake, centipawnLoss: 250),
      );
      expect(result, l10n.moveCommentaryMistakeCostly);
    });

    test('good/best moves never attempt hanging-piece detection even when'
        ' fenAfter is provided', () {
      final result = MoveCommentaryService.generate(
        l10n,
        move(
          quality: MoveQuality.best,
          legalMoveCountBefore: 20,
          fenAfter: _hangsRookFen,
        ),
      );
      expect(result, l10n.moveCommentaryBest);
    });
  });
}
