import 'dart:math' show pow;

import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_chess/src/models/online_game.dart';

/// Performance testing utilities for online multiplayer
class PerformanceMetrics {
  final String testName;
  final DateTime startTime;
  late DateTime endTime;
  late int operationCount;
  late double operationsPerSecond;
  late double averageTimeMs;

  PerformanceMetrics({
    required this.testName,
    required this.startTime,
  });

  void recordEnd(int operations) {
    endTime = DateTime.now();
    operationCount = operations;

    final durationMs = endTime.difference(startTime).inMilliseconds.toDouble();
    final durationSeconds = durationMs / 1000;

    averageTimeMs = durationMs / operations;
    operationsPerSecond = operations / durationSeconds;
  }

  @override
  String toString() {
    return '''
Performance Report: $testName
  Operations: $operationCount
  Total Time: ${endTime.difference(startTime).inMilliseconds}ms
  Avg Time/Op: ${averageTimeMs.toStringAsFixed(3)}ms
  Throughput: ${operationsPerSecond.toStringAsFixed(2)} ops/sec
''';
  }
}

/// Stress test utilities
class StressTestScenario {
  final String scenarioName;
  final int concurrentGames;
  final int movesPerGame;
  final Duration timePerMove;

  StressTestScenario({
    required this.scenarioName,
    required this.concurrentGames,
    required this.movesPerGame,
    required this.timePerMove,
  });

  String describe() {
    return '''
Stress Test: $scenarioName
  Concurrent Games: $concurrentGames
  Moves per Game: $movesPerGame
  Time per Move: ${timePerMove.inMilliseconds}ms
  Total Moves: ${concurrentGames * movesPerGame}
''';
  }
}

void main() {
  group('Performance Tests', () {
    group('Game Creation Performance', () {
      test('Create 100 games in sequence', () {
        final metrics = PerformanceMetrics(
          testName: 'Create 100 Games',
          startTime: DateTime.now(),
        );

        const gameCount = 100;
        for (int i = 0; i < gameCount; i++) {
          final game = OnlineGame(
            gameId: 'game_$i',
            type: 'online_pvp',
            status: 'matchmaking',
            createdAt: DateTime.now(),
            whitePlayerId: 'user_${i * 2}',
            blackPlayerId: 'user_${i * 2 + 1}',
            whitePlayerName: 'Player_${i * 2}',
            blackPlayerName: 'Player_${i * 2 + 1}',
            whiteRating: 1600 + (i % 100),
            blackRating: 1580 + (i % 100),
            pgn: '',
            currentFen:
                'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
            moves: [],
            timeControl: '5min',
            timeControlMs: 5 * 60 * 1000,
            whiteTimeRemainingMs: 5 * 60 * 1000,
            blackTimeRemainingMs: 5 * 60 * 1000,
          );

          expect(game.gameId, isNotNull);
        }

        metrics.recordEnd(gameCount);
        print(metrics);

        // Performance expectations
        // Creating 100 games should take < 100ms
        expect(
          metrics.endTime.difference(metrics.startTime).inMilliseconds,
          lessThan(100),
        );
      });

      test('Copy game with modifications (100 times)', () {
        final baseGame = OnlineGame(
          gameId: 'game_1',
          type: 'online_pvp',
          status: 'active',
          createdAt: DateTime.now(),
          startedAt: DateTime.now(),
          whitePlayerId: 'user_1',
          blackPlayerId: 'user_2',
          whitePlayerName: 'Player 1',
          blackPlayerName: 'Player 2',
          whiteRating: 1600,
          blackRating: 1580,
          pgn: '',
          currentFen:
              'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
          moves: [],
          timeControl: '5min',
          timeControlMs: 5 * 60 * 1000,
          whiteTimeRemainingMs: 5 * 60 * 1000,
          blackTimeRemainingMs: 5 * 60 * 1000,
        );

        final metrics = PerformanceMetrics(
          testName: 'Copy Game with Modifications',
          startTime: DateTime.now(),
        );

        const copyCount = 100;
        for (int i = 0; i < copyCount; i++) {
          final modifiedGame = baseGame.copyWith(
            whiteTimeRemainingMs: 5 * 60 * 1000 - (i * 1000),
            blackTimeRemainingMs: 5 * 60 * 1000 - (i * 800),
          );

          expect(modifiedGame.gameId, baseGame.gameId);
          expect(modifiedGame.whiteTimeRemainingMs,
              lessThan(baseGame.whiteTimeRemainingMs));
        }

        metrics.recordEnd(copyCount);
        print(metrics);

        expect(metrics.averageTimeMs, lessThan(1.0)); // < 1ms per copy
      });
    });

    group('Move Recording Performance', () {
      test('Record 1000 moves with FEN updates', () {
        final game = OnlineGame(
          gameId: 'game_1',
          type: 'online_pvp',
          status: 'active',
          createdAt: DateTime.now(),
          startedAt: DateTime.now(),
          whitePlayerId: 'user_1',
          blackPlayerId: 'user_2',
          whitePlayerName: 'Player 1',
          blackPlayerName: 'Player 2',
          whiteRating: 1600,
          blackRating: 1580,
          pgn: '',
          currentFen:
              'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
          moves: [],
          timeControl: '5min',
          timeControlMs: 5 * 60 * 1000,
          whiteTimeRemainingMs: 5 * 60 * 1000,
          blackTimeRemainingMs: 5 * 60 * 1000,
        );

        final metrics = PerformanceMetrics(
          testName: 'Record 1000 Moves',
          startTime: DateTime.now(),
        );

        var currentGame = game;
        const moveCount = 1000;

        for (int i = 0; i < moveCount; i++) {
          final move = GameMove(
            moveNumber: i + 1,
            from: 'e${(i % 8) + 1}',
            to: 'e${((i + 1) % 8) + 1}',
            timestamp: DateTime.now(),
            playerId: i % 2 == 0 ? 'user_1' : 'user_2',
          );

          // Simulate move recording
          final updatedMoves = [...currentGame.moves, move];
          currentGame = currentGame.copyWith(moves: updatedMoves);
        }

        metrics.recordEnd(moveCount);
        print(metrics);

        expect(currentGame.moves.length, moveCount);
        expect(metrics.averageTimeMs, lessThan(0.5)); // < 0.5ms per move
      });

      test('Game move list with 500 moves remains responsive', () {
        final moves = <GameMove>[];
        for (int i = 0; i < 500; i++) {
          moves.add(GameMove(
            moveNumber: i + 1,
            from: 'a1',
            to: 'h8',
            timestamp: DateTime.now(),
            playerId: i % 2 == 0 ? 'user_1' : 'user_2',
          ));
        }

        final metrics = PerformanceMetrics(
          testName: 'Query 500 Move List',
          startTime: DateTime.now(),
        );

        const queryCount = 100;
        for (int i = 0; i < queryCount; i++) {
          final lastMove = moves.last;
          final moveCount = moves.length;
          final whiteMovesOnly =
              moves.where((m) => m.playerId == 'user_1').toList();

          expect(lastMove, isNotNull);
          expect(moveCount, 500);
          expect(whiteMovesOnly.length, 250);
        }

        metrics.recordEnd(queryCount);
        print(metrics);

        expect(metrics.averageTimeMs, lessThan(1.0));
      });
    });

    group('Rating Calculation Performance', () {
      test('Calculate ratings for 500 completed games', () {
        final metrics = PerformanceMetrics(
          testName: 'Calculate 500 Game Ratings',
          startTime: DateTime.now(),
        );

        const gameCount = 500;
        const K = 32.0;
        const D = 400.0;

        for (int i = 0; i < gameCount; i++) {
          final whiteRating = 1400 + (i % 400);
          final blackRating = 1400 + ((i + 100) % 400);

          // Simulate ELO calculation
          final whiteExpected =
              1.0 / (1.0 + pow(10, (blackRating - whiteRating) / D).toDouble());
          final blackExpected = 1.0 - whiteExpected;

          final whiteScore = i % 3 == 0 ? 1.0 : (i % 3 == 1 ? 0.0 : 0.5);
          final blackScore = 1.0 - whiteScore;

          final whiteChange = (K * (whiteScore - whiteExpected)).round();
          final blackChange = (K * (blackScore - blackExpected)).round();

          expect(whiteChange + blackChange, 0); // Zero-sum
        }

        metrics.recordEnd(gameCount);
        print(metrics);

        expect(
            metrics.operationsPerSecond, greaterThan(1000)); // 1000+ calcs/sec
      });
    });

    group('Time Tracking Performance', () {
      test('Decrement time for 1000 moves efficiently', () {
        var whiteTime = 5 * 60 * 1000; // 5 minutes
        var blackTime = 5 * 60 * 1000;

        final metrics = PerformanceMetrics(
          testName: 'Decrement Time 1000 Times',
          startTime: DateTime.now(),
        );

        const decrementCount = 1000;
        const timeDecrementMs = 100; // 100ms per move

        for (int i = 0; i < decrementCount; i++) {
          if (i % 2 == 0) {
            whiteTime -= timeDecrementMs;
          } else {
            blackTime -= timeDecrementMs;
          }

          expect(whiteTime >= 0 || blackTime >= 0, true);
        }

        metrics.recordEnd(decrementCount);
        print(metrics);

        expect(metrics.operationsPerSecond, greaterThan(100000)); // Very fast
      });

      test('Detect timeout efficiently', () {
        final games = <OnlineGame>[];
        for (int i = 0; i < 100; i++) {
          games.add(OnlineGame(
            gameId: 'game_$i',
            type: 'online_pvp',
            status: 'active',
            createdAt: DateTime.now(),
            startedAt: DateTime.now(),
            whitePlayerId: 'user_1',
            blackPlayerId: 'user_2',
            whitePlayerName: 'Player 1',
            blackPlayerName: 'Player 2',
            whiteRating: 1600,
            blackRating: 1580,
            pgn: '',
            currentFen:
                'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
            moves: [],
            timeControl: '5min',
            timeControlMs: 5 * 60 * 1000,
            whiteTimeRemainingMs: i < 50 ? 0 : 300000, // Half have timed out
            blackTimeRemainingMs: 300000,
          ));
        }

        final metrics = PerformanceMetrics(
          testName: 'Detect Timeouts in 100 Games',
          startTime: DateTime.now(),
        );

        const checkCount = 100;
        for (int check = 0; check < checkCount; check++) {
          for (final game in games) {
            final whiteTimeout = game.whiteTimeRemainingMs <= 0;
            final blackTimeout = game.blackTimeRemainingMs <= 0;

            if (whiteTimeout || blackTimeout) {
              // Game would end
            }
          }
        }

        metrics.recordEnd(games.length * checkCount);
        print(metrics);

        expect(metrics.operationsPerSecond, greaterThan(100000));
      });
    });

    group('Stress Test Scenarios', () {
      test('Describe stress test scenario: Light load', () {
        final scenario = StressTestScenario(
          scenarioName: 'Light Load',
          concurrentGames: 10,
          movesPerGame: 40,
          timePerMove: const Duration(seconds: 5),
        );

        print(scenario.describe());
        expect(scenario.concurrentGames, 10);
        expect(scenario.movesPerGame, 40);
      });

      test('Describe stress test scenario: Medium load', () {
        final scenario = StressTestScenario(
          scenarioName: 'Medium Load',
          concurrentGames: 100,
          movesPerGame: 40,
          timePerMove: const Duration(seconds: 3),
        );

        print(scenario.describe());
        expect(scenario.concurrentGames, 100);
      });

      test('Describe stress test scenario: Heavy load', () {
        final scenario = StressTestScenario(
          scenarioName: 'Heavy Load',
          concurrentGames: 500,
          movesPerGame: 50,
          timePerMove: const Duration(milliseconds: 500),
        );

        print(scenario.describe());
        expect(scenario.concurrentGames, 500);
      });

      test('Simulate 100 concurrent games without memory issues', () {
        final metrics = PerformanceMetrics(
          testName: 'Simulate 100 Concurrent Games',
          startTime: DateTime.now(),
        );

        const gameCount = 100;
        final games = <OnlineGame>[];

        // Create games
        for (int i = 0; i < gameCount; i++) {
          games.add(OnlineGame(
            gameId: 'game_$i',
            type: 'online_pvp',
            status: 'active',
            createdAt: DateTime.now(),
            startedAt: DateTime.now(),
            whitePlayerId: 'user_${i * 2}',
            blackPlayerId: 'user_${i * 2 + 1}',
            whitePlayerName: 'Player ${i * 2}',
            blackPlayerName: 'Player ${i * 2 + 1}',
            whiteRating: 1600,
            blackRating: 1580,
            pgn: '',
            currentFen:
                'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
            moves: [],
            timeControl: '5min',
            timeControlMs: 5 * 60 * 1000,
            whiteTimeRemainingMs: 5 * 60 * 1000,
            blackTimeRemainingMs: 5 * 60 * 1000,
          ));
        }

        // Simulate moves
        for (int move = 0; move < 20; move++) {
          for (int i = 0; i < gameCount; i++) {
            final updatedGame = games[i].copyWith(
              whiteTimeRemainingMs: games[i].whiteTimeRemainingMs - 500,
              blackTimeRemainingMs: games[i].blackTimeRemainingMs - 500,
            );

            games[i] = updatedGame;
          }
        }

        expect(games.length, gameCount);
        expect(games.every((g) => g.gameId.isNotEmpty), true);

        metrics.recordEnd(gameCount * 20);
        print(metrics);
      });
    });

    group('Memory Efficiency', () {
      test('Game document size is reasonable', () {
        final game = OnlineGame(
          gameId: 'game_1',
          type: 'online_pvp',
          status: 'active',
          createdAt: DateTime.now(),
          startedAt: DateTime.now(),
          whitePlayerId: 'user_1',
          blackPlayerId: 'user_2',
          whitePlayerName: 'Player 1',
          blackPlayerName: 'Player 2',
          whiteRating: 1600,
          blackRating: 1580,
          pgn: '1. e4 e5 2. Nf3 Nc6' * 10, // Simulate longer game
          currentFen:
              'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
          moves: [],
          timeControl: '5min',
          timeControlMs: 5 * 60 * 1000,
          whiteTimeRemainingMs: 5 * 60 * 1000,
          blackTimeRemainingMs: 5 * 60 * 1000,
        );

        final jsonData = game.toJson();
        final jsonString = jsonData.toString();

        // A reasonable game document should be < 2KB
        expect(jsonString.length, lessThan(2048));
      });
    });
  });
}
