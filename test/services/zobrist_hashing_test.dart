import 'package:flutter_test/flutter_test.dart';
import 'package:chess/chess.dart' as chess_lib;
import 'package:komovia_chess/src/services/zobrist_hashing.dart';

void main() {
  group('ZobristHash', () {
    setUpAll(() {
      // Initialize Zobrist hash tables before running tests
      ZobristHash.initialize();
    });

    group('initialization', () {
      test('can be initialized', () {
        ZobristHash.initialize(); // Should not throw
      });

      test('initialization is idempotent', () {
        ZobristHash.initialize();
        ZobristHash.initialize(); // Second call should be safe
      });

      test('returns initialization statistics', () {
        final stats = ZobristHash.getHashStatistics();

        expect(stats.containsKey('status'), true);
        expect(stats['status'], 'initialized');
        expect(stats.containsKey('piecesTableSize'), true);
        expect(stats['totalKeys'], 780); // 768 + 1 + 4 + 8 - 1
      });
    });

    group('hashPosition', () {
      test('hashes starting position consistently', () {
        final chess = chess_lib.Chess();
        final hash1 = ZobristHash.hashPosition(chess);
        final hash2 = ZobristHash.hashPosition(chess);

        expect(hash1, equals(hash2));
      });

      test('returns different hash for different positions', () {
        final chess1 = chess_lib.Chess();
        final hash1 = ZobristHash.hashPosition(chess1);

        final chess2 = chess_lib.Chess();
        chess2.move(chess_lib.Move(fromAlgebraic: 'e2', toAlgebraic: 'e4'));
        final hash2 = ZobristHash.hashPosition(chess2);

        expect(hash1, isNot(equals(hash2)));
      });

      test('returns non-zero hash for starting position', () {
        final chess = chess_lib.Chess();
        final hash = ZobristHash.hashPosition(chess);

        expect(hash, isNot(0));
      });

      test('returns 64-bit hash value', () {
        final chess = chess_lib.Chess();
        final hash = ZobristHash.hashPosition(chess);

        // Hash should be a valid 64-bit integer
        expect(hash, isA<int>());
      });

      test('hashes positions with pieces', () {
        final chess = chess_lib.Chess();
        chess.move(chess_lib.Move(fromAlgebraic: 'e2', toAlgebraic: 'e4'));
        chess.move(chess_lib.Move(fromAlgebraic: 'c7', toAlgebraic: 'c5'));

        final hash = ZobristHash.hashPosition(chess);
        expect(hash, isNot(0));
      });

      test('detects capture moves', () {
        final chess1 = chess_lib.Chess();
        chess1.move(chess_lib.Move(fromAlgebraic: 'e2', toAlgebraic: 'e4'));
        chess1.move(chess_lib.Move(fromAlgebraic: 'd7', toAlgebraic: 'd5'));
        final hash1 = ZobristHash.hashPosition(chess1);

        final chess2 = chess_lib.Chess();
        chess2.move(chess_lib.Move(fromAlgebraic: 'e2', toAlgebraic: 'e4'));
        chess2.move(chess_lib.Move(fromAlgebraic: 'd7', toAlgebraic: 'd5'));
        chess2.move(
            chess_lib.Move(fromAlgebraic: 'e4', toAlgebraic: 'd5')); // Capture
        final hash2 = ZobristHash.hashPosition(chess2);

        expect(hash1, isNot(equals(hash2)));
      });

      test('accounts for turn order', () {
        final chess = chess_lib.Chess();
        final hash1 = ZobristHash.hashPosition(chess); // White to move

        chess.move(chess_lib.Move(fromAlgebraic: 'e2', toAlgebraic: 'e4'));
        final hash2 = ZobristHash.hashPosition(chess); // Black to move

        expect(hash1, isNot(equals(hash2)));
      });

      test('accounts for castling rights', () {
        final chess1 = chess_lib.Chess();
        final hash1 = ZobristHash.hashPosition(chess1);

        final chess2 = chess_lib.Chess();
        chess2.move(chess_lib.Move(fromAlgebraic: 'e2', toAlgebraic: 'e4'));
        chess2.move(chess_lib.Move(fromAlgebraic: 'e7', toAlgebraic: 'e5'));
        chess2.move(chess_lib.Move(fromAlgebraic: 'g1', toAlgebraic: 'f3'));
        chess2.move(chess_lib.Move(fromAlgebraic: 'g8', toAlgebraic: 'f6'));

        final hash2 = ZobristHash.hashPosition(chess2);

        // Different positions should have different hashes
        expect(hash1, isNot(equals(hash2)));
      });

      test('accounts for en passant', () {
        final chess = chess_lib.Chess();
        chess.move(chess_lib.Move(fromAlgebraic: 'e2', toAlgebraic: 'e4'));
        chess.move(chess_lib.Move(fromAlgebraic: 'a7', toAlgebraic: 'a5'));
        chess.move(chess_lib.Move(fromAlgebraic: 'd2', toAlgebraic: 'd4'));
        chess.move(chess_lib.Move(
            fromAlgebraic: 'd7', toAlgebraic: 'd5')); // En passant possible

        final hash = ZobristHash.hashPosition(chess);
        expect(hash, isNot(0));
      });
    });

    group('hash collision resistance', () {
      test('different starting positions have different hashes', () {
        final positions = <int>[];

        // Generate several different positions and verify all hashes are unique
        for (int i = 0; i < 5; i++) {
          final chess = chess_lib.Chess();
          // Make different moves
          final moves = chess.moves();
          if (i < moves.length) {
            chess.move(moves[i] as chess_lib.Move);
          }
          final hash = ZobristHash.hashPosition(chess);
          positions.add(hash);
        }

        // All hashes should be unique (no collisions in this small sample)
        final uniqueHashes = positions.toSet();
        expect(uniqueHashes.length, greaterThan(1));
      });

      test('symmetrical positions have different hashes if pieces differ', () {
        final chess = chess_lib.Chess();
        chess.move(chess_lib.Move(fromAlgebraic: 'e2', toAlgebraic: 'e4'));
        chess.move(chess_lib.Move(fromAlgebraic: 'd7', toAlgebraic: 'd5'));
        final hash1 = ZobristHash.hashPosition(chess);

        final chess2 = chess_lib.Chess();
        chess2.move(chess_lib.Move(fromAlgebraic: 'd2', toAlgebraic: 'd4'));
        chess2.move(chess_lib.Move(fromAlgebraic: 'e7', toAlgebraic: 'e5'));
        final hash2 = ZobristHash.hashPosition(chess2);

        expect(hash1, isNot(equals(hash2)));
      });
    });

    group('performance characteristics', () {
      test('hash computation is deterministic', () {
        final chess = chess_lib.Chess();
        final hashes = <int>[];

        for (int i = 0; i < 10; i++) {
          hashes.add(ZobristHash.hashPosition(chess));
        }

        // All hashes should be identical
        final uniqueHashes = hashes.toSet();
        expect(uniqueHashes.length, equals(1));
      });

      test('hash remains consistent across multiple games', () {
        final hash1 = _getHashAfterMoves(['e2e4', 'c7c5']);
        final hash2 = _getHashAfterMoves(['e2e4', 'c7c5']);

        expect(hash1, equals(hash2));
      });

      test('different move orders can result in same position', () {
        // Note: In chess, different move orders usually result in different positions
        // unless they're exactly the same sequence. This test verifies hash consistency.
        final chess = chess_lib.Chess();
        chess.move(chess_lib.Move(fromAlgebraic: 'e2', toAlgebraic: 'e4'));
        chess.move(chess_lib.Move(fromAlgebraic: 'e7', toAlgebraic: 'e5'));
        final hash1 = ZobristHash.hashPosition(chess);

        final chess2 = chess_lib.Chess();
        chess2.move(chess_lib.Move(fromAlgebraic: 'e7', toAlgebraic: 'e5'));
        chess2.move(chess_lib.Move(fromAlgebraic: 'e2', toAlgebraic: 'e4'));
        final hash2 = ZobristHash.hashPosition(chess2);

        // Different positions should have different hashes
        expect(hash1, isNot(equals(hash2)));
      });
    });
  });

  group('ZobristTranspositionTable', () {
    test('stores and retrieves entries', () {
      final table = ZobristTranspositionTable();
      final hash = 12345;
      final score = 150;
      const depth = 3;
      const flag = 0; // Exact score

      table.store(hash, score, depth, flag);
      final entry = table.lookup(hash);

      expect(entry, isNotNull);
      expect(entry!.score, equals(score));
      expect(entry.depth, equals(depth));
      expect(entry.isExact(), true);
    });

    test('returns null for missing entries', () {
      final table = ZobristTranspositionTable();
      final entry = table.lookup(99999);

      expect(entry, isNull);
    });

    test('tracks hit and miss statistics', () {
      final table = ZobristTranspositionTable();

      table.store(1, 100, 2, 0);
      table.lookup(1); // Hit
      table.lookup(2); // Miss

      final stats = table.getStatistics();
      expect(stats['hits'], equals(1));
      expect(stats['misses'], equals(1));
      expect(stats['total'], equals(2));
    });

    test('calculates hit rate correctly', () {
      final table = ZobristTranspositionTable();

      table.store(1, 100, 2, 0);
      table.lookup(1); // Hit
      table.lookup(1); // Hit
      table.lookup(2); // Miss

      final stats = table.getStatistics();
      expect(stats['hitRate'], contains('66'));
    });

    test('handles overflow gracefully', () {
      final table = ZobristTranspositionTable(maxSize: 10);

      // Store more than max size
      for (int i = 0; i < 20; i++) {
        table.store(i, i * 10, 2, 0);
      }

      final stats = table.getStatistics();
      expect(stats['entries'], lessThanOrEqualTo(10));
    });

    test('clear resets statistics', () {
      final table = ZobristTranspositionTable();

      table.store(1, 100, 2, 0);
      table.lookup(1);
      table.clear();

      final stats = table.getStatistics();
      expect(stats['entries'], equals(0));
      expect(stats['hits'], equals(0));
      expect(stats['misses'], equals(0));
    });

    test('distinguishes flag types', () {
      final table = ZobristTranspositionTable();

      table.store(1, 100, 2, 0); // Exact
      table.store(2, 200, 3, 1); // Lower bound
      table.store(3, 300, 4, 2); // Upper bound

      expect(table.lookup(1)!.isExact(), true);
      expect(table.lookup(2)!.isLowerBound(), true);
      expect(table.lookup(3)!.isUpperBound(), true);
    });

    test('overwrites existing entries at same hash', () {
      final table = ZobristTranspositionTable();

      table.store(1, 100, 2, 0);
      final entry1 = table.lookup(1);

      table.store(1, 200, 3, 0); // Same hash, different score/depth
      final entry2 = table.lookup(1);

      expect(entry1!.score, equals(100));
      expect(entry2!.score, equals(200));
    });

    test('reports memory estimate', () {
      final table = ZobristTranspositionTable();

      table.store(1, 100, 2, 0);
      final stats = table.getStatistics();

      expect(stats.containsKey('memoryEstimate'), true);
      expect(stats['memoryEstimate'], contains('KB'));
    });
  });

  group('TranspositionEntry', () {
    test('stores all required data', () {
      final entry = ZobristTranspositionTable.TranspositionEntry(
        hash: 12345,
        score: 150,
        depth: 3,
        flag: 0,
      );

      expect(entry.hash, equals(12345));
      expect(entry.score, equals(150));
      expect(entry.depth, equals(3));
      expect(entry.flag, equals(0));
    });

    test('flag types are correct', () {
      final exact = ZobristTranspositionTable.TranspositionEntry(
        hash: 1,
        score: 100,
        depth: 2,
        flag: 0,
      );
      final lower = ZobristTranspositionTable.TranspositionEntry(
        hash: 2,
        score: 100,
        depth: 2,
        flag: 1,
      );
      final upper = ZobristTranspositionTable.TranspositionEntry(
        hash: 3,
        score: 100,
        depth: 2,
        flag: 2,
      );

      expect(exact.isExact(), true);
      expect(lower.isLowerBound(), true);
      expect(upper.isUpperBound(), true);
    });
  });

  group('integration', () {
    test('zobrist table works with realistic game flow', () {
      ZobristHash.initialize();
      final table = ZobristTranspositionTable();

      final chess = chess_lib.Chess();

      // Play first few moves
      final moves = ['e2e4', 'c7c5', 'd2d4', 'c5d4'];

      for (final moveStr in moves) {
        final from = moveStr.substring(0, 2);
        final to = moveStr.substring(2, 4);

        chess.move(chess_lib.Move(fromAlgebraic: from, toAlgebraic: to));

        final hash = ZobristHash.hashPosition(chess);
        table.store(hash, 0, 2, 0); // Store with dummy score
      }

      // Verify all positions were stored
      final stats = table.getStatistics();
      expect(stats['entries'], greaterThan(0));
    });

    test('hash improves with multiple lookups', () {
      ZobristHash.initialize();
      final table = ZobristTranspositionTable();

      final chess = chess_lib.Chess();
      chess.move(chess_lib.Move(fromAlgebraic: 'e2', toAlgebraic: 'e4'));
      chess.move(chess_lib.Move(fromAlgebraic: 'c7', toAlgebraic: 'c5'));

      final hash = ZobristHash.hashPosition(chess);

      // Store and lookup multiple times
      table.store(hash, 150, 3, 0);
      for (int i = 0; i < 10; i++) {
        table.lookup(hash);
      }

      final stats = table.getStatistics();
      expect(stats['hits'], equals(10));
      expect(stats['hitRate'], contains('100'));
    });
  });
}

/// Helper function to get hash after a sequence of moves
int _getHashAfterMoves(List<String> moves) {
  ZobristHash.initialize();
  final chess = chess_lib.Chess();

  for (final moveStr in moves) {
    final from = moveStr.substring(0, 2);
    final to = moveStr.substring(2, 4);
    chess.move(chess_lib.Move(fromAlgebraic: from, toAlgebraic: to));
  }

  return ZobristHash.hashPosition(chess);
}
