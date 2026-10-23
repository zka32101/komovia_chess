import 'package:flutter/material.dart';
import 'package:chess/chess.dart' as chess_lib;

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

  /// Get symbol for display
  String _getSymbol(chess_lib.Piece piece) => piece.type.name.toUpperCase();

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

    return Column(
      children: [
        // Black captured pieces (displayed at top)
        if (blackCapturedPieces.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Wrap(
              spacing: 4,
              children: blackCapturedPieces
                  .map((piece) => Chip(
                        label: Text(_getSymbol(piece)),
                        avatar: CircleAvatar(
                          backgroundColor: Colors.grey[700],
                          child: Text(
                            _getSymbol(piece),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        backgroundColor: Colors.grey[300],
                      ))
                  .toList(),
            ),
          ),

        // Material advantage indicator
        if (materialDifference > 0)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isWhiteAdvantage ? Colors.grey[300] : Colors.grey[700],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isWhiteAdvantage
                    ? '+$materialDifference'
                    : '-$materialDifference',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isWhiteAdvantage ? Colors.black : Colors.white,
                ),
              ),
            ),
          ),

        // White captured pieces (displayed at bottom)
        if (whiteCapturedPieces.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Wrap(
              spacing: 4,
              children: whiteCapturedPieces
                  .map((piece) => Chip(
                        label: Text(_getSymbol(piece)),
                        avatar: CircleAvatar(
                          backgroundColor: Colors.grey[300],
                          child: Text(
                            _getSymbol(piece),
                            style: const TextStyle(color: Colors.black),
                          ),
                        ),
                        backgroundColor: Colors.grey[100],
                      ))
                  .toList(),
            ),
          ),
      ],
    );
  }
}
