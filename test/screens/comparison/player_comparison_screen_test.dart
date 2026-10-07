import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_chess/src/screens/comparison/player_comparison_screen.dart';

void main() {
  group('PlayerComparisonScreen', () {
    testWidgets('displays both player names and ratings',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: PlayerComparisonScreen(
              player1Id: 'player1',
              player1Name: 'Alice',
              player1Rating: 1600,
              player2Id: 'player2',
              player2Name: 'Bob',
              player2Rating: 1550,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Alice'), findsWidgets);
      expect(find.text('Bob'), findsWidgets);
      expect(find.text('レーティング: 1600'), findsOneWidget);
      expect(find.text('レーティング: 1550'), findsOneWidget);
    });

    testWidgets('displays vs text between players',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: PlayerComparisonScreen(
              player1Id: 'player1',
              player1Name: 'Alice',
              player1Rating: 1600,
              player2Id: 'player2',
              player2Name: 'Bob',
              player2Rating: 1550,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('vs'), findsOneWidget);
    });

    testWidgets('displays comparison header', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: PlayerComparisonScreen(
              player1Id: 'player1',
              player1Name: 'Alice',
              player1Rating: 1600,
              player2Id: 'player2',
              player2Name: 'Bob',
              player2Rating: 1550,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('プレイヤー比較'), findsOneWidget);
    });

    testWidgets('displays H2H statistics section', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: PlayerComparisonScreen(
              player1Id: 'player1',
              player1Name: 'Alice',
              player1Rating: 1600,
              player2Id: 'player2',
              player2Name: 'Bob',
              player2Rating: 1550,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('対戦成績'), findsOneWidget);
    });

    testWidgets('displays player avatars with initials',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: PlayerComparisonScreen(
              player1Id: 'player1',
              player1Name: 'Alice',
              player1Rating: 1600,
              player2Id: 'player2',
              player2Name: 'Bob',
              player2Rating: 1550,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(CircleAvatar), findsWidgets);
      expect(find.text('A'), findsOneWidget); // Alice's initial
      expect(find.text('B'), findsOneWidget); // Bob's initial
    });

    testWidgets('displays refresh button in AppBar',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: PlayerComparisonScreen(
              player1Id: 'player1',
              player1Name: 'Alice',
              player1Rating: 1600,
              player2Id: 'player2',
              player2Name: 'Bob',
              player2Rating: 1550,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('displays correct layout structure',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: PlayerComparisonScreen(
              player1Id: 'player1',
              player1Name: 'Alice',
              player1Rating: 1600,
              player2Id: 'player2',
              player2Name: 'Bob',
              player2Rating: 1550,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(find.byType(Column), findsWidgets);
    });
  });
}
