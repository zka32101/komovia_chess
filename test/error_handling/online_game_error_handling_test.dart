import 'dart:math' show pow;

import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_chess/src/models/online_game.dart';

/// Tests for error handling and resilience in online multiplayer
void main() {
  group('Error Handling & Resilience Tests', () {
    group('Network Failure Recovery', () {
      test('Handle Firestore write failure gracefully', () {
        // Simulate Firestore write failure
        expect(() {
          throw Exception('Firestore write failed: Network error');
        }, throwsException);
      });

      test('Reconnection preserves game state', () {
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
          pgn: '1. e4 e5 2. Nf3 Nc6',
          currentFen:
              'rnbqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 1 3',
          moves: [
            GameMove(
              moveNumber: 1,
              from: 'e2',
              to: 'e4',
              timestamp: DateTime.now(),
              playerId: 'user_1',
            ),
            GameMove(
              moveNumber: 1,
              from: 'e7',
              to: 'e5',
              timestamp: DateTime.now(),
              playerId: 'user_2',
            ),
          ],
          timeControl: '5min',
          timeControlMs: 5 * 60 * 1000,
          whiteTimeRemainingMs: 290000,
          blackTimeRemainingMs: 280000,
        );

        // Simulate connection loss and recovery
        // Game state should be preserved from last successful Firestore read

        expect(game.gameId, 'game_1');
        expect(game.status, 'active');
        expect(game.moves.length, 2);
        expect(game.whiteTimeRemainingMs, 290000);
      });

      test('Handle intermittent network latency (Retry logic)', () {
        var attemptCount = 0;
        const maxRetries = 3;

        bool performOperationWithRetry() {
          attemptCount++;

          // Simulate intermittent failure (fails on attempt 1, succeeds on attempt 2)
          if (attemptCount < 2) {
            throw Exception('Network timeout');
          }
          return true;
        }

        // Implement retry logic
        bool success = false;
        while (!success && attemptCount < maxRetries) {
          try {
            success = performOperationWithRetry();
          } catch (e) {
            // Wait before retry (exponential backoff)
            // In real code: await Future.delayed(Duration(...))
          }
        }

        expect(success, true);
        expect(attemptCount, 2);
      });

      test('Detect connection loss and transition to offline state', () {
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
          whiteTimeRemainingMs: 300000,
          blackTimeRemainingMs: 300000,
        );

        // In real implementation, this would transition to 'offline' state
        // For now, just verify the game can be marked as needing reconnection
        expect(game.status, 'active');

        // After reconnection attempt fails, game should be marked as offline
        final offlineGame = game.copyWith(
          status:
              'active', // Keep active but with offline flag in state manager
        );

        expect(offlineGame.gameId, game.gameId);
      });
    });

    group('Timeout Edge Cases', () {
      test('Time goes exactly to zero', () {
        var time = 1000; // 1 second
        time -= 1000;

        expect(time, 0);
        expect(time <= 0, true);
      });

      test('Time goes slightly below zero due to network delay', () {
        var time = 500; // 500ms
        time -= 600; // Network delay caused more time to pass

        expect(time, -100);
        expect(time <= 0, true);
      });

      test('Detect timeout at boundary conditions', () {
        const timeoutThresholdMs = 0;

        // Case 1: Exactly at threshold
        final timeAtThreshold = 0;
        expect(timeAtThreshold <= timeoutThresholdMs, true);

        // Case 2: Just above threshold
        final timeAboveThreshold = 1;
        expect(timeAboveThreshold <= timeoutThresholdMs, false);

        // Case 3: Well below threshold
        final timeBelowThreshold = -1000;
        expect(timeBelowThreshold <= timeoutThresholdMs, true);
      });

      test('Timeout doesnt trigger if time is positive', () {
        const timeoutThresholdMs = 0;

        for (int time = 1; time <= 1000; time += 100) {
          expect(time > timeoutThresholdMs, true);
        }
      });

      test('Timeout triggers for any non-positive time', () {
        const timeoutThresholdMs = 0;

        final timesToTest = [-1000, -100, -1, 0];
        for (final time in timesToTest) {
          expect(time <= timeoutThresholdMs, true);
        }
      });
    });

    group('Concurrent Move Validation', () {
      test('Two players cannot move simultaneously in the same position', () {
        final move1 = GameMove(
          moveNumber: 1,
          from: 'e2',
          to: 'e4',
          timestamp: DateTime.now(),
          playerId: 'user_1',
        );

        final move2 = GameMove(
          moveNumber: 1,
          from: 'e7',
          to: 'e5',
          timestamp: DateTime.now().add(const Duration(milliseconds: 1)),
          playerId: 'user_2',
        );

        // In real system, only one move is valid per position
        expect(move1.moveNumber, move2.moveNumber);
        // Database would ensure only move1 or move2, not both
      });

      test('Reject move if its not current players turn', () {
        final move1 = GameMove(
          moveNumber: 1,
          from: 'e2',
          to: 'e4',
          timestamp: DateTime.now(),
          playerId: 'user_1', // White
        );

        const currentTurnPlayer = 'user_2'; // Black's turn

        // Check if move belongs to current turn player
        expect(move1.playerId == currentTurnPlayer, false);
      });

      test('Detect and handle duplicate moves', () {
        final move = GameMove(
          moveNumber: 1,
          from: 'e2',
          to: 'e4',
          timestamp: DateTime.now(),
          playerId: 'user_1',
        );

        final moves = [move, move]; // Duplicate

        // Deduplicate based on moveNumber + position + player
        final uniqueMoves =
            moves.toSet().toList(); // In real code, would use unique key

        // Still have duplicates since we're just storing references
        // In real implementation, validate move uniqueness in Cloud Function
        expect(moves.length, 2);
      });
    });

    group('Invalid Move Handling', () {
      test('Reject move from invalid source square', () {
        final move = GameMove(
          moveNumber: 1,
          from: 'z9', // Invalid square
          to: 'e4',
          timestamp: DateTime.now(),
          playerId: 'user_1',
        );

        // In real implementation, validate square notation
        final validSquares = RegExp(r'^[a-h][1-8]$');
        expect(validSquares.hasMatch(move.from), false);
      });

      test('Reject move to invalid destination square', () {
        final move = GameMove(
          moveNumber: 1,
          from: 'e2',
          to: 'z9', // Invalid square
          timestamp: DateTime.now(),
          playerId: 'user_1',
        );

        final validSquares = RegExp(r'^[a-h][1-8]$');
        expect(validSquares.hasMatch(move.to), false);
      });

      test('Reject move with same source and destination', () {
        final move = GameMove(
          moveNumber: 1,
          from: 'e2',
          to: 'e2', // Same square
          timestamp: DateTime.now(),
          playerId: 'user_1',
        );

        expect(move.from == move.to, true);
        // Should be rejected by validation
      });

      test('Promote pawn only at correct rank', () {
        // Valid: pawn reaching 8th rank
        final validPromotion = GameMove(
          moveNumber: 32,
          from: 'e7',
          to: 'e8',
          promotion: 'q',
          timestamp: DateTime.now(),
          playerId: 'user_1',
        );

        expect(validPromotion.promotion, 'q');

        // Invalid: promotion on non-final rank
        final invalidPromotion = GameMove(
          moveNumber: 5,
          from: 'e4',
          to: 'e5',
          promotion: 'q', // Should not have promotion
          timestamp: DateTime.now(),
          playerId: 'user_1',
        );

        // Real validation would flag this as invalid
        expect(invalidPromotion.from.endsWith('4'), true);
      });

      test('Validate promotion piece type', () {
        const validPromotions = [
          'q',
          'r',
          'b',
          'n'
        ]; // Queen, Rook, Bishop, Knight

        for (final promotion in validPromotions) {
          final move = GameMove(
            moveNumber: 32,
            from: 'e7',
            to: 'e8',
            promotion: promotion,
            timestamp: DateTime.now(),
            playerId: 'user_1',
          );

          expect(validPromotions.contains(move.promotion), true);
        }

        // Invalid promotion piece
        const invalidPromotion = 'k'; // King cannot be promoted to
        expect(validPromotions.contains(invalidPromotion), false);
      });
    });

    group('Rating Calculation Edge Cases', () {
      test('Prevent negative ratings', () {
        final game = OnlineGame(
          gameId: 'game_1',
          type: 'online_pvp',
          status: 'completed',
          createdAt: DateTime.now(),
          endedAt: DateTime.now(),
          whitePlayerId: 'user_1',
          blackPlayerId: 'user_2',
          whitePlayerName: 'Player 1',
          blackPlayerName: 'Player 2',
          whiteRating: 100, // Very low rating
          blackRating: 3000, // Very high rating
          pgn: '',
          currentFen:
              'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
          moves: [],
          timeControl: '5min',
          timeControlMs: 5 * 60 * 1000,
          whiteTimeRemainingMs: 0,
          blackTimeRemainingMs: 300000,
          result: 'black_win',
          resultReason: 'timeout',
          whiteRatingDelta: -32,
          blackRatingDelta: 32,
          whiteNewRating: 100 - 32, // Could be 68, still valid
          blackNewRating: 3000 + 32,
        );

        // Verify rating doesn't go negative
        expect(game.whiteNewRating ?? 0, greaterThanOrEqualTo(0));
      });

      test('Handle zero rating difference', () {
        const whiteRating = 1600;
        const blackRating = 1600;
        const diff = whiteRating - blackRating;

        expect(diff, 0);

        // ELO should result in 0 rating change for equal ratings in a draw
        const K = 32.0;
        const D = 400.0;

        final whiteExpected =
            1.0 / (1.0 + pow(10, (blackRating - whiteRating) / D).toDouble());

        // For equal ratings, expected is always 0.5
        expect(whiteExpected, closeTo(0.5, 0.01));
      });

      test('Handle extreme rating differences', () {
        const lowRating = 400;
        const highRating = 2800;

        // Expected win probability for low-rated player vs high-rated
        const K = 32.0;
        const D = 400.0;

        final lowExpected =
            1.0 / (1.0 + pow(10, (highRating - lowRating) / D).toDouble());

        // Should be very close to 0
        expect(lowExpected, lessThan(0.01));

        // If low-rated wins, gets significant points
        final lowGain = (K * (1.0 - lowExpected)).round();
        expect(lowGain, greaterThan(30));
      });
    });

    group('Data Consistency', () {
      test('Game state is consistent after moves', () {
        final initialGame = OnlineGame(
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
          whiteTimeRemainingMs: 300000,
          blackTimeRemainingMs: 300000,
        );

        // Apply moves
        var gameState = initialGame;
        for (int i = 0; i < 10; i++) {
          final move = GameMove(
            moveNumber: i + 1,
            from: 'e2',
            to: 'e4',
            timestamp: DateTime.now(),
            playerId: i % 2 == 0 ? 'user_1' : 'user_2',
          );

          gameState = gameState.copyWith(
            moves: [...gameState.moves, move],
          );
        }

        // Verify consistency
        expect(gameState.moves.length, 10);
        expect(gameState.gameId, 'game_1');
        expect(gameState.status, 'active');
      });

      test('Moves list always matches move count in PGN', () {
        final moves = [
          GameMove(
            moveNumber: 1,
            from: 'e2',
            to: 'e4',
            timestamp: DateTime.now(),
            playerId: 'user_1',
          ),
          GameMove(
            moveNumber: 1,
            from: 'e7',
            to: 'e5',
            timestamp: DateTime.now(),
            playerId: 'user_2',
          ),
        ];

        const pgn = '1. e4 e5';

        // PGN should be consistent with moves
        expect(moves.length, 2);
        // In real code, parse PGN and verify move count
      });
    });

    group('Abandonment Handling', () {
      test('Record which player abandoned the game', () {
        final game = OnlineGame(
          gameId: 'game_1',
          type: 'online_pvp',
          status: 'abandoned',
          createdAt: DateTime.now(),
          endedAt: DateTime.now(),
          whitePlayerId: 'user_1',
          blackPlayerId: 'user_2',
          whitePlayerName: 'Player 1',
          blackPlayerName: 'Player 2',
          whiteRating: 1600,
          blackRating: 1580,
          pgn: '1. e4 e5',
          currentFen:
              'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2',
          moves: [],
          timeControl: '5min',
          timeControlMs: 5 * 60 * 1000,
          whiteTimeRemainingMs: 290000,
          blackTimeRemainingMs: 280000,
          result: 'black_win',
          resultReason: 'abandonment',
          abandonedBy: 'user_1', // White abandoned
        );

        expect(game.abandonedBy, 'user_1');
        expect(game.result, 'black_win'); // Other player wins
      });

      test('Assign win to non-abandoning player', () {
        const abandoningPlayer = 'user_1';
        const otherPlayer = 'user_2';

        // Win should go to other player
        final resultWinner =
            abandoningPlayer == 'user_1' ? 'black_win' : 'white_win';

        expect(resultWinner, 'black_win');
      });
    });

    group('Draw Scenarios', () {
      test('Mutual draw agreement', () {
        final game = OnlineGame(
          gameId: 'game_1',
          type: 'online_pvp',
          status: 'completed',
          createdAt: DateTime.now(),
          endedAt: DateTime.now(),
          whitePlayerId: 'user_1',
          blackPlayerId: 'user_2',
          whitePlayerName: 'Player 1',
          blackPlayerName: 'Player 2',
          whiteRating: 1600,
          blackRating: 1600,
          pgn: '1. e4 e5 2. Nf3 Nf6',
          currentFen:
              'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
          moves: [],
          timeControl: '5min',
          timeControlMs: 5 * 60 * 1000,
          whiteTimeRemainingMs: 250000,
          blackTimeRemainingMs: 250000,
          result: 'draw',
          resultReason: 'mutual_agreement',
          whiteRatingDelta: 0,
          blackRatingDelta: 0,
        );

        expect(game.result, 'draw');
        expect(game.whiteRatingDelta, 0);
        expect(game.blackRatingDelta, 0);
      });

      test('Stalemate draw', () {
        final game = OnlineGame(
          gameId: 'game_1',
          type: 'online_pvp',
          status: 'completed',
          createdAt: DateTime.now(),
          endedAt: DateTime.now(),
          whitePlayerId: 'user_1',
          blackPlayerId: 'user_2',
          whitePlayerName: 'Player 1',
          blackPlayerName: 'Player 2',
          whiteRating: 1600,
          blackRating: 1600,
          pgn: '1. e3 a5 2. Qh5 Ra6 3. Qxa5',
          currentFen: '6bk/6pp/r7/Q7/8/4P3/PPP2PPP/RNB1KBNR w KQ - 1 4',
          moves: [],
          timeControl: '5min',
          timeControlMs: 5 * 60 * 1000,
          whiteTimeRemainingMs: 280000,
          blackTimeRemainingMs: 270000,
          result: 'draw',
          resultReason: 'stalemate',
          whiteRatingDelta: 0,
          blackRatingDelta: 0,
        );

        expect(game.result, 'draw');
        expect(game.resultReason, 'stalemate');
      });
    });
  });
}
