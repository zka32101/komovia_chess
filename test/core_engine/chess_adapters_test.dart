import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_chess/komovia_chess_engine.dart';
import 'package:komovia_chess/src/models/puzzle.dart';

void main() {
  group('ChessGame', () {
    test('white moves first (Side.first = white)', () {
      final game = ChessGame();
      final pos = game.initialPosition();
      expect(pos.sideToMove, Side.first);
    });

    test('checkmate (fool\'s mate) ends the game for the mated side', () {
      final game = ChessGame();
      var pos = game.initialPosition();
      Move drop(String from, String to, {bool promote = false}) =>
          BoardMove(from: squareFromAlgebraic(from), to: squareFromAlgebraic(to), promote: promote);
      // 1. f3 e5 2. g4 Qh4#
      pos = game.apply(pos, drop('f2', 'f3'));
      pos = game.apply(pos, drop('e7', 'e5'));
      pos = game.apply(pos, drop('g2', 'g4'));
      pos = game.apply(pos, drop('d8', 'h4'));
      final result = game.result(pos);
      expect(result.kind, ResultKind.win);
      expect(result.winner, Side.second);
      expect(result.reason, WinReason.checkmate);
      expect(game.legalMoves(pos), isEmpty);
    });

    test('stalemate ends the game as a draw', () {
      final game = ChessGame();
      // A known stalemate position: black king has no legal move and is
      // not in check.
      final pos = game.decode('7k/5Q2/6K1/8/8/8/8/8 b - - 0 1');
      final result = game.result(pos);
      expect(result.kind, ResultKind.draw);
      expect(result.reason, WinReason.stalemate);
    });

    test('insufficient material (K vs K) ends the game as a draw', () {
      final game = ChessGame();
      final pos = game.decode('8/8/8/4k3/8/4K3/8/8 w - - 0 1');
      final result = game.result(pos);
      expect(result.kind, ResultKind.draw);
      expect(result.reason, WinReason.agreement);
    });

    test('fifty-move rule ends the game as a draw', () {
      final game = ChessGame();
      final pos = game.decode('8/8/8/4k3/8/4K3/4R3/8 w - - 100 80');
      final result = game.result(pos);
      expect(result.kind, ResultKind.draw);
      expect(result.reason, WinReason.agreement);
    });

    test('threefold repetition (via historyKeys) ends the game as a draw', () {
      final game = ChessGame();
      final pos = game.initialPosition();
      final key = game.positionKey(pos);
      final historyKeys = [key, key, key];
      final result = game.result(pos, historyKeys: historyKeys);
      expect(result.kind, ResultKind.draw);
      expect(result.reason, WinReason.repetition);
    });

    test('promotion defaults to queen', () {
      final game = ChessGame();
      final pos = game.decode('8/P7/8/4k3/8/4K3/8/8 w - - 0 1');
      final afterPromote = game.apply(
        pos,
        BoardMove(from: squareFromAlgebraic('a7'), to: squareFromAlgebraic('a8'), promote: true),
      );
      expect(afterPromote.fen.split(' ')[0].startsWith('Q'), isTrue);
    });

    test('rejects a DropMove and PassMove (chess has neither)', () {
      final game = ChessGame();
      final pos = game.initialPosition();
      expect(
        () => game.apply(pos, const DropMove(pieceType: 'stone', to: Square(0, 0))),
        throwsArgumentError,
      );
      expect(() => game.apply(pos, const PassMove()), throwsArgumentError);
    });

    test('resignation ends the game for the opponent', () {
      final game = ChessGame();
      final pos = game.initialPosition();
      final afterResign = game.apply(pos, ResignMove(pos.sideToMove));
      final result = game.result(afterResign);
      expect(result.winner, Side.second);
      expect(result.reason, WinReason.resignation);
    });

    test('exportRecord/importRecord round-trips a real game including result', () {
      final game = ChessGame();
      final moves = <RecordedMove>[
        RecordedMove(number: 1, side: Side.first, move: BoardMove(from: squareFromAlgebraic('f2'), to: squareFromAlgebraic('f3'))),
        RecordedMove(number: 1, side: Side.second, move: BoardMove(from: squareFromAlgebraic('e7'), to: squareFromAlgebraic('e5'))),
        RecordedMove(number: 2, side: Side.first, move: BoardMove(from: squareFromAlgebraic('g2'), to: squareFromAlgebraic('g4'))),
        RecordedMove(number: 2, side: Side.second, move: BoardMove(from: squareFromAlgebraic('d8'), to: squareFromAlgebraic('h4'))),
      ];
      final record = GameRecord(
        gameId: 'chess',
        moves: moves,
        result: const GameResult.win(Side.second, WinReason.checkmate),
      );
      final pgn = game.exportRecord(record);
      expect(pgn, isNot(contains('1-0')));
      expect(pgn, contains('0-1'));
      final imported = game.importRecord(pgn);
      expect(imported.result, const GameResult.win(Side.second, WinReason.checkmate));
      expect(imported.moves.length, 4);
      expect(game.exportRecord(imported), pgn);
    });
  });

  group('ChessPuzzle', () {
    test('wraps a PuzzleModel into a Puzzle with a real move-by-move solution', () {
      final puzzle = PuzzleModel(
        id: 'p1',
        fen: 'r3k2r/pp1n1ppp/2p1p3/q7/2PP4/2NB4/PPQ2PPP/R3K2R w - - 0 1',
        moves: ['c2h7'],
        rating: 1500,
        themes: const ['fork', 'middlegame'],
      );
      final wrapped = ChessPuzzle.fromPuzzleModel(puzzle, gameId: 'chess');
      expect(wrapped.gameId, 'chess');
      expect(wrapped.solution, isNotEmpty);
      expect(wrapped.solution.single, BoardMove(from: squareFromAlgebraic('c2'), to: squareFromAlgebraic('h7')));
      expect(wrapped.metadata['rating'], 1500);
      expect(wrapped.title, 'fork, middlegame');
    });
  });
}
