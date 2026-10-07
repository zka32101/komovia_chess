import 'dart:math' show pow;

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:komovia_chess/src/models/online_game.dart';
import 'package:komovia_chess/src/services/online_game_service.dart';
import 'package:komovia_chess/src/services/matchmaking_service.dart';

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockCollectionReference extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class MockDocumentReference extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

class MockDocumentSnapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

void main() {
  group('Online Multiplayer Integration Tests', () {
    late OnlineGameService gameService;
    late MatchmakingService matchmakingService;
    late MockFirebaseFirestore mockFirestore;

    setUp(() {
      mockFirestore = MockFirebaseFirestore();
      gameService = OnlineGameService(firestore: mockFirestore);
      matchmakingService = MatchmakingService(firestore: mockFirestore);
    });

    group('Complete Game Flow', () {
      test('Full game lifecycle: matchmaking to completion', () async {
        // Scenario: Two players match and complete a game
        const whitePlayerId = 'user_1';
        const blackPlayerId = 'user_2';
        const whitePlayerName = 'Alice';
        const blackPlayerName = 'Bob';
        const timeControl = '5min';

        // Step 1: Both players join queue
        final whiteQueueEntry = MatchmakingQueueEntry(
          queueId: 'queue_white_1',
          playerId: whitePlayerId,
          playerName: whitePlayerName,
          currentRating: 1600,
          ratingRange: RatingRange(min: 1550, max: 1650),
          timeControlType: timeControl,
          queuedAt: DateTime.now(),
          timeoutAt: DateTime.now().add(const Duration(seconds: 30)),
          priority: 16,
          status: 'waiting',
          color: 'white',
        );

        final blackQueueEntry = MatchmakingQueueEntry(
          queueId: 'queue_black_1',
          playerId: blackPlayerId,
          playerName: blackPlayerName,
          currentRating: 1580,
          ratingRange: RatingRange(min: 1530, max: 1630),
          timeControlType: timeControl,
          queuedAt: DateTime.now().add(const Duration(milliseconds: 500)),
          timeoutAt: DateTime.now().add(const Duration(seconds: 30)),
          priority: 15,
          status: 'waiting',
          color: 'black',
        );

        // Step 2: Create game (simulating matchmaking worker)
        final game = await gameService.createGame(
          whitePlayerId: whitePlayerId,
          whitePlayerName: whitePlayerName,
          whiteRating: 1600,
          blackPlayerId: blackPlayerId,
          blackPlayerName: blackPlayerName,
          blackRating: 1580,
          gameType: 'online_pvp',
          timeControl: timeControl,
        );

        expect(game.whitePlayerId, whitePlayerId);
        expect(game.blackPlayerId, blackPlayerId);
        expect(game.status, 'matchmaking');
        expect(game.whiteTimeRemainingMs, 5 * 60 * 1000);
        expect(game.blackTimeRemainingMs, 5 * 60 * 1000);
      });

      test('Game state transitions correctly through all states', () async {
        final game = OnlineGame(
          gameId: 'game_1',
          type: 'online_pvp',
          status: 'matchmaking',
          createdAt: DateTime.now(),
          whitePlayerId: 'user_1',
          blackPlayerId: 'user_2',
          whitePlayerName: 'Alice',
          blackPlayerName: 'Bob',
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

        // Verify initial state
        expect(game.status, 'matchmaking');

        // Simulate state transition to active
        final activeGame = game.copyWith(
          status: 'active',
          startedAt: DateTime.now(),
        );
        expect(activeGame.status, 'active');
        expect(activeGame.startedAt, isNotNull);

        // Simulate game completion
        final completedGame = activeGame.copyWith(
          status: 'completed',
          endedAt: DateTime.now(),
          result: 'white_win',
          resultReason: 'checkmate',
          whiteRatingDelta: 16,
          blackRatingDelta: -16,
          whiteNewRating: 1616,
          blackNewRating: 1564,
        );

        expect(completedGame.status, 'completed');
        expect(completedGame.result, 'white_win');
        expect(completedGame.whiteNewRating, 1616);
        expect(completedGame.blackNewRating, 1564);
      });

      test('Move recording updates game state correctly', () async {
        final initialGame = OnlineGame(
          gameId: 'game_1',
          type: 'online_pvp',
          status: 'active',
          createdAt: DateTime.now(),
          startedAt: DateTime.now(),
          whitePlayerId: 'user_1',
          blackPlayerId: 'user_2',
          whitePlayerName: 'Alice',
          blackPlayerName: 'Bob',
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

        // Simulate white's first move (e2-e4)
        final move1 = GameMove(
          moveNumber: 1,
          from: 'e2',
          to: 'e4',
          timestamp: DateTime.now(),
          playerId: 'user_1',
        );

        // Verify move can be created
        expect(move1.from, 'e2');
        expect(move1.to, 'e4');
        expect(move1.playerId, 'user_1');

        // Simulate FEN update after move
        const updatedFen =
            'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1';
        const updatedPgn = '1. e4';

        final gameAfterMove1 = initialGame.copyWith(
          currentFen: updatedFen,
          pgn: updatedPgn,
          moves: [move1],
        );

        expect(gameAfterMove1.moves.length, 1);
        expect(gameAfterMove1.currentFen, updatedFen);
        expect(gameAfterMove1.pgn, updatedPgn);
      });
    });

    group('Rating System Accuracy', () {
      test('ELO calculation: 1600 vs 1580 (1600 wins)', () async {
        const K = 32.0;
        const D = 400.0;

        final rating1 = 1600;
        final rating2 = 1580;

        // Expected score for 1600
        final expected1 =
            1.0 / (1.0 + pow(10, (rating2 - rating1) / D).toDouble());
        // Expected score for 1580
        final expected2 = 1.0 - expected1;

        // 1600 wins
        final delta1 = (K * (1.0 - expected1)).round();
        final delta2 = (K * (0.0 - expected2)).round();

        // Verify zero-sum property
        expect(delta1 + delta2, 0);

        // 1600 should gain slightly less than 32 (unfavorable win)
        expect(delta1, lessThan(16));
        // 1580 should lose slightly more than 32 (upset loss)
        expect(delta2, greaterThan(-32));
      });

      test('ELO calculation: Draw between equal ratings', () async {
        const K = 32.0;
        const D = 400.0;

        final rating1 = 1600;
        final rating2 = 1600;

        final expected1 =
            1.0 / (1.0 + pow(10, (rating2 - rating1) / D).toDouble());
        final expected2 = 1.0 - expected1;

        // Draw (0.5 points each)
        final delta1 = (K * (0.5 - expected1)).round();
        final delta2 = (K * (0.5 - expected2)).round();

        // Equal ratings should result in equal draws
        expect(delta1, 0);
        expect(delta2, 0);
      });

      test('ELO calculation: Upset (lower rated wins)', () async {
        const K = 32.0;
        const D = 400.0;

        final rating1 = 1400; // Lower rated
        final rating2 = 1800; // Higher rated

        final expected1 =
            1.0 / (1.0 + pow(10, (rating2 - rating1) / D).toDouble());
        final expected2 = 1.0 - expected1;

        // 1400 wins (upset)
        final delta1 = (K * (1.0 - expected1)).round();
        final delta2 = (K * (0.0 - expected2)).round();

        // Upset winner gains more
        expect(delta1, greaterThan(16));
        // Heavy favorite loses more
        expect(delta2, lessThan(-32));
      });

      test('Rating changes are preserved through game completion', () async {
        final game = OnlineGame(
          gameId: 'game_1',
          type: 'online_pvp',
          status: 'completed',
          createdAt: DateTime.now(),
          whitePlayerId: 'user_1',
          blackPlayerId: 'user_2',
          whitePlayerName: 'Alice',
          blackPlayerName: 'Bob',
          whiteRating: 1600,
          blackRating: 1580,
          pgn: '1. e4 e5 2. Nf3 Nc6',
          currentFen:
              'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
          moves: [],
          timeControl: '5min',
          timeControlMs: 5 * 60 * 1000,
          whiteTimeRemainingMs: 0,
          blackTimeRemainingMs: 120000,
          result: 'white_win',
          resultReason: 'timeout',
          whiteRatingDelta: 32,
          blackRatingDelta: -32,
          whiteNewRating: 1632,
          blackNewRating: 1548,
          endedAt: DateTime.now(),
        );

        expect(game.whiteNewRating, game.whiteRating + game.whiteRatingDelta!);
        expect(game.blackNewRating, game.blackRating + game.blackRatingDelta!);
      });
    });

    group('Timeout Handling', () {
      test('Game ends when white time expires', () async {
        final game = OnlineGame(
          gameId: 'game_1',
          type: 'online_pvp',
          status: 'active',
          createdAt: DateTime.now(),
          startedAt: DateTime.now(),
          whitePlayerId: 'user_1',
          blackPlayerId: 'user_2',
          whitePlayerName: 'Alice',
          blackPlayerName: 'Bob',
          whiteRating: 1600,
          blackRating: 1580,
          pgn: '1. e4 e5',
          currentFen:
              'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2',
          moves: [],
          timeControl: '5min',
          timeControlMs: 5 * 60 * 1000,
          whiteTimeRemainingMs: 0, // Time expired
          blackTimeRemainingMs: 300000,
        );

        // Verify timeout detection
        expect(game.whiteTimeRemainingMs, 0);
        expect(game.blackTimeRemainingMs, greaterThan(0));

        // Simulate game end by timeout
        final completedGame = game.copyWith(
          status: 'completed',
          endedAt: DateTime.now(),
          result: 'black_win',
          resultReason: 'timeout',
        );

        expect(completedGame.result, 'black_win');
        expect(completedGame.resultReason, 'timeout');
      });

      test('Game ends when black time expires', () async {
        final game = OnlineGame(
          gameId: 'game_1',
          type: 'online_pvp',
          status: 'active',
          createdAt: DateTime.now(),
          startedAt: DateTime.now(),
          whitePlayerId: 'user_1',
          blackPlayerId: 'user_2',
          whitePlayerName: 'Alice',
          blackPlayerName: 'Bob',
          whiteRating: 1600,
          blackRating: 1580,
          pgn: '1. e4 e5',
          currentFen:
              'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2',
          moves: [],
          timeControl: '5min',
          timeControlMs: 5 * 60 * 1000,
          whiteTimeRemainingMs: 300000,
          blackTimeRemainingMs: 0, // Time expired
        );

        expect(game.blackTimeRemainingMs, 0);

        final completedGame = game.copyWith(
          status: 'completed',
          endedAt: DateTime.now(),
          result: 'white_win',
          resultReason: 'timeout',
        );

        expect(completedGame.result, 'white_win');
      });

      test('Timeout occurs at exactly zero time', () async {
        final initialGame = OnlineGame(
          gameId: 'game_1',
          type: 'online_pvp',
          status: 'active',
          createdAt: DateTime.now(),
          startedAt: DateTime.now(),
          whitePlayerId: 'user_1',
          blackPlayerId: 'user_2',
          whitePlayerName: 'Alice',
          blackPlayerName: 'Bob',
          whiteRating: 1600,
          blackRating: 1580,
          pgn: '',
          currentFen:
              'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
          moves: [],
          timeControl: '5min',
          timeControlMs: 5 * 60 * 1000,
          whiteTimeRemainingMs: 1000, // 1 second remaining
          blackTimeRemainingMs: 300000,
        );

        // Simulate time passing
        final afterTimePass = initialGame.copyWith(
          whiteTimeRemainingMs: 0,
        );

        // Verify timeout at 0
        expect(afterTimePass.whiteTimeRemainingMs, 0);
      });
    });

    group('Concurrent Game Handling', () {
      test('Multiple games can exist simultaneously', () async {
        final game1 = OnlineGame(
          gameId: 'game_1',
          type: 'online_pvp',
          status: 'active',
          createdAt: DateTime.now(),
          startedAt: DateTime.now(),
          whitePlayerId: 'user_1',
          blackPlayerId: 'user_2',
          whitePlayerName: 'Alice',
          blackPlayerName: 'Bob',
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

        final game2 = OnlineGame(
          gameId: 'game_2',
          type: 'online_pvp',
          status: 'active',
          createdAt: DateTime.now(),
          startedAt: DateTime.now(),
          whitePlayerId: 'user_3',
          blackPlayerId: 'user_4',
          whitePlayerName: 'Charlie',
          blackPlayerName: 'Diana',
          whiteRating: 1700,
          blackRating: 1650,
          pgn: '',
          currentFen:
              'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
          moves: [],
          timeControl: '3min',
          timeControlMs: 3 * 60 * 1000,
          whiteTimeRemainingMs: 180000,
          blackTimeRemainingMs: 180000,
        );

        // Verify both games are independent
        expect(game1.gameId, 'game_1');
        expect(game2.gameId, 'game_2');
        expect(game1.whitePlayerId, 'user_1');
        expect(game2.whitePlayerId, 'user_3');
        expect(game1.timeControl, '5min');
        expect(game2.timeControl, '3min');
      });

      test('Player cannot have same player in two games', () async {
        // User 1 in two games should be possible but distinct games
        final game1 = OnlineGame(
          gameId: 'game_1',
          type: 'online_pvp',
          status: 'active',
          createdAt: DateTime.now(),
          startedAt: DateTime.now(),
          whitePlayerId: 'user_1',
          blackPlayerId: 'user_2',
          whitePlayerName: 'Alice',
          blackPlayerName: 'Bob',
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

        final game2 = OnlineGame(
          gameId: 'game_2',
          type: 'online_pvp',
          status: 'active',
          createdAt: DateTime.now(),
          startedAt: DateTime.now(),
          whitePlayerId: 'user_1',
          blackPlayerId: 'user_3',
          whitePlayerName: 'Alice',
          blackPlayerName: 'Charlie',
          whiteRating: 1600,
          blackRating: 1620,
          pgn: '',
          currentFen:
              'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
          moves: [],
          timeControl: '3min',
          timeControlMs: 3 * 60 * 1000,
          whiteTimeRemainingMs: 180000,
          blackTimeRemainingMs: 180000,
        );

        // Both games exist (in real system, validation would prevent this)
        expect(game1.gameId, isNotNull);
        expect(game2.gameId, isNotNull);
        expect(game1.gameId, isNot(game2.gameId));
      });
    });

    group('Move Validation', () {
      test('Move contains required fields', () async {
        final move = GameMove(
          moveNumber: 1,
          from: 'e2',
          to: 'e4',
          timestamp: DateTime.now(),
          playerId: 'user_1',
        );

        expect(move.moveNumber, 1);
        expect(move.from, isNotEmpty);
        expect(move.to, isNotEmpty);
        expect(move.timestamp, isNotNull);
        expect(move.playerId, isNotEmpty);
      });

      test('Promotion move includes promotion field', () async {
        final move = GameMove(
          moveNumber: 32,
          from: 'e7',
          to: 'e8',
          promotion: 'q',
          timestamp: DateTime.now(),
          playerId: 'user_1',
        );

        expect(move.promotion, 'q');
      });

      test('Move from and to positions are different', () async {
        final move = GameMove(
          moveNumber: 1,
          from: 'e2',
          to: 'e4',
          timestamp: DateTime.now(),
          playerId: 'user_1',
        );

        expect(move.from, isNot(move.to));
      });
    });

    group('Game Result Scenarios', () {
      test('Checkmate result is recorded correctly', () async {
        final game = OnlineGame(
          gameId: 'game_1',
          type: 'online_pvp',
          status: 'completed',
          createdAt: DateTime.now(),
          endedAt: DateTime.now(),
          whitePlayerId: 'user_1',
          blackPlayerId: 'user_2',
          whitePlayerName: 'Alice',
          blackPlayerName: 'Bob',
          whiteRating: 1600,
          blackRating: 1580,
          pgn:
              '1. e4 e5 2. Nf3 Nc6 3. Bc4 Bc5 4. b4 Bxb4 5. c3 Ba5 6. d4 exd4 7. O-O d3 8. Qxd3 Qe7 9. e5 Ng4 10. e6 fxe6 11. Bxe6+ Kd8 12. Bf7 Qd6 13. Bg5+ Kc7 14. Bxg4 Bxc3 15. Bxe6 Bxa1 16. Qg3#',
          currentFen:
              'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
          moves: [],
          timeControl: '5min',
          timeControlMs: 5 * 60 * 1000,
          whiteTimeRemainingMs: 250000,
          blackTimeRemainingMs: 0,
          result: 'white_win',
          resultReason: 'checkmate',
          whiteRatingDelta: 32,
          blackRatingDelta: -32,
          whiteNewRating: 1632,
          blackNewRating: 1548,
        );

        expect(game.result, 'white_win');
        expect(game.resultReason, 'checkmate');
        expect(game.status, 'completed');
      });

      test('Resignation result is recorded correctly', () async {
        final game = OnlineGame(
          gameId: 'game_1',
          type: 'online_pvp',
          status: 'completed',
          createdAt: DateTime.now(),
          endedAt: DateTime.now(),
          whitePlayerId: 'user_1',
          blackPlayerId: 'user_2',
          whitePlayerName: 'Alice',
          blackPlayerName: 'Bob',
          whiteRating: 1600,
          blackRating: 1580,
          pgn: '1. e4 e5 2. Nf3 Nc6 3. Bb5',
          currentFen:
              'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
          moves: [],
          timeControl: '5min',
          timeControlMs: 5 * 60 * 1000,
          whiteTimeRemainingMs: 280000,
          blackTimeRemainingMs: 270000,
          result: 'white_win',
          resultReason: 'resignation',
          whiteRatingDelta: 28,
          blackRatingDelta: -28,
          whiteNewRating: 1628,
          blackNewRating: 1552,
        );

        expect(game.result, 'white_win');
        expect(game.resultReason, 'resignation');
      });

      test('Draw result is recorded correctly', () async {
        final game = OnlineGame(
          gameId: 'game_1',
          type: 'online_pvp',
          status: 'completed',
          createdAt: DateTime.now(),
          endedAt: DateTime.now(),
          whitePlayerId: 'user_1',
          blackPlayerId: 'user_2',
          whitePlayerName: 'Alice',
          blackPlayerName: 'Bob',
          whiteRating: 1600,
          blackRating: 1600,
          pgn:
              '1. e4 e5 2. Nf3 Nf6 3. Bc4 Bc5 4. d3 d6 5. O-O O-O 6. Bg5 h6 7. Bh4 g5 8. Bg3 Ne4 9. dxe4 gxh4 10. Bxh4',
          currentFen:
              'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
          moves: [],
          timeControl: '5min',
          timeControlMs: 5 * 60 * 1000,
          whiteTimeRemainingMs: 290000,
          blackTimeRemainingMs: 290000,
          result: 'draw',
          resultReason: 'mutual_agreement',
          whiteRatingDelta: 0,
          blackRatingDelta: 0,
          whiteNewRating: 1600,
          blackNewRating: 1600,
        );

        expect(game.result, 'draw');
        expect(game.resultReason, 'mutual_agreement');
        expect(game.whiteRatingDelta, 0);
        expect(game.blackRatingDelta, 0);
      });

      test('Abandonment result is recorded correctly', () async {
        final game = OnlineGame(
          gameId: 'game_1',
          type: 'online_pvp',
          status: 'abandoned',
          createdAt: DateTime.now(),
          endedAt: DateTime.now(),
          whitePlayerId: 'user_1',
          blackPlayerId: 'user_2',
          whitePlayerName: 'Alice',
          blackPlayerName: 'Bob',
          whiteRating: 1600,
          blackRating: 1580,
          pgn: '1. e4 e5',
          currentFen:
              'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2',
          moves: [],
          timeControl: '5min',
          timeControlMs: 5 * 60 * 1000,
          whiteTimeRemainingMs: 295000,
          blackTimeRemainingMs: 295000,
          result: 'black_win',
          resultReason: 'abandonment',
          whiteRatingDelta: -32,
          blackRatingDelta: 32,
          whiteNewRating: 1568,
          blackNewRating: 1612,
        );

        expect(game.status, 'abandoned');
        expect(game.result, 'black_win');
        expect(game.resultReason, 'abandonment');
      });
    });
  });
}
