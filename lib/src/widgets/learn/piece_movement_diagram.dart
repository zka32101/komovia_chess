import 'package:flutter/material.dart';

import '../../services/chess_engine_service.dart';

/// A small, non-interactive 8x8 board diagram used to illustrate how a
/// piece moves: shows the piece on [pieceSquare] and highlights every
/// square in [highlightSquares] as a reachable destination.
///
/// This is intentionally decoupled from [ChessEngineService]/[ChessBoard]:
/// it only ever renders a fixed illustration, never live game state.
class PieceMovementDiagram extends StatelessWidget {
  const PieceMovementDiagram({
    required this.symbol,
    required this.pieceSquare,
    required this.highlightSquares,
    Key? key,
    this.size = 280,
  }) : super(key: key);
  final String symbol;
  final String pieceSquare;
  final List<String> highlightSquares;
  final double size;

  static const List<String> _files = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];

  @override
  Widget build(BuildContext context) {
    final highlightSet = highlightSquares.toSet();
    final squareSize = size / 8;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(8, (row) {
          final rank = 8 - row;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(8, (col) {
              final file = _files[col];
              final square = '$file$rank';
              final isDark = (row + col) % 2 == 1;
              final isPiece = square == pieceSquare;
              final isHighlighted = highlightSet.contains(square);

              return Container(
                width: squareSize,
                height: squareSize,
                color: isDark ? Colors.brown.shade300 : Colors.brown.shade50,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (isHighlighted)
                      Container(
                        margin: EdgeInsets.all(squareSize * 0.18),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.55),
                          shape: BoxShape.circle,
                        ),
                      ),
                    if (isPiece)
                      Text(
                        symbol,
                        style: TextStyle(fontSize: squareSize * 0.7),
                      ),
                  ],
                ),
              );
            }),
          );
        }),
      ),
    );
  }
}
