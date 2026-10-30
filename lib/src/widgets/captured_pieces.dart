import 'package:flutter/material.dart';
import 'package:chess/chess.dart' as chess_lib;
import 'piece_glyph.dart';

/// Display captured pieces for both sides
class CapturedPieces extends StatelessWidget {
  const CapturedPieces({
    required this.whiteCapturedPieces,
    required this.blackCapturedPieces,
    Key? key,
  }) : super(key: key);
  final List<chess_lib.Piece> whiteCapturedPieces;
  final List<chess_lib.Piece> blackCapturedPieces;

  /// Get material value for a piece
  int _getMaterialValue(chess_lib.Piece piece) {
    // PieceType is a plain class with static const instances, not a real
    // Dart enum, so the analyzer can't prove this switch is exhaustive.
    switch (piece.type) {
      case chess_lib.PieceType.PAWN:
        return 1;
      case chess_lib.PieceType.KNIGHT:
        return 3;
      case chess_lib.PieceType.BISHOP:
        return 3;
      case chess_lib.PieceType.ROOK:
        return 5;
      case chess_lib.PieceType.QUEEN:
        return 9;
      case chess_lib.PieceType.KING:
        return 0;
      default:
        throw ArgumentError('Unknown piece type: ${piece.type}');
    }
  }

  /// Calculate total material value
  int _calculateMaterialValue(List<chess_lib.Piece> pieces) =>
      pieces.fold(0, (sum, piece) => sum + _getMaterialValue(piece));

  /// Small icon-row rendering for one side's captured pieces: a tight
  /// row of tiny [PieceGlyph]s (same glyph rendering the board itself
  /// uses) rather than a full-sized [Chip] per piece - the previous
  /// per-piece `Chip` (label + CircleAvatar) rendered each captured
  /// piece far larger than this compact summary needs.
  Widget _buildIconRow(List<chess_lib.Piece> pieces, bool rowIsWhite) {
    const iconSize = 14.0;
    return Wrap(
      spacing: 1,
      children: pieces
          .map(
            (piece) => PieceGlyph(
              type: piece.type.name,
              isWhite: rowIsWhite,
              fontSize: iconSize,
              whiteColor: Colors.grey[300]!,
              blackColor: Colors.grey[700]!,
            ),
          )
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // whiteCapturedPieces/blackCapturedPieces (see GameBoardState.
    // _getCapturedPieces) are each color's OWN pieces that are missing
    // from the board - i.e. each side's losses, not what it captured
    // from the opponent. whiteMaterial is therefore the value white has
    // LOST (captured by black) and blackMaterial is what black has lost
    // (captured by white) - so white is ahead when black has lost MORE
    // material, not when whiteMaterial is bigger. The previous
    // `isWhiteAdvantage = whiteMaterial > blackMaterial` had this
    // backwards: capturing black's queen for free (blackMaterial=9,
    // whiteMaterial=0) showed "-9" with the black-advantage styling,
    // even though white was actually up a queen.
    final whiteMaterial = _calculateMaterialValue(whiteCapturedPieces);
    final blackMaterial = _calculateMaterialValue(blackCapturedPieces);
    final materialDifference = (whiteMaterial - blackMaterial).abs();
    final isWhiteAdvantage = blackMaterial > whiteMaterial;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Black's losses (white's captures) - small icon row.
        if (blackCapturedPieces.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _buildIconRow(blackCapturedPieces, false),
          ),

        // Material advantage indicator
        if (materialDifference > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isWhiteAdvantage ? Colors.grey[300] : Colors.grey[700],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                isWhiteAdvantage
                    ? '+$materialDifference'
                    : '-$materialDifference',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: isWhiteAdvantage ? Colors.black : Colors.white,
                ),
              ),
            ),
          ),

        // White's losses (black's captures) - small icon row.
        if (whiteCapturedPieces.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _buildIconRow(whiteCapturedPieces, true),
          ),
      ],
    );
  }
}
