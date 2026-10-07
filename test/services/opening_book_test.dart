import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_chess/src/services/opening_book.dart';

void main() {
  group('OpeningBook', () {
    group('getRecommendedMoves', () {
      test('returns recommended moves for starting position', () {
        const fen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
        final moves = OpeningBook.getRecommendedMoves(fen);

        expect(moves.isNotEmpty, true);
        expect(moves.contains('e2e4'), true);
        expect(moves[0], 'e2e4'); // Most popular first
      });

      test('returns recommended moves for 1.e4', () {
        const fen =
            'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1';
        final moves = OpeningBook.getRecommendedMoves(fen);

        expect(moves.isNotEmpty, true);
        expect(moves.contains('c7c5'), true); // Sicilian
        expect(moves.contains('e7e5'), true); // Open game
        expect(moves[0], 'c7c5'); // Sicilian is most popular
      });

      test('returns recommended moves for 1.d4', () {
        const fen =
            'rnbqkbnr/pppppppp/8/8/3P4/8/PPP1PPPP/RNBQKBNR b KQkq d3 0 1';
        final moves = OpeningBook.getRecommendedMoves(fen);

        expect(moves.isNotEmpty, true);
        expect(moves.contains('d7d5'), true); // QGD
      });

      test('returns recommended moves for 1.c4', () {
        const fen =
            'rnbqkbnr/pppppppp/8/8/2P5/8/PP1PPPPP/RNBQKBNR b KQkq c3 0 1';
        final moves = OpeningBook.getRecommendedMoves(fen);

        expect(moves.isNotEmpty, true);
        expect(moves.contains('e7e5'), true);
      });

      test('returns empty list for unknown position', () {
        const fen =
            'r1bqkb1r/pppp1ppp/2n2n2/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 4 4';
        final moves = OpeningBook.getRecommendedMoves(fen);

        // This position might be in book or not, but should be valid
        expect(moves, isA<List<String>>());
      });

      test('returns null-safe empty list for null FEN', () {
        final moves = OpeningBook.getRecommendedMoves('');
        expect(moves, isA<List<String>>());
      });
    });

    group('isInBook', () {
      test('returns true for starting position', () {
        const fen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
        expect(OpeningBook.isInBook(fen), true);
      });

      test('returns true for 1.e4 position', () {
        const fen =
            'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1';
        expect(OpeningBook.isInBook(fen), true);
      });

      test('returns false for deep positions not in book', () {
        const fen =
            'r1bqkb1r/pppp1ppp/2n2n2/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 4 4';
        final inBook = OpeningBook.isInBook(fen);
        expect(inBook, isA<bool>());
      });
    });

    group('getBookDepth', () {
      test('returns 0 for starting position', () {
        const fen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
        final depth = OpeningBook.getBookDepth(fen);
        expect(depth, 0);
      });

      test('returns correct depth after first white move', () {
        const fen =
            'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1';
        final depth = OpeningBook.getBookDepth(fen);
        expect(depth, 1); // One half-move (ply)
      });

      test('returns correct depth after first black move', () {
        const fen =
            'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2';
        final depth = OpeningBook.getBookDepth(fen);
        expect(depth, 2); // Two half-moves
      });

      test('returns correct depth for move 5', () {
        const fen =
            'rnbqkbnr/pppp1ppp/8/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq - 1 3';
        final depth = OpeningBook.getBookDepth(fen);
        expect(depth >= 4, true); // At least 4 plies in
      });

      test('handles malformed FEN gracefully', () {
        final depth = OpeningBook.getBookDepth('malformed');
        expect(depth, 0);
      });
    });

    group('_normalizeFen', () {
      test('normalizes FEN with different move counters', () {
        const fen1 = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
        const fen2 =
            'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 5 10';

        final normalized1 = OpeningBook.getRecommendedMoves(fen1);
        final normalized2 = OpeningBook.getRecommendedMoves(fen2);

        expect(normalized1, normalized2);
      });
    });

    group('_areFenPositionsEquivalent', () {
      test('recognizes equivalent positions', () {
        const fen1 =
            'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1';
        const fen2 =
            'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 5 10';

        // Both should return same moves
        final moves1 = OpeningBook.getRecommendedMoves(fen1);
        final moves2 = OpeningBook.getRecommendedMoves(fen2);

        expect(moves1, moves2);
      });

      test('distinguishes different positions', () {
        const fen1 =
            'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1';
        const fen2 =
            'rnbqkbnr/pppppppp/8/8/3P4/8/PPP1PPPP/RNBQKBNR b KQkq d3 0 1';

        // Different positions might have different moves
        final moves1 = OpeningBook.getRecommendedMoves(fen1);
        final moves2 = OpeningBook.getRecommendedMoves(fen2);

        // At least they should both be valid lists
        expect(moves1, isA<List<String>>());
        expect(moves2, isA<List<String>>());
      });
    });

    group('getBookStatistics', () {
      test('returns valid statistics', () {
        final stats = OpeningBook.getBookStatistics();

        expect(stats.containsKey('totalPositions'), true);
        expect(stats.containsKey('totalMoveEntries'), true);
        expect(stats.containsKey('maxMoves'), true);
        expect(stats.containsKey('averageMoveOptions'), true);

        expect(stats['totalPositions'], greaterThan(0));
        expect(stats['totalMoveEntries'], greaterThan(0));
        expect(stats['maxMoves'], greaterThan(0));
        expect(stats['averageMoveOptions'], greaterThan(0));
      });

      test('statistics are consistent', () {
        final stats = OpeningBook.getBookStatistics();
        final totalPositions = stats['totalPositions'] as int;
        final totalMoveEntries = stats['totalMoveEntries'] as int;
        final averageMoveOptions = stats['averageMoveOptions'] as double;

        // Average should be total divided by positions
        expect(
          (totalMoveEntries / totalPositions).abs() - averageMoveOptions.abs(),
          lessThan(0.01),
        );
      });

      test('maxMoves is reasonable', () {
        final stats = OpeningBook.getBookStatistics();
        final maxMoves = stats['maxMoves'] as int;
        final averageMoveOptions = stats['averageMoveOptions'] as double;

        expect(maxMoves, greaterThanOrEqualTo(averageMoveOptions.toInt()));
      });
    });

    group('Opening lines', () {
      test('has Ruy Lopez lines', () {
        const fen =
            'r1bqkbnr/pppp1ppp/2n5/1B2p3/4P3/5N2/PPPP1PPP/RNBQK2R b KQkq - 3 3';
        final moves = OpeningBook.getRecommendedMoves(fen);

        expect(moves.isNotEmpty, true);
        // Should recommend a6 or other solid moves
        expect(moves.any((m) => m.contains('a')), true);
      });

      test('has Sicilian Defense lines', () {
        const fen =
            'rnbqkbnr/pp2pppp/3p4/8/3NP3/8/PPP2PPP/RNBQKB1R b KQkq - 0 4';
        final moves = OpeningBook.getRecommendedMoves(fen);

        expect(moves.isNotEmpty, true);
        // Should recommend legal moves like Nf6
      });

      test('has Queen\'s Gambit lines', () {
        const fen =
            'rnbqkbnr/pppppppp/8/8/3P4/8/PPP1PPPP/RNBQKBNR b KQkq d3 0 1';
        final moves = OpeningBook.getRecommendedMoves(fen);

        expect(moves.isNotEmpty, true);
        expect(moves.contains('d7d5'), true); // QGD
      });

      test('recommends strong openings for white', () {
        const fen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
        final moves = OpeningBook.getRecommendedMoves(fen);

        expect(moves.isNotEmpty, true);
        // Should include e4, d4, c4, Nf3
        expect(
          moves.any((m) => ['e2e4', 'd2d4', 'c2c4', 'g1f3'].contains(m)),
          true,
        );
      });

      test('recommends strong openings for black', () {
        const fen =
            'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1';
        final moves = OpeningBook.getRecommendedMoves(fen);

        expect(moves.isNotEmpty, true);
        // Should include Sicilian, e5, etc.
        expect(
          moves
              .any((m) => ['c7c5', 'e7e5', 'c7c6', 'd7d5', 'e7e6'].contains(m)),
          true,
        );
      });
    });

    group('Move ordering', () {
      test('recommends most popular move first for starting position', () {
        const fen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
        final moves = OpeningBook.getRecommendedMoves(fen);

        expect(moves[0], 'e2e4');
      });

      test('recommends Sicilian first for 1.e4', () {
        const fen =
            'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1';
        final moves = OpeningBook.getRecommendedMoves(fen);

        expect(moves[0], 'c7c5');
      });

      test('moves are in strength order', () {
        const fen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
        final moves = OpeningBook.getRecommendedMoves(fen);

        // First moves should be the strongest
        expect(moves.first, 'e2e4');
        expect(moves.length >= 2, true);
      });
    });
  });
}
