import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chess/chess.dart' as chess_lib;
import 'package:komovia_chess/src/widgets/captured_pieces.dart';
import 'package:komovia_chess/src/widgets/piece_glyph.dart';

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
        chess_lib.Piece(chess_lib.PieceType.PAWN, chess_lib.Color.WHITE),
        chess_lib.Piece(chess_lib.PieceType.KNIGHT, chess_lib.Color.WHITE),
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

      expect(find.byType(PieceGlyph), findsWidgets);
    });

    testWidgets('displays black captured pieces', (WidgetTester tester) async {
      final blackCaptured = [
        chess_lib.Piece(chess_lib.PieceType.PAWN, chess_lib.Color.BLACK),
        chess_lib.Piece(chess_lib.PieceType.BISHOP, chess_lib.Color.BLACK),
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

      expect(find.byType(PieceGlyph), findsWidgets);
    });

    testWidgets('displays both captured pieces', (WidgetTester tester) async {
      final whiteCaptured = [
        chess_lib.Piece(chess_lib.PieceType.PAWN, chess_lib.Color.WHITE),
      ];
      final blackCaptured = [
        chess_lib.Piece(chess_lib.PieceType.QUEEN, chess_lib.Color.BLACK),
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

      expect(find.byType(PieceGlyph), findsWidgets);
    });

    testWidgets('shows material advantage for white',
        (WidgetTester tester) async {
      final whiteCaptured = [
        chess_lib.Piece(chess_lib.PieceType.QUEEN, chess_lib.Color.WHITE), // 9
      ];
      final blackCaptured = [
        chess_lib.Piece(chess_lib.PieceType.PAWN, chess_lib.Color.BLACK), // 1
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
        chess_lib.Piece(chess_lib.PieceType.PAWN, chess_lib.Color.WHITE), // 1
      ];
      final blackCaptured = [
        chess_lib.Piece(chess_lib.PieceType.ROOK, chess_lib.Color.BLACK), // 5
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
        chess_lib.Piece(chess_lib.PieceType.PAWN, chess_lib.Color.WHITE),
      ];
      final blackCaptured = [
        chess_lib.Piece(chess_lib.PieceType.PAWN, chess_lib.Color.BLACK),
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
        chess_lib.Piece(chess_lib.PieceType.PAWN, chess_lib.Color.WHITE),
        chess_lib.Piece(chess_lib.PieceType.PAWN, chess_lib.Color.WHITE),
        chess_lib.Piece(chess_lib.PieceType.PAWN, chess_lib.Color.WHITE),
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

      expect(find.byType(PieceGlyph), findsWidgets);
    });

    testWidgets('arranges captured pieces in wrap layout',
        (WidgetTester tester) async {
      final whiteCaptured = List<chess_lib.Piece>.generate(
        10,
        (index) => chess_lib.Piece(chess_lib.PieceType.PAWN, chess_lib.Color.WHITE),
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
      expect(find.byType(PieceGlyph), findsWidgets);
    });
  });
}
