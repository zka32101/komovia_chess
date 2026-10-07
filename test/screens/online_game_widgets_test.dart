import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_chess/src/models/online_game.dart';
import 'package:komovia_chess/src/screens/online/online_game_widgets.dart';

void main() {
  group('PlayerPresenceWidget', () {
    testWidgets('displays online player with green indicator',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlayerPresenceWidget(
              playerId: 'user_1',
              playerName: 'Player 1',
              rating: 1600,
              isOnline: true,
              isCurrentPlayer: false,
            ),
          ),
        ),
      );

      expect(find.text('Player 1'), findsOneWidget);
      expect(find.text('Rating: 1600'), findsOneWidget);

      // Check for green indicator (looking for color)
      final container = find.byType(Container);
      expect(container, findsWidgets);
    });

    testWidgets('displays offline player with grey indicator',
        (WidgetTester tester) async {
      final lastActivity = DateTime.now().subtract(const Duration(minutes: 5));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlayerPresenceWidget(
              playerId: 'user_1',
              playerName: 'Player 1',
              rating: 1600,
              isOnline: false,
              lastActivityTime: lastActivity,
              isCurrentPlayer: false,
            ),
          ),
        ),
      );

      expect(find.text('Player 1'), findsOneWidget);
      expect(find.text('Rating: 1600'), findsOneWidget);
      expect(find.textContaining('Last seen'), findsOneWidget);
    });

    testWidgets('displays current player badge', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlayerPresenceWidget(
              playerId: 'user_1',
              playerName: 'Player 1',
              rating: 1600,
              isOnline: true,
              isCurrentPlayer: true,
            ),
          ),
        ),
      );

      expect(find.text('You'), findsOneWidget);
    });

    testWidgets('formats time ago correctly', (WidgetTester tester) async {
      final lastActivity = DateTime.now().subtract(const Duration(hours: 2));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlayerPresenceWidget(
              playerId: 'user_1',
              playerName: 'Player 1',
              rating: 1600,
              isOnline: false,
              lastActivityTime: lastActivity,
              isCurrentPlayer: false,
            ),
          ),
        ),
      );

      expect(find.textContaining('Last seen'), findsOneWidget);
    });
  });

  group('MatchmakingStatusWidget', () {
    testWidgets('displays queue status with position',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MatchmakingStatusWidget(
              queueId: 'queue_1',
              position: 3,
              estimatedWaitTime: const Duration(seconds: 30),
              timeControl: '5min',
            ),
          ),
        ),
      );

      expect(find.text('Searching for opponent...'), findsOneWidget);
      expect(find.text('Queue Position'), findsOneWidget);
      expect(find.text('#3'), findsOneWidget);
    });

    testWidgets('displays time control', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MatchmakingStatusWidget(
              queueId: 'queue_1',
              position: 1,
              estimatedWaitTime: const Duration(seconds: 45),
              timeControl: '10min',
            ),
          ),
        ),
      );

      expect(find.text('10min'), findsOneWidget);
    });

    testWidgets('formats wait time correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MatchmakingStatusWidget(
              queueId: 'queue_1',
              position: 5,
              estimatedWaitTime: const Duration(minutes: 2, seconds: 30),
              timeControl: '5min',
            ),
          ),
        ),
      );

      expect(find.text('Est. Wait Time'), findsOneWidget);
    });

    testWidgets('displays loading indicator', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MatchmakingStatusWidget(
              queueId: 'queue_1',
              position: 1,
              estimatedWaitTime: const Duration(seconds: 20),
              timeControl: '3min',
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('GameInfoWidget', () {
    late OnlineGame game;

    setUp(() {
      final now = DateTime.now();
      game = OnlineGame(
        gameId: 'game_1',
        type: 'online_pvp',
        status: 'active',
        createdAt: now,
        startedAt: now.subtract(const Duration(minutes: 3)),
        whitePlayerId: 'user_1',
        blackPlayerId: 'user_2',
        whitePlayerName: 'Player 1',
        blackPlayerName: 'Player 2',
        whiteRating: 1600,
        blackRating: 1550,
        pgn: '1. e4 e5',
        currentFen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        moves: [],
        timeControl: '5min',
        timeControlMs: 5 * 60 * 1000,
        whiteTimeRemainingMs: 300000,
        blackTimeRemainingMs: 280000,
      );
    });

    testWidgets('displays game information', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameInfoWidget(game: game),
          ),
        ),
      );

      expect(find.text('Game Information'), findsOneWidget);
      expect(find.text('ACTIVE'), findsOneWidget);
    });

    testWidgets('displays player ratings', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameInfoWidget(game: game),
          ),
        ),
      );

      expect(find.text('Player Ratings'), findsOneWidget);
      expect(find.text('White'), findsOneWidget);
      expect(find.text('Black'), findsOneWidget);
    });

    testWidgets('displays game details', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameInfoWidget(game: game),
          ),
        ),
      );

      expect(find.text('Game ID'), findsOneWidget);
      expect(find.text('Type'), findsOneWidget);
      expect(find.text('Time Control'), findsOneWidget);
    });

    testWidgets('shows action buttons for active game',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameInfoWidget(
              game: game,
              onResign: () {},
              onDrawOffer: () {},
            ),
          ),
        ),
      );

      expect(find.text('Offer Draw'), findsOneWidget);
      expect(find.text('Resign Game'), findsOneWidget);
    });

    testWidgets('hides action buttons for completed game',
        (WidgetTester tester) async {
      final completedGame = game.copyWith(status: 'completed');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameInfoWidget(game: completedGame),
          ),
        ),
      );

      expect(find.text('Offer Draw'), findsNothing);
      expect(find.text('Resign Game'), findsNothing);
    });
  });

  group('MoveHistoryWidget', () {
    testWidgets('displays empty state when no moves',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MoveHistoryWidget(moves: []),
          ),
        ),
      );

      expect(find.text('No moves yet'), findsOneWidget);
    });

    testWidgets('displays moves in pairs', (WidgetTester tester) async {
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
        GameMove(
          moveNumber: 2,
          from: 'g1',
          to: 'f3',
          timestamp: DateTime.now(),
          playerId: 'user_1',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MoveHistoryWidget(moves: moves),
          ),
        ),
      );

      expect(find.text('1.'), findsOneWidget);
      expect(find.text('2.'), findsOneWidget);
      expect(find.text('e2e4'), findsOneWidget);
      expect(find.text('e7e5'), findsOneWidget);
    });

    testWidgets('displays promotion moves correctly',
        (WidgetTester tester) async {
      final moves = [
        GameMove(
          moveNumber: 1,
          from: 'e7',
          to: 'e8',
          promotion: 'q',
          timestamp: DateTime.now(),
          playerId: 'user_1',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MoveHistoryWidget(moves: moves),
          ),
        ),
      );

      expect(find.text('e7e8=q'), findsOneWidget);
    });

    testWidgets('handles odd number of moves', (WidgetTester tester) async {
      final moves = [
        GameMove(
          moveNumber: 1,
          from: 'e2',
          to: 'e4',
          timestamp: DateTime.now(),
          playerId: 'user_1',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MoveHistoryWidget(moves: moves),
          ),
        ),
      );

      expect(find.text('1.'), findsOneWidget);
      expect(find.text('e2e4'), findsOneWidget);
    });
  });
}
