import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_chess/src/services/opening_explorer_service.dart';

OpeningGameMoves _game(String result, List<String> tokens) {
  final moves = tokens.map((token) {
    final withoutPromotion = token.split('=').first;
    final promotion = token.contains('=') ? token.split('=').last : null;
    return {
      'from': withoutPromotion.substring(0, 2),
      'to': withoutPromotion.substring(2, 4),
      'promotion': promotion,
    };
  }).toList();
  return OpeningGameMoves(result: result, moves: moves);
}

void main() {
  group('OpeningExplorerService.getCandidateMoves', () {
    late OpeningExplorerService service;

    setUp(() {
      service = OpeningExplorerService(firestore: FakeFirebaseFirestore());
    });

    test('returns no candidates when there are no games', () {
      final candidates = service.getCandidateMoves([], []);
      expect(candidates, isEmpty);
    });

    test('aggregates the first move across several games', () {
      final games = [
        _game('win', ['e2e4', 'e7e5']),
        _game('win', ['e2e4', 'c7c5']),
        _game('loss', ['d2d4', 'd7d5']),
      ];

      final candidates = service.getCandidateMoves(games, []);

      expect(candidates, hasLength(2));
      final e4 = candidates.firstWhere((c) => c.move == 'e2e4');
      expect(e4.games, 2);
      expect(e4.wins, 2);
      expect(e4.winRate, 1.0);

      final d4 = candidates.firstWhere((c) => c.move == 'd2d4');
      expect(d4.games, 1);
      expect(d4.losses, 1);
    });

    test('only counts games matching the given path prefix', () {
      final games = [
        _game('win', ['e2e4', 'e7e5', 'g1f3']),
        _game('draw', ['e2e4', 'c7c5', 'g1f3']),
        _game('loss', ['d2d4', 'd7d5']),
      ];

      final candidates = service.getCandidateMoves(games, ['e2e4']);

      expect(candidates, hasLength(2));
      final totalGames =
          candidates.fold<int>(0, (sum, c) => sum + c.games);
      expect(totalGames, 2);
    });

    test('games shorter than the path are excluded', () {
      final games = [
        _game('win', ['e2e4']),
        _game('win', ['e2e4', 'e7e5']),
      ];

      final candidates = service.getCandidateMoves(games, ['e2e4']);

      expect(candidates, hasLength(1));
      expect(candidates.first.move, 'e7e5');
    });

    test('returns no candidates once a position is a leaf for every game',
        () {
      final games = [
        _game('win', ['e2e4', 'e7e5']),
        _game('loss', ['e2e4', 'e7e5']),
      ];

      final candidates = service.getCandidateMoves(games, ['e2e4', 'e7e5']);

      expect(candidates, isEmpty);
    });

    test('distinguishes promotion choices as separate moves', () {
      final games = [
        _game('win', ['a1a2', 'b1b2', 'b7b8=q']),
        _game('loss', ['a1a2', 'b1b2', 'b7b8=n']),
      ];

      final candidates = service.getCandidateMoves(games, ['a1a2', 'b1b2']);

      expect(candidates, hasLength(2));
      expect(candidates.any((c) => c.move == 'b7b8=q'), isTrue);
      expect(candidates.any((c) => c.move == 'b7b8=n'), isTrue);
    });

    test('sorts candidates by game count descending', () {
      final games = [
        _game('win', ['d2d4']),
        _game('win', ['e2e4']),
        _game('win', ['e2e4']),
        _game('win', ['e2e4']),
      ];

      final candidates = service.getCandidateMoves(games, []);

      expect(candidates.first.move, 'e2e4');
      expect(candidates.first.games, 3);
    });
  });
}
