import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:chess/chess.dart' as chess_lib;
import 'package:image/image.dart' as img;
import '../models/board_theme.dart';
import 'chess_engine_service.dart';

/// Exposed so callers that only have an optional/nullable starting FEN
/// (e.g. [CpuGameState.startingFen]) can fall back to it explicitly
/// instead of omitting the parameter and relying on [generateGif]'s own
/// default to happen to match.
const standardStartingFen =
    'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

/// One played move, deliberately decoupled from both `chess_lib.Move`
/// (which only exists for a *live* `Chess` instance's current legal moves,
/// not a replayable record) and `GameMove` (Firestore-specific), so this
/// service can replay a finished game from either `CPUGameScreen`'s
/// `chess_lib.Move` history or `OnlineGame.moves`' from/to/promotion
/// strings with the same code.
typedef ReplayMove = ({String from, String to, String? promotion});

/// Renders a finished game's move sequence as an animated GIF - one frame
/// per position, replayed move by move - for sharing outside the app. No
/// Flutter widget tree is involved: each frame is painted directly onto a
/// `dart:ui` canvas (same squares/pieces drawing as `ChessBoard`'s
/// `_ChessBoardPainter`, re-implemented here since that one is private and
/// driven by live widget state rather than a replayed position), rasterized
/// via `Picture.toImage`, and handed to the `image` package to encode.
///
/// NOTE: written without a Flutter/Dart toolchain available in this
/// sandbox to run `flutter pub get` or `dart analyze` against the `image`
/// package's real API - the frame/encode calls below follow image v4's
/// documented API as best effort and have not been compile-checked.
class GameGifService {
  /// [frameSize] is the GIF's width/height in pixels (square board).
  /// [frameDurationMs] is how long each position is shown before advancing
  /// to the next move; the final position is shown for 3x as long so a
  /// viewer has time to register the result before the GIF loops.
  Future<Uint8List> generateGif({
    required List<ReplayMove> moves,
    String startingFen = standardStartingFen,
    BoardTheme theme = BoardThemeCatalog.classic,
    int frameSize = 480,
    int frameDurationMs = 700,
  }) async {
    final chess = chess_lib.Chess.fromFEN(startingFen);
    final frames = <img.Image>[];

    frames.add(await _renderFrame(chess, theme, frameSize));

    for (final move in moves) {
      final applied = chess.move({
        'from': move.from,
        'to': move.to,
        if (move.promotion != null) 'promotion': move.promotion,
      });
      if (!applied) continue; // malformed/legacy record - skip, don't abort
      frames.add(await _renderFrame(
        chess,
        theme,
        frameSize,
        lastMoveFrom: move.from,
        lastMoveTo: move.to,
      ));
    }

    if (frames.isEmpty) {
      frames.add(await _renderFrame(chess, theme, frameSize));
    }

    final animation = frames.first;
    animation.frameDuration = frameDurationMs;
    for (var i = 1; i < frames.length; i++) {
      final frame = frames[i];
      frame.frameDuration =
          i == frames.length - 1 ? frameDurationMs * 3 : frameDurationMs;
      animation.addFrame(frame);
    }

    final encoded = img.encodeGif(animation);
    return Uint8List.fromList(encoded);
  }

  Future<img.Image> _renderFrame(
    chess_lib.Chess chess,
    BoardTheme theme,
    int frameSize, {
    String? lastMoveFrom,
    String? lastMoveTo,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = frameSize.toDouble();
    final squareSize = size / 8;

    final squarePaint = Paint();
    final highlightPaint = Paint();

    for (var rank = 0; rank < 8; rank++) {
      for (var file = 0; file < 8; file++) {
        final square = ChessEngineService.indicesToSquare(rank, file);
        final rect = Rect.fromLTWH(
          file * squareSize,
          rank * squareSize,
          squareSize,
          squareSize,
        );

        final isLight = (rank + file) % 2 == 0;
        squarePaint.color =
            isLight ? theme.lightSquareColor : theme.darkSquareColor;
        canvas.drawRect(rect, squarePaint);

        if (square == lastMoveFrom || square == lastMoveTo) {
          highlightPaint.color =
              theme.legalMoveIndicatorColor.withOpacity(0.35);
          canvas.drawRect(rect, highlightPaint);
        }
      }
    }

    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    for (var rank = 0; rank < 8; rank++) {
      for (var file = 0; file < 8; file++) {
        final piece = chess.get(ChessEngineService.indicesToSquare(rank, file));
        if (piece == null) continue;

        textPainter.text = TextSpan(
          text: _pieceGlyph(piece),
          style: TextStyle(
            fontSize: squareSize * 0.68,
            fontWeight: FontWeight.bold,
            color: piece.color == chess_lib.Color.WHITE
                ? theme.whitePieceColor
                : theme.blackPieceColor,
          ),
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(
            file * squareSize + (squareSize - textPainter.width) / 2,
            rank * squareSize + (squareSize - textPainter.height) / 2,
          ),
        );
      }
    }

    final picture = recorder.endRecording();
    final uiImage = await picture.toImage(frameSize, frameSize);
    final byteData =
        await uiImage.toByteData(format: ui.ImageByteFormat.rawRgba);
    uiImage.dispose();

    return img.Image.fromBytes(
      width: frameSize,
      height: frameSize,
      bytes: byteData!.buffer,
      numChannels: 4,
    );
  }

  String _pieceGlyph(chess_lib.Piece piece) {
    // Not `const`: PieceType overrides hashCode/==, which Dart disallows
    // for constant map keys (same note as ChessBoard._getPieceSymbol).
    final whiteGlyphs = {
      chess_lib.PieceType.KING: '♔',
      chess_lib.PieceType.QUEEN: '♕',
      chess_lib.PieceType.ROOK: '♖',
      chess_lib.PieceType.BISHOP: '♗',
      chess_lib.PieceType.KNIGHT: '♘',
      chess_lib.PieceType.PAWN: '♙',
    };
    final blackGlyphs = {
      chess_lib.PieceType.KING: '♚',
      chess_lib.PieceType.QUEEN: '♛',
      chess_lib.PieceType.ROOK: '♜',
      chess_lib.PieceType.BISHOP: '♝',
      chess_lib.PieceType.KNIGHT: '♞',
      chess_lib.PieceType.PAWN: '♟',
    };
    final glyphs =
        piece.color == chess_lib.Color.WHITE ? whiteGlyphs : blackGlyphs;
    return glyphs[piece.type] ?? '?';
  }
}
