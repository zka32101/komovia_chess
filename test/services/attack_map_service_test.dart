import 'package:chess/chess.dart' as chess_lib;
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_chess/src/services/attack_map_service.dart';

void main() {
  group('AttackMapService.compute', () {
    test('a defended pawn is attacked and defended by one piece each', () {
      // White pawn on d4, defended by White's bishop on c3 and attacked
      // by Black's bishop on f6 - a classic "even trade if taken" square.
      final chess =
          chess_lib.Chess.fromFEN('4k3/8/5b2/8/3P4/2B5/8/4K3 w - - 0 1');
      final map = AttackMapService.compute(chess);

      final d4 = map['d4']!;
      expect(d4.white, 1); // the c3 bishop defends it
      expect(d4.black, 1); // the f6 bishop attacks it
      expect(d4.isContested, isTrue);
    });

    test('a hanging (undefended) piece has attackers but no defenders', () {
      // White rook on d4 with nothing of White's own defending it, while
      // Black's bishop on g7 attacks it along the long diagonal.
      final chess = chess_lib.Chess.fromFEN('4k3/6b1/8/8/3R4/8/8/4K3 w - - 0 1');
      final map = AttackMapService.compute(chess);

      final d4 = map['d4']!;
      expect(d4.white, 0);
      expect(d4.black, 1);
      expect(d4.isContested, isFalse);
    });

    test('a square attacked by multiple pieces of one side counts all of them',
        () {
      // Black king on e5 is attacked by White's rook on e1 (down the
      // e-file) AND White's bishop on a1 (up the long diagonal) - two
      // separate White attackers on the same square.
      final chess = chess_lib.Chess.fromFEN('8/8/8/4k3/8/8/8/B3R2K w - - 0 1');
      final map = AttackMapService.compute(chess);

      final e5 = map['e5']!;
      expect(e5.white, 2);
      expect(e5.black, 0);
    });

    test('a contested square is attacked by both sides at once', () {
      // e4 is attacked by White's knight on c3 and Black's knight on c5 -
      // both sides have exactly one attacker on the same square.
      final chess =
          chess_lib.Chess.fromFEN('4k3/8/8/2n5/8/2N5/8/4K3 w - - 0 1');
      final map = AttackMapService.compute(chess);

      final e4 = map['e4']!;
      expect(e4.white, 1);
      expect(e4.black, 1);
      expect(e4.isContested, isTrue);
    });

    test('a sliding piece is blocked by any piece in its path, friend or foe',
        () {
      // White rook on a1, White pawn on a3, then empty a4+. The rook
      // attacks/defends a2 and a3 (the blocker itself), but NOT a4, a5...
      // even though nothing of the opponent's is in the way either - the
      // blocker is White's own pawn, which still fully blocks the ray.
      final chess = chess_lib.Chess.fromFEN('4k3/8/8/8/8/P7/8/R3K3 w - - 0 1');
      final map = AttackMapService.compute(chess);

      expect(map['a2']!.white, 1); // empty square before the blocker
      expect(map['a3']!.white, 1); // the blocking pawn itself is "defended"
      expect(map.containsKey('a4'), isFalse); // nothing attacks past it
      expect(map.containsKey('a5'), isFalse);
    });

    test('a sliding piece is likewise blocked by an enemy piece in its path',
        () {
      // White rook on a1, Black pawn on a3. The rook attacks a2 and a3
      // (the enemy blocker, capturable) but not a4+ beyond it.
      final chess = chess_lib.Chess.fromFEN('4k3/8/8/8/8/p7/8/R3K3 w - - 0 1');
      final map = AttackMapService.compute(chess);

      expect(map['a2']!.white, 1);
      expect(map['a3']!.white, 1);
      expect(map.containsKey('a4'), isFalse);
    });

    test('pawns attack diagonally, never straight ahead', () {
      // A lone White pawn on d4 with empty diagonals and an empty square
      // directly ahead - d5 (where it moves) must NOT be counted as
      // attacked, only c5 and e5 (where it could capture).
      final chess = chess_lib.Chess.fromFEN('4k3/8/8/8/3P4/8/8/4K3 w - - 0 1');
      final map = AttackMapService.compute(chess);

      expect(map.containsKey('d5'), isFalse);
      expect(map['c5']!.white, 1);
      expect(map['e5']!.white, 1);
    });

    test('black pawns attack diagonally toward rank 1', () {
      final chess = chess_lib.Chess.fromFEN('4k3/8/8/3p4/8/8/8/4K3 b - - 0 1');
      final map = AttackMapService.compute(chess);

      expect(map.containsKey('d4'), isFalse); // straight ahead, not an attack
      expect(map['c4']!.black, 1);
      expect(map['e4']!.black, 1);
    });

    test('a knight jumps over any intervening piece', () {
      // White knight on b1 surrounded by its own pawns on a2/b2/c2 still
      // reaches d2 - a square none of those pawns also attack - proving
      // the knight's own path was never blocked by them. The white king
      // is parked on h1, well out of range of d2, so it can't contribute
      // a second attacker there and confound the count.
      final chess =
          chess_lib.Chess.fromFEN('4k3/8/8/8/8/8/PPP5/1N5K w - - 0 1');
      final map = AttackMapService.compute(chess);

      expect(map['d2']!.white, 1);
    });

    test('an empty board position has no entries at all', () {
      // A bare two-king endgame with no other pieces: each king attacks
      // its own adjacent squares, so the map is non-empty but every
      // entry comes only from the kings themselves.
      final chess = chess_lib.Chess.fromFEN('8/8/8/4k3/8/8/4K3/8 w - - 0 1');
      final map = AttackMapService.compute(chess);

      // Kings are 3 ranks apart, so their attack sets don't overlap.
      expect(map.containsKey('e3'), isTrue); // adjacent to the white king on e2
      expect(map.containsKey('e4'), isTrue); // adjacent to the black king on e5
      for (final attackers in map.values) {
        expect(attackers.isContested, isFalse);
      }
    });

    test('SquareAttackers.isEmpty is true only with zero attackers both sides',
        () {
      expect(const SquareAttackers().isEmpty, isTrue);
      expect(const SquareAttackers(white: 1).isEmpty, isFalse);
      expect(const SquareAttackers(black: 1).isEmpty, isFalse);
    });
  });
}
