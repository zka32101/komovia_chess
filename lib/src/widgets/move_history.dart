import 'package:flutter/material.dart';
import 'package:chess/chess.dart' as chess_lib;

/// Display move history with annotations
class MoveHistory extends StatelessWidget {
  const MoveHistory({
    required this.moves,
    Key? key,
    this.currentMoveIndex,
    this.onMoveSelected,
  }) : super(key: key);
  final List<chess_lib.Move> moves;
  final int? currentMoveIndex;
  final Function(int)? onMoveSelected;

  /// Convert move to algebraic notation (simplified)
  String _moveToNotation(chess_lib.Move move) {
    String notation = '';

    // Add piece symbol (omit for pawns). Move.piece is the PieceType of the
    // piece that moved (no color info), not a Piece with a nested .type.
    if (move.piece != chess_lib.PieceType.PAWN) {
      notation += move.piece.name.toUpperCase();
    }

    // Add move coordinates
    notation += move.fromAlgebraic;

    // Add capture indicator. flags is an int bitmask, not a String.
    if ((move.flags & chess_lib.Chess.BITS_CAPTURE) != 0) {
      notation += 'x';
    } else {
      notation += '-';
    }

    notation += move.toAlgebraic;

    // Add promotion
    if (move.promotion != null) {
      notation += '=${move.promotion!.name.toUpperCase()}';
    }

    return notation;
  }

  @override
  Widget build(BuildContext context) {
    if (moves.isEmpty) {
      return Center(
        child: Text(
          'No moves yet',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey,
              ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: (moves.length / 2).ceil(),
      itemBuilder: (context, index) {
        final moveIndex1 = index * 2;
        final moveIndex2 = moveIndex1 + 1;

        final move1 = moveIndex1 < moves.length ? moves[moveIndex1] : null;
        final move2 = moveIndex2 < moves.length ? moves[moveIndex2] : null;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              // Move number
              SizedBox(
                width: 40,
                child: Text(
                  '${index + 1}.',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),

              // White move
              if (move1 != null)
                Expanded(
                  child: _MoveButton(
                    notation: _moveToNotation(move1),
                    isSelected: currentMoveIndex == moveIndex1,
                    onTap: () => onMoveSelected?.call(moveIndex1),
                  ),
                )
              else
                Expanded(child: Container()),

              const SizedBox(width: 4),

              // Black move
              if (move2 != null)
                Expanded(
                  child: _MoveButton(
                    notation: _moveToNotation(move2),
                    isSelected: currentMoveIndex == moveIndex2,
                    onTap: () => onMoveSelected?.call(moveIndex2),
                  ),
                )
              else
                Expanded(child: Container()),
            ],
          ),
        );
      },
    );
  }
}

/// Individual move button
class _MoveButton extends StatelessWidget {
  const _MoveButton({
    required this.notation,
    required this.isSelected,
    this.onTap,
  });
  final String notation;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue[300] : Colors.transparent,
            border: Border.all(
              color: isSelected ? Colors.blue : Colors.grey[300] ?? Colors.grey,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            notation,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
            textAlign: TextAlign.center,
          ),
        ),
      );
}
