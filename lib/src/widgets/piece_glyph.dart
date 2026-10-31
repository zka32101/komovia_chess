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
    // The pawn is not a glyph: U+265F has an emoji presentation that Android
    // renders as a grey picture ignoring the paint color (and VS15 does not
    // prevent it), and the hollow U+2659 shows the square color inside, so
    // black and white pawns looked alike. It is drawn by [_PawnPainter].
  };

  @override
  Widget build(BuildContext context) {
    final s = skin ?? PieceSkinCatalog.standard;
    final fill = isWhite
        ? (s.whiteFill ?? whiteColor)
        : (s.blackFill ?? blackColor);
    final outline = isWhite ? s.whiteOutline : s.blackOutline;
    final strokeWidth =
        fontSize * (isWhite ? s.whiteStrokeScale : s.blackStrokeScale);
    final weight = s.fontWeight;

    if (type == 'p') {
      return CustomPaint(
        size: Size.square(fontSize),
        painter: _PawnPainter(
          fill: fill,
          outline: outline,
          strokeWidth: strokeWidth,
        ),
      );
    }

    final glyph = solidGlyphs[type] ?? '?';
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

/// A solid pawn silhouette (head, collar, body, base) in a unit square, so it
/// takes the piece color like the other solid glyphs do.
class _PawnPainter extends CustomPainter {
  const _PawnPainter({
    required this.fill,
    required this.outline,
    required this.strokeWidth,
  });

  final Color fill;
  final Color outline;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    Offset at(double x, double y) => Offset(x * w, y * h);

    final head = Path()
      ..addOval(Rect.fromCircle(center: at(0.5, 0.30), radius: 0.12 * w));
    final collar = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromPoints(at(0.35, 0.41), at(0.65, 0.47)),
        Radius.circular(0.03 * w),
      ));
    final body = Path()
      ..moveTo(at(0.41, 0.46).dx, at(0.41, 0.46).dy)
      ..lineTo(at(0.59, 0.46).dx, at(0.59, 0.46).dy)
      ..lineTo(at(0.68, 0.72).dx, at(0.68, 0.72).dy)
      ..lineTo(at(0.32, 0.72).dx, at(0.32, 0.72).dy)
      ..close();
    final base = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromPoints(at(0.26, 0.72), at(0.74, 0.82)),
        Radius.circular(0.04 * w),
      ));

    final silhouette = [head, collar, body, base].reduce(
      (a, b) => Path.combine(PathOperation.union, a, b),
    );

    canvas
      ..drawPath(
        silhouette,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeJoin = StrokeJoin.round
          ..color = outline,
      )
      ..drawPath(silhouette, Paint()..color = fill);
  }

  @override
  bool shouldRepaint(_PawnPainter old) =>
      old.fill != fill ||
      old.outline != outline ||
      old.strokeWidth != strokeWidth;
}
