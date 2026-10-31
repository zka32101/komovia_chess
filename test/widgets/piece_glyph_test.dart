import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_chess/src/models/board_theme.dart';
import 'package:komovia_chess/src/widgets/piece_glyph.dart';

/// Renders [PieceGlyph] on a square of [square] and returns the RGBA pixels.
Future<({Uint8List rgba, int width, int height})> _render(
  WidgetTester tester, {
  required bool isWhite,
  required Color square,
  String type = 'k',
  Color? whiteColor,
  Color? blackColor,
}) async {
  final key = GlobalKey();
  const side = 120.0;
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: RepaintBoundary(
          key: key,
          child: Container(
            width: side,
            height: side,
            color: square,
            child: Center(
              child: PieceGlyph(
                type: type,
                isWhite: isWhite,
                fontSize: side * 0.6,
                whiteColor: whiteColor ?? BoardThemeCatalog.classic.whitePieceColor,
                blackColor: blackColor ?? BoardThemeCatalog.classic.blackPieceColor,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  final image = await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    return boundary.toImage();
  });
  final data = await tester.runAsync(
    () => image!.toByteData(format: ui.ImageByteFormat.rawRgba),
  );
  return (
    rgba: data!.buffer.asUint8List(),
    width: image!.width,
    height: image.height
  );
}

/// Perceived brightness 0..255 of a pixel.
double _luma(Uint8List p, int i) =>
    0.299 * p[i] + 0.587 * p[i + 1] + 0.114 * p[i + 2];

/// The darkest pixel brightness in the image (the outline), and how many
/// pixels differ clearly from the background brightness.
({double darkest, int distinct}) _contrast(
  ({Uint8List rgba, int width, int height}) img,
  Color background,
) {
  final bg = 0.299 * background.red +
      0.587 * background.green +
      0.114 * background.blue;
  var darkest = 255.0;
  var distinct = 0;
  for (var i = 0; i < img.rgba.length; i += 4) {
    final l = _luma(img.rgba, i);
    if (l < darkest) darkest = l;
    if ((l - bg).abs() > 60) distinct++;
  }
  return (darkest: darkest, distinct: distinct);
}

void main() {
  final light = BoardThemeCatalog.classic.lightSquareColor;
  final dark = BoardThemeCatalog.classic.darkSquareColor;

  testWidgets('白い駒は薄い升の上でも暗い輪郭で縁取られ、見分けがつく', (tester) async {
    final img = await _render(tester, isWhite: true, square: light);
    final c = _contrast(img, light);

    // 輪郭の暗いピクセルがある(以前は#F8F8F8の塗りだけで、升とほぼ同色だった)。
    expect(c.darkest, lessThan(60));
    // 升と明らかに違うピクセルが、駒の大きさに見合うだけある。
    expect(c.distinct, greaterThan(400));
  });

  testWidgets('白い駒は濃い升の上でも見分けがつく', (tester) async {
    final img = await _render(tester, isWhite: true, square: dark);
    final c = _contrast(img, dark);

    expect(c.distinct, greaterThan(400));
  });

  testWidgets('黒い駒は濃い升の上でも、明るい縁で見分けがつく', (tester) async {
    final img = await _render(tester, isWhite: false, square: dark);
    final c = _contrast(img, dark);

    expect(c.distinct, greaterThan(400));
  });

  testWidgets('全てのテーマで、白い駒は薄い升の上で見分けがつく', (tester) async {
    for (final theme in BoardThemeCatalog.all) {
      final img = await _render(
        tester,
        isWhite: true,
        square: theme.lightSquareColor,
        whiteColor: theme.whitePieceColor,
        blackColor: theme.blackPieceColor,
      );
      final c = _contrast(img, theme.lightSquareColor);
      expect(c.distinct, greaterThan(400), reason: 'テーマ ${theme.id}');
    }
  });

  testWidgets('全ての駒の種類で、白は薄い升の上で見分けがつく', (tester) async {
    for (final type in ['k', 'q', 'r', 'b', 'n', 'p']) {
      final img =
          await _render(tester, isWhite: true, square: light, type: type);
      final c = _contrast(img, light);
      expect(c.distinct, greaterThan(200), reason: '駒 $type');
    }
  });

  testWidgets('ポーンは中身が駒の色で塗られ、白黒の区別がつく(空洞ではない)', (tester) async {
    // 駒は 120 の升の中央に 72 四方で描かれる。胴体の中心はその少し下。
    double bodyLuma(({Uint8List rgba, int width, int height}) img) {
      final x = (img.width * 0.5).round();
      final y = (img.height * 0.56).round();
      return _luma(img.rgba, (y * img.width + x) * 4);
    }

    final white =
        await _render(tester, isWhite: true, square: light, type: 'p');
    final black =
        await _render(tester, isWhite: false, square: light, type: 'p');

    expect(bodyLuma(white), greaterThan(220));
    expect(bodyLuma(black), lessThan(80));
  });
}
