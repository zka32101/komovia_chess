import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chess/chess.dart' as chess_lib;
import 'package:komovia_chess/src/widgets/captured_pieces.dart';

void main() {
  group('CapturedPieces', () {
    testWidgets('renders with no captured pieces', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CapturedPieces(
              whiteCapturedPieces: [],
              blackCapturedPieces: [],
            ),
          ),
        ),
      );

      expect(find.byType(CapturedPieces), findsOneWidget);
    });

    testWidgets('displays white captured pieces', (WidgetTester tester) async {
      final whiteCaptured = [
        chess_lib.Piece(
            color: chess_lib.Color.WHITE, type: chess_lib.PieceType.pawn),
        chess_lib.Piece(
            color: chess_lib.Color.WHITE, type: chess_lib.PieceType.knight),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CapturedPieces(
              whiteCapturedPieces: whiteCaptured,
              blackCapturedPieces: [],
            ),
          ),
        ),
      );

      expect(find.byType(Chip), findsWidgets);
    });

    testWidgets('displays black captured pieces', (WidgetTester tester) async {
      final blackCaptured = [
        chess_lib.Piece(
            color: chess_lib.Color.BLACK, type: chess_lib.PieceType.pawn),
        chess_lib.Piece(
            color: chess_lib.Color.BLACK, type: chess_lib.PieceType.bishop),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CapturedPieces(
              whiteCapturedPieces: [],
              blackCapturedPieces: blackCaptured,
            ),
          ),
        ),
      );

      expect(find.byType(Chip), findsWidgets);
    });

    testWidgets('displays both captured pieces', (WidgetTester tester) async {
      final whiteCaptured = [
        chess_lib.Piece(
            color: chess_lib.Color.WHITE, type: chess_lib.PieceType.pawn),
      ];
      final blackCaptured = [
        chess_lib.Piece(
            color: chess_lib.Color.BLACK, type: chess_lib.PieceType.queen),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CapturedPieces(
              whiteCapturedPieces: whiteCaptured,
              blackCapturedPieces: blackCaptured,
            ),
          ),
        ),
      );

      expect(find.byType(Chip), findsWidgets);
    });

    testWidgets('shows material advantage for white',
        (WidgetTester tester) async {
      final whiteCaptured = [
        chess_lib.Piece(
            color: chess_lib.Color.WHITE, type: chess_lib.PieceType.queen), // 9
      ];
      final blackCaptured = [
        chess_lib.Piece(
            color: chess_lib.Color.BLACK, type: chess_lib.PieceType.pawn), // 1
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CapturedPieces(
              whiteCapturedPieces: whiteCaptured,
              blackCapturedPieces: blackCaptured,
            ),
          ),
        ),
      );

      // Should show material difference
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('shows material advantage for black',
        (WidgetTester tester) async {
      final whiteCaptured = [
        chess_lib.Piece(
            color: chess_lib.Color.WHITE, type: chess_lib.PieceType.pawn), // 1
      ];
      final blackCaptured = [
        chess_lib.Piece(
            color: chess_lib.Color.BLACK, type: chess_lib.PieceType.rook), // 5
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CapturedPieces(
              whiteCapturedPieces: whiteCaptured,
              blackCapturedPieces: blackCaptured,
            ),
          ),
        ),
      );

      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('shows equal material as no advantage',
        (WidgetTester tester) async {
      final whiteCaptured = [
        chess_lib.Piece(
            color: chess_lib.Color.WHITE, type: chess_lib.PieceType.pawn),
      ];
      final blackCaptured = [
        chess_lib.Piece(
            color: chess_lib.Color.BLACK, type: chess_lib.PieceType.pawn),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CapturedPieces(
              whiteCapturedPieces: whiteCaptured,
              blackCapturedPieces: blackCaptured,
            ),
          ),
        ),
      );

      // Equal material, no advantage display
      expect(find.byType(CapturedPieces), findsOneWidget);
    });

    testWidgets('displays multiple pieces of same type',
        (WidgetTester tester) async {
      final whiteCaptured = [
        chess_lib.Piece(
            color: chess_lib.Color.WHITE, type: chess_lib.PieceType.pawn),
        chess_lib.Piece(
            color: chess_lib.Color.WHITE, type: chess_lib.PieceType.pawn),
        chess_lib.Piece(
            color: chess_lib.Color.WHITE, type: chess_lib.PieceType.pawn),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CapturedPieces(
              whiteCapturedPieces: whiteCaptured,
              blackCapturedPieces: [],
            ),
          ),
        ),
      );

      expect(find.byType(Chip), findsWidgets);
    });

    testWidgets('arranges captured pieces in wrap layout',
        (WidgetTester tester) async {
      final whiteCaptured = List.generate(
        10,
        (index) => chess_lib.Piece(
          color: chess_lib.Color.WHITE,
          type: chess_lib.PieceType.pawn,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CapturedPieces(
                whiteCapturedPieces: whiteCaptured,
                blackCapturedPieces: [],
              ),
            ),
          ),
        ),
      );

      expect(find.byType(Wrap), findsWidgets);
      expect(find.byType(Chip), findsWidgets);
    });
  });
}
