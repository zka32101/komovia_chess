import 'package:chess/chess.dart' as chess_lib;
import '../models/online_game.dart';

/// Builds a standard PGN (Portable Game Notation) transcript for a
/// completed [OnlineGame] - every komovia_chess game starts from the
/// standard position (no handicap/setup variants, per
/// OnlineGameService.createGame), so replaying [game.moves] from there is
/// always correct.
///
/// Previously there was no PGN export anywhere in the app (only a GIF
/// share, via GameShareService) despite every finished game having a full
/// move list ready to turn into one - a feature every real competitor
/// (chess.com, lichess) offers for any finished game.
String buildPgn(OnlineGame game) {
  final chess = chess_lib.Chess();
  chess.set_header([
    'Event',
    'Komovia Chess',
    'Site',
    'Komovia Chess',
    'Date',
    _formatPgnDate(game.createdAt),
    'White',
    game.whitePlayerName,
    'Black',
    game.blackPlayerName,
    'Result',
    _pgnResult(game.result),
  ]);

  for (final move in game.moves) {
    if (move.from.isEmpty || move.to.isEmpty) continue; // pass/sentinel moves
    chess.move({
      'from': move.from,
      'to': move.to,
      if (move.promotion != null) 'promotion': move.promotion,
    });
  }

  return chess.pgn();
}

String _formatPgnDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}.'
    '${date.month.toString().padLeft(2, '0')}.'
    '${date.day.toString().padLeft(2, '0')}';

String _pgnResult(String? result) {
  switch (result) {
    case 'white_win':
      return '1-0';
    case 'black_win':
      return '0-1';
    case 'draw':
      return '1/2-1/2';
    default:
      return '*';
  }
}
