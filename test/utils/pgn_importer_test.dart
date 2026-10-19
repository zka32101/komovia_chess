import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_chess/src/utils/pgn_importer.dart';
import 'package:komovia_chess/src/utils/pgn_builder.dart';
import 'package:komovia_chess/src/models/online_game.dart';

void main() {
  group('parsePgnToOnlineGame', () {
    test('parses a standard PGN with headers and moves', () {
      const pgn = '''
[Event "Test Game"]
[Site "Komovia Chess"]
[Date "2026.01.01"]
[White "Alice"]
[Black "Bob"]
[Result "1-0"]

1. e4 e5 2. Nf3 Nc6 3. Bb5 1-0
''';

      final game = parsePgnToOnlineGame(pgn);

      expect(game.whitePlayerName, 'Alice');
      expect(game.blackPlayerName, 'Bob');
      expect(game.result, 'white_win');
      expect(game.moves, hasLength(5));
      expect(game.moves.first.from, 'e2');
      expect(game.moves.first.to, 'e4');
    });

    test('parses a promotion move correctly', () {
      const pgn = '''
[Event "Promotion Test"]
[White "Alice"]
[Black "Bob"]
[Result "*"]

1. a4 h5 2. a5 h4 3. a6 h3 4. axb7 hxg2 5. bxa8=Q gxh1=Q *
''';

      final game = parsePgnToOnlineGame(pgn);

      final whitePromotion = game.moves[8];
      expect(whitePromotion.from, 'b7');
      expect(whitePromotion.to, 'a8');
      expect(whitePromotion.promotion, 'q');

      final blackPromotion = game.moves[9];
      expect(blackPromotion.from, 'g2');
      expect(blackPromotion.to, 'h1');
      expect(blackPromotion.promotion, 'q');
    });

    test('round-trips with buildPgn (export then re-import)', () {
      final original = OnlineGame(
        gameId: 'game_1',
        type: 'online_pvp',
        status: 'completed',
        createdAt: DateTime(2026, 1, 1),
        whitePlayerId: 'white_uid',
        blackPlayerId: 'black_uid',
        whitePlayerName: 'White Player',
        blackPlayerName: 'Black Player',
        whiteRating: 1500,
        blackRating: 1500,
        pgn: '',
        currentFen: 'rnbqkbnr/pppp1ppp/8/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq - 1 2',
        moves: [
          GameMove(
            moveNumber: 1,
            from: 'e2',
            to: 'e4',
            timestamp: DateTime(2026, 1, 1),
            playerId: 'white_uid',
          ),
          GameMove(
            moveNumber: 2,
            from: 'e7',
            to: 'e5',
            timestamp: DateTime(2026, 1, 1),
            playerId: 'black_uid',
          ),
          GameMove(
            moveNumber: 3,
            from: 'g1',
            to: 'f3',
            timestamp: DateTime(2026, 1, 1),
            playerId: 'white_uid',
          ),
        ],
        timeControl: 'blitz',
        timeControlMs: 300000,
        whiteTimeRemainingMs: 300000,
        blackTimeRemainingMs: 300000,
      );

      final exported = buildPgn(original);
      final reimported = parsePgnToOnlineGame(exported);

      expect(reimported.whitePlayerName, 'White Player');
      expect(reimported.blackPlayerName, 'Black Player');
      expect(reimported.moves, hasLength(3));
      expect(reimported.moves[0].from, 'e2');
      expect(reimported.moves[0].to, 'e4');
      expect(reimported.moves[2].from, 'g1');
      expect(reimported.moves[2].to, 'f3');
      // Black to move after White's 2nd move (1.e4 e5 2.Nf3).
      expect(reimported.currentFen.split(' ')[1], 'b');
    });

    test('throws PgnParseException for empty input', () {
      expect(() => parsePgnToOnlineGame(''), throwsA(isA<PgnParseException>()));
    });

    test('throws PgnParseException for unparseable text', () {
      expect(
        () => parsePgnToOnlineGame('this is not a pgn at all'),
        throwsA(isA<PgnParseException>()),
      );
    });

    test('result defaults to null when the PGN has no final result', () {
      const pgn = '''
[White "Alice"]
[Black "Bob"]

1. e4 e5 *
''';

      final game = parsePgnToOnlineGame(pgn);
      expect(game.result, isNull);
    });
  });
}
