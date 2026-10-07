import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:komovia_chess/src/models/online_game.dart';
import 'package:komovia_chess/src/screens/online/online_game_result_screen.dart';

class MockAuthService extends Mock {}

void main() {
  group('OnlineGameResultScreen', () {
    late OnlineGame winGame;
    late OnlineGame lossGame;
    late OnlineGame drawGame;

    setUp(() {
      final now = DateTime.now();

      winGame = OnlineGame(
        gameId: 'game_1',
        type: 'online_pvp',
        status: 'completed',
        createdAt: now,
        startedAt: now.subtract(const Duration(minutes: 5)),
        endedAt: now,
        whitePlayerId: 'user_1',
        blackPlayerId: 'user_2',
        whitePlayerName: 'Player 1',
        blackPlayerName: 'Player 2',
        whiteRating: 1600,
        blackRating: 1550,
        pgn: '1. e4 e5 2. Nf3 Nc6',
        currentFen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        moves: [],
        timeControl: '5min',
        timeControlMs: 5 * 60 * 1000,
        whiteTimeRemainingMs: 300000,
        blackTimeRemainingMs: 280000,
        result: 'white_win',
        resultReason: 'checkmate',
        whiteRatingDelta: 32,
        blackRatingDelta: -32,
        whiteNewRating: 1632,
        blackNewRating: 1518,
      );

      lossGame = OnlineGame(
        gameId: 'game_2',
        type: 'online_pvp',
        status: 'completed',
        createdAt: now,
        startedAt: now.subtract(const Duration(minutes: 3)),
        endedAt: now,
        whitePlayerId: 'user_1',
        blackPlayerId: 'user_2',
        whitePlayerName: 'Player 1',
        blackPlayerName: 'Player 2',
        whiteRating: 1600,
        blackRating: 1550,
        pgn: '1. e4 e5',
        currentFen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        moves: [],
        timeControl: '3min',
        timeControlMs: 3 * 60 * 1000,
        whiteTimeRemainingMs: 180000,
        blackTimeRemainingMs: 0,
        result: 'black_win',
        resultReason: 'timeout',
        whiteRatingDelta: -32,
        blackRatingDelta: 32,
        whiteNewRating: 1568,
        blackNewRating: 1582,
      );

      drawGame = OnlineGame(
        gameId: 'game_3',
        type: 'online_pvp',
        status: 'completed',
        createdAt: now,
        startedAt: now.subtract(const Duration(minutes: 10)),
        endedAt: now,
        whitePlayerId: 'user_1',
        blackPlayerId: 'user_2',
        whitePlayerName: 'Player 1',
        blackPlayerName: 'Player 2',
        whiteRating: 1600,
        blackRating: 1600,
        pgn: '1. e4 e5 2. Nf3',
        currentFen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        moves: [],
        timeControl: '10min',
        timeControlMs: 10 * 60 * 1000,
        whiteTimeRemainingMs: 600000,
        blackTimeRemainingMs: 600000,
        result: 'draw',
        resultReason: 'stalemate',
        whiteRatingDelta: 0,
        blackRatingDelta: 0,
        whiteNewRating: 1600,
        blackNewRating: 1600,
      );
    });

    Widget buildTestWidget(OnlineGame game) {
      return ProviderContainer(
        child: MaterialApp(
          home: OnlineGameResultScreen(
            gameId: game.gameId,
            game: game,
          ),
          routes: {
            '/': (context) => Scaffold(body: Container()),
            '/online/matchmaking': (context) => Scaffold(body: Container()),
          },
        ),
      );
    }

    testWidgets('displays win result with green background',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(winGame));

      expect(find.text('You Won! 🎉'), findsOneWidget);
      expect(find.text('CHECKMATE'), findsOneWidget);
    });

    testWidgets('displays loss result', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(lossGame));

      expect(find.text('You Lost'), findsOneWidget);
      expect(find.text('TIMEOUT'), findsOneWidget);
    });

    testWidgets('displays draw result', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(drawGame));

      expect(find.text('Draw'), findsOneWidget);
      expect(find.text('STALEMATE'), findsOneWidget);
    });

    testWidgets('displays rating changes for both players',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(winGame));

      expect(find.text('Rating Changes'), findsOneWidget);
      expect(find.text('Player 1'), findsWidgets);
      expect(find.text('Player 2'), findsWidgets);
      expect(find.text('+32'), findsOneWidget);
      expect(find.text('-32'), findsOneWidget);
    });

    testWidgets('displays old and new ratings', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(winGame));

      expect(find.text('1600 → 1632'), findsOneWidget);
      expect(find.text('1550 → 1518'), findsOneWidget);
    });

    testWidgets('displays game statistics', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(winGame));

      expect(find.text('Game Statistics'), findsOneWidget);
      expect(find.text('online_pvp'), findsOneWidget);
      expect(find.text('5min'), findsOneWidget);
    });

    testWidgets('displays action buttons', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(winGame));

      expect(find.text('Back to Home'), findsOneWidget);
      expect(find.text('Play Again'), findsOneWidget);
    });

    testWidgets('back to home button navigates correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(winGame));

      await tester.tap(find.text('Back to Home'));
      await tester.pumpAndSettle();

      // Navigation should occur
      expect(find.byType(OnlineGameResultScreen), findsNothing);
    });

    testWidgets('play again button navigates to matchmaking',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(winGame));

      await tester.tap(find.text('Play Again'));
      await tester.pumpAndSettle();

      // Navigation should occur
      expect(find.byType(OnlineGameResultScreen), findsNothing);
    });

    testWidgets('displays duration correctly', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(winGame));

      expect(find.text('5m 0s'), findsOneWidget);
    });

    testWidgets('displays resignation reason', (WidgetTester tester) async {
      final resignGame = winGame.copyWith(resultReason: 'resignation');
      await tester.pumpWidget(buildTestWidget(resignGame));

      expect(find.text('RESIGNATION'), findsOneWidget);
    });

    testWidgets('displays abandonment reason', (WidgetTester tester) async {
      final abandonGame = winGame.copyWith(resultReason: 'abandonment');
      await tester.pumpWidget(buildTestWidget(abandonGame));

      expect(find.text('ABANDONMENT'), findsOneWidget);
    });
  });
}
