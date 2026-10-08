import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_chess/komovia_chess_engine.dart';

void main() {
  testWidgets('ChessBoardRenderer builds an 8x8 board and squareAt maps taps back',
      (tester) async {
    final game = ChessGame();
    final pos = game.initialPosition();
    const renderer = ChessBoardRenderer();

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(width: 320, height: 320, child: renderer.build(pos)),
      ),
    );

    expect(find.byType(CustomPaint), findsWidgets);
    // 32 pieces on the standard starting position.
    expect(find.byType(Text), findsNWidgets(32));

    final square = renderer.squareAt(
      const BoardOffset(10, 10),
      const BoardSize(320, 320),
      pos,
    );
    expect(square, isNotNull);
    expect(square!.file, inInclusiveRange(0, 7));
    expect(square.rank, inInclusiveRange(0, 7));

    expect(
      renderer.squareAt(const BoardOffset(-5, -5), const BoardSize(320, 320), pos),
      isNull,
    );
  });
}
