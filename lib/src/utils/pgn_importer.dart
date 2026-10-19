import 'package:chess/chess.dart' as chess_lib;
import '../models/online_game.dart';

/// Thrown by [parsePgnToOnlineGame] when the given text isn't a parseable
/// PGN (malformed headers/movetext, or an illegal move sequence).
class PgnParseException implements Exception {
  PgnParseException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Parses a PGN transcript into a synthetic, never-persisted [OnlineGame]
/// suitable for local review via [GameReviewScreen] - the inverse of
/// `pgn_builder.dart`'s `buildPgn`. Previously this app could only export
/// PGN (from a game played here); there was no way to bring an external
/// game in for analysis at all, a one-directional gap every real
/// competitor (chess.com, lichess) closes with PGN upload/paste.
///
/// Purely local parsing - never touches Firestore, and the returned game
/// has no real participant uids (an imported game isn't attached to any
/// komovia_chess account on either side).
OnlineGame parsePgnToOnlineGame(String pgnText) {
  final trimmed = pgnText.trim();
  if (trimmed.isEmpty) {
    throw PgnParseException('PGNを入力してください。');
  }

  final chess = chess_lib.Chess();
  final loaded = chess.load_pgn(trimmed);
  if (!loaded) {
    throw PgnParseException(
      'PGNを解析できませんでした。形式を確認してください。',
    );
  }

  final verboseHistory =
      chess.getHistory({'verbose': true}).cast<Map<String, dynamic>>();
  if (verboseHistory.isEmpty) {
    throw PgnParseException('指し手が見つかりませんでした。');
  }

  final now = DateTime.now();
  final moves = <GameMove>[];
  for (var i = 0; i < verboseHistory.length; i++) {
    final move = verboseHistory[i];
    final san = move['san'] as String? ?? '';
    // make_pretty() (package:chess) doesn't expose a `promotion` field
    // directly on its verbose move map, only the SAN string - parse the
    // standard `=Q`/`=R`/`=B`/`=N` suffix ourselves.
    final promotionMatch = RegExp(r'=([QRBN])').firstMatch(san);
    moves.add(GameMove(
      moveNumber: i + 1,
      from: move['from'] as String,
      to: move['to'] as String,
      promotion: promotionMatch?.group(1)?.toLowerCase(),
      timestamp: now,
      playerId: i.isEven ? 'white' : 'black',
    ));
  }

  final header = chess.header;
  String? headerValue(String key) {
    final value = header[key];
    if (value is! String || value.trim().isEmpty) return null;
    return value.trim();
  }

  String? resolvedResult() {
    switch (headerValue('Result')) {
      case '1-0':
        return 'white_win';
      case '0-1':
        return 'black_win';
      case '1/2-1/2':
        return 'draw';
      default:
        return null;
    }
  }

  return OnlineGame(
    gameId: 'imported_${now.millisecondsSinceEpoch}',
    type: 'imported_pgn',
    status: 'completed',
    createdAt: now,
    whitePlayerId: 'imported_white',
    blackPlayerId: 'imported_black',
    whitePlayerName: headerValue('White') ?? 'White',
    blackPlayerName: headerValue('Black') ?? 'Black',
    whiteRating: 0,
    blackRating: 0,
    pgn: trimmed,
    currentFen: chess.fen,
    moves: moves,
    timeControl: 'unrated',
    timeControlMs: 0,
    whiteTimeRemainingMs: 0,
    blackTimeRemainingMs: 0,
    result: resolvedResult(),
  );
}
