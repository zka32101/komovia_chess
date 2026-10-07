import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_chess/src/providers/online_game_provider.dart';

void main() {
  group('ELO Rating Calculation', () {
    late OnlineGameService gameService;

    setUp(() {
      gameService = OnlineGameService(null, null);
    });

    test('calculates equal rating win', () {
      const whiteRating = 1600;
      const blackRating = 1600;

      final deltas = gameService.calculateRatingDeltas(
        'white_win',
        whiteRating,
        blackRating,
      );

      expect(deltas['white'], isPositive);
      expect(deltas['black'], isNegative);
      expect(deltas['white'], equals(16)); // K=32, expected=0.5, actual=1.0
      expect(deltas['black'], equals(-16));
    });

    test('calculates higher rated player win', () {
      const whiteRating = 1700;
      const blackRating = 1500;

      final deltas = gameService.calculateRatingDeltas(
        'white_win',
        whiteRating,
        blackRating,
      );

      // Lower rated player winning loses less
      expect(deltas['white'], lessThan(16));
      expect(deltas['black'], greaterThan(-16));
    });

    test('calculates lower rated player win (upset)', () {
      const whiteRating = 1500;
      const blackRating = 1700;

      final deltas = gameService.calculateRatingDeltas(
        'white_win',
        whiteRating,
        blackRating,
      );

      // Lower rated player winning gains more
      expect(deltas['white'], greaterThan(16));
      expect(deltas['black'], lessThan(-16));
    });

    test('calculates draw correctly', () {
      const whiteRating = 1600;
      const blackRating = 1600;

      final deltas = gameService.calculateRatingDeltas(
        'draw',
        whiteRating,
        blackRating,
      );

      // Draw for equal players should be near zero
      expect(deltas['white']?.abs(), lessThanOrEqualTo(2));
      expect(deltas['black']?.abs(), lessThanOrEqualTo(2));
    });

    test('maintains rating symmetry (deltas sum to zero)', () {
      const whiteRating = 1600;
      const blackRating = 1700;

      final deltas = gameService.calculateRatingDeltas(
        'white_win',
        whiteRating,
        blackRating,
      );

      // In ELO, rating change is zero-sum (one player's gain is another's loss)
      expect(
        (deltas['white'] ?? 0) + (deltas['black'] ?? 0),
        equals(0),
      );
    });

    test('black win calculation', () {
      const whiteRating = 1600;
      const blackRating = 1600;

      final deltas = gameService.calculateRatingDeltas(
        'black_win',
        whiteRating,
        blackRating,
      );

      expect(deltas['white'], isNegative);
      expect(deltas['black'], isPositive);
      expect(deltas['white'], equals(-16));
      expect(deltas['black'], equals(16));
    });

    test('rating changes are integers', () {
      const whiteRating = 1650;
      const blackRating = 1700;

      final deltas = gameService.calculateRatingDeltas(
        'white_win',
        whiteRating,
        blackRating,
      );

      expect(deltas['white'], isA<int>());
      expect(deltas['black'], isA<int>());
    });
  });

  group('OnlineGameState', () {
    test('initializes with correct default values', () {
      final state = OnlineGameState(
        gameId: 'game-1',
        game: _mockGame(),
        engine: _mockEngine(),
      );

      expect(state.gameId, equals('game-1'));
      expect(state.isSyncingMove, isFalse);
      expect(state.lastError, isNull);
    });

    test('copyWith creates new instance with updated values', () {
      final state = OnlineGameState(
        gameId: 'game-1',
        game: _mockGame(),
        engine: _mockEngine(),
      );

      final newState = state.copyWith(isSyncingMove: true);

      expect(state.isSyncingMove, isFalse);
      expect(newState.isSyncingMove, isTrue);
      expect(newState.gameId, equals(state.gameId));
    });

    test('copyWith preserves non-updated values', () {
      final syncTime = DateTime.now();
      final state = OnlineGameState(
        gameId: 'game-1',
        game: _mockGame(),
        engine: _mockEngine(),
        lastSyncTime: syncTime,
      );

      final newState = state.copyWith(lastError: 'Some error');

      expect(newState.lastSyncTime, equals(syncTime));
      expect(newState.lastError, equals('Some error'));
    });
  });

  // Mock helpers
  _MockGame _mockGame() {
    return _MockGame();
  }

  _MockEngine _mockEngine() {
    return _MockEngine();
  }
}

class _MockGame {
  String get gameId => 'mock-game-1';
}

class _MockEngine {
  bool makeMove(String from, String to, {String? promotion}) => true;
}
