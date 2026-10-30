import 'package:chess/chess.dart' as chess_lib;

/// Thrown by [parseMoveSequenceToUci] when the given text isn't a
/// parseable move sequence.
class MoveSequenceParseException implements Exception {
  MoveSequenceParseException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Parses a short pasted move sequence (either a bare movetext like
/// `"1. e4 e5 2. Nf3 Nc6"` or a full PGN transcript with headers - both
/// load fine through `chess_lib.load_pgn`, same as `pgn_importer.dart`'s
/// `parsePgnToOnlineGame`) into the UCI move-token list this app already
/// stores moves as elsewhere (`ActiveCpuGame.moveUcis`,
/// `PuzzleModel.moves`). Reuses the same `chess` package parsing
/// `pgn_importer.dart` already relies on, rather than writing a second,
/// separate SAN parser for repertoire lines.
List<String> parseMoveSequenceToUci(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) {
    throw MoveSequenceParseException('手順を入力してください。');
  }

  final chess = chess_lib.Chess();
  final loaded = chess.load_pgn(trimmed);
  if (!loaded) {
    throw MoveSequenceParseException(
      '手順を解析できませんでした。「1. e4 e5 2. Nf3」のような形式で入力してください。',
    );
  }

  final verboseHistory =
      chess.getHistory({'verbose': true}).cast<Map<String, dynamic>>();
  if (verboseHistory.isEmpty) {
    throw MoveSequenceParseException('指し手が見つかりませんでした。');
  }

  return verboseHistory.map((move) {
    final from = move['from'] as String;
    final to = move['to'] as String;
    final san = move['san'] as String? ?? '';
    final promotionMatch = RegExp(r'=([QRBN])').firstMatch(san);
    final promotion = promotionMatch?.group(1)?.toLowerCase();
    return promotion == null ? '$from$to' : '$from$to$promotion';
  }).toList();
}
