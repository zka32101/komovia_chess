import 'package:flutter/material.dart';
import '../models/piece_skin.dart';

/// A chess piece drawn from a Unicode glyph, readable on both square colors.
///
/// The hollow "white" glyphs (♔ ♕ ...) filled with a near-white color vanish on
/// light squares (the default theme's light square #F0D9B5 vs piece #F8F8F8),
/// so white pieces are drawn as the *solid* glyphs (♚ ♛ ...) with a dark
/// outline under the fill. Black pieces get a thin light outline so they also
/// stay readable on dark squares.
class PieceGlyph extends StatelessWidget {
  const PieceGlyph({
    required this.type,
    required this.isWhite,
    required this.fontSize,
    required this.whiteColor,
    required this.blackColor,
    this.skin,
    Key? key,
  }) : super(key: key);

  /// One of `k q r b n p` (lower case, regardless of color).
  final String type;
  final bool isWhite;
  final double fontSize;
  final Color whiteColor;
  final Color blackColor;

  /// Optional piece-set skin. Its fills (when set) override
  /// [whiteColor]/[blackColor]; its outline/weight replace the defaults.
  final PieceSkin? skin;

  /// The solid glyphs, used for both colors (the color comes from the paint).
  static const Map<String, String> solidGlyphs = {
    'k': '♚',
    'q': '♛',
    'r': '♜',
    'b': '♝',
    'n': '♞',
    // U+265F has an emoji presentation that Android renders as a grey picture
    // ignoring the paint color (and VS15, U+FE0E, does not prevent it), so the
    // pawn uses the hollow U+2659 shape, which has no emoji form. Known
    // limitation: being hollow, the pawn's inside shows the square color
    // instead of the piece color; drawing the pawn as a custom shape would fix
    // that.
    'p': '♙',
  };

  @override
  Widget build(BuildContext context) {
    final glyph = solidGlyphs[type] ?? '?';
    final s = skin ?? PieceSkinCatalog.standard;
    final fill = isWhite
        ? (s.whiteFill ?? whiteColor)
        : (s.blackFill ?? blackColor);
    final outline = isWhite ? s.whiteOutline : s.blackOutline;
    final strokeWidth =
        fontSize * (isWhite ? s.whiteStrokeScale : s.blackStrokeScale);
    final weight = s.fontWeight;

    return Stack(
      alignment: Alignment.center,
      children: [
        Text(
          glyph,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: weight,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth
              ..strokeJoin = StrokeJoin.round
              ..color = outline,
          ),
        ),
        Text(
          glyph,
          style: TextStyle(fontSize: fontSize, fontWeight: weight, color: fill),
        ),
      ],
    );
  }
}
