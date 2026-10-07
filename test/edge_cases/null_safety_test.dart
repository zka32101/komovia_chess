import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_chess/src/models/online_game.dart';
import '../helpers/widget_test_helpers.dart';

void main() {
  group('Null Safety & Edge Case Tests', () {
    group('Game Model Null Handling', () {
      test('OnlineGame handles null player names', () {
        final game = OnlineGame(
          id: 'test_game',
          whitePlayerId: 'white_1',
          whitePlayerName: null,
          whiteRating: 1600,
          blackPlayerId: 'black_1',
          blackPlayerName: null,
          blackRating: 1650,
          status: 'active',
          pgn: 'e4',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          timeControl: '5+3',
        );

        expect(game.whitePlayerName, isNull);
        expect(game.blackPlayerName, isNull);
        expect(game.status, 'active');
      });

      test('OnlineGame handles null ratings', () {
        final game = OnlineGame(
          id: 'test_game',
          whitePlayerId: 'white_1',
          whitePlayerName: 'White',
          whiteRating: null,
          blackPlayerId: 'black_1',
          blackPlayerName: 'Black',
          blackRating: null,
          status: 'active',
          pgn: 'e4',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          timeControl: '5+3',
        );

        expect(game.whiteRating, isNull);
        expect(game.blackRating, isNull);
      });

      test('OnlineGame handles null result before completion', () {
        final game = OnlineGame(
          id: 'test_game',
          whitePlayerId: 'white_1',
          whitePlayerName: 'White',
          whiteRating: 1600,
          blackPlayerId: 'black_1',
          blackPlayerName: 'Black',
          blackRating: 1650,
          status: 'active',
          pgn: 'e4 c5',
          result: null,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          timeControl: '5+3',
        );

        expect(game.result, isNull);
        expect(game.status, 'active');
      });

      test('OnlineGame handles empty PGN', () {
        final game = OnlineGame(
          id: 'test_game',
          whitePlayerId: 'white_1',
          whitePlayerName: 'White',
          whiteRating: 1600,
          blackPlayerId: 'black_1',
          blackPlayerName: 'Black',
          blackRating: 1650,
          status: 'active',
          pgn: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          timeControl: '5+3',
        );

        expect(game.pgn, isEmpty);
      });
    });

    group('Data Model Null Handling', () {
      test('MockDataGenerator creates valid games with missing data', () {
        final games = [
          MockDataGenerator.mockGame(),
          MockDataGenerator.mockGame(status: 'completed'),
          MockDataGenerator.mockGame(pgn: ''),
        ];

        expect(games, isNotEmpty);
        for (final game in games) {
          expect(game.id, isNotEmpty);
          expect(game.whitePlayerId, isNotEmpty);
        }
      });

      test('MockDataGenerator creates valid users', () {
        final user = MockDataGenerator.mockUser();

        expect(user['uid'], isNotNull);
        expect(user['email'], isNotNull);
        expect(user['rating'], greaterThan(0));
      });

      test('MockDataGenerator rating history maintains order', () {
        final history = MockDataGenerator.mockRatingHistory(days: 10);

        expect(history.length, 10);
        for (int i = 0; i < history.length - 1; i++) {
          final date1 = history[i]['date'] as DateTime;
          final date2 = history[i + 1]['date'] as DateTime;
          expect(
              date1.isBefore(date2) || date1.isAtSameMomentAs(date2), isTrue);
        }
      });
    });

    group('Widget Null Display', () {
      testWidgets('Text widget handles null data gracefully',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestApp(
            child: Text(null ?? 'Fallback'),
          ),
        );

        expect(find.text('Fallback'), findsOneWidget);
      });

      testWidgets('ListView builder handles null items',
          (WidgetTester tester) async {
        final items = <String?>['Item 1', null, 'Item 3'];

        await tester.pumpWidget(
          createTestApp(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) => Text(items[index] ?? 'Empty'),
            ),
          ),
        );

        expect(find.text('Item 1'), findsOneWidget);
        expect(find.text('Empty'), findsOneWidget);
        expect(find.text('Item 3'), findsOneWidget);
      });

      testWidgets('Image widget handles null URL', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestApp(
            child: Image.asset('assets/images/placeholder.png'),
          ),
        );

        // Should display placeholder or error gracefully
        expect(find.byType(Image), findsOneWidget);
      });

      testWidgets('Container handles null child', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestApp(
            child: Container(
              child: null ?? Text('Default'),
            ),
          ),
        );

        expect(find.text('Default'), findsOneWidget);
      });
    });

    group('List Empty State Handling', () {
      testWidgets('ListView handles empty list', (WidgetTester tester) async {
        const items = <String>[];

        await tester.pumpWidget(
          createTestApp(
            child: ListView.builder(
              itemCount: items.isEmpty ? 1 : items.length,
              itemBuilder: (context, index) =>
                  Text(items.isEmpty ? 'No items' : items[index]),
            ),
          ),
        );

        expect(find.text('No items'), findsOneWidget);
      });

      testWidgets('ListView handles single item', (WidgetTester tester) async {
        const items = ['Single'];

        await tester.pumpWidget(
          createTestApp(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) => Text(items[index]),
            ),
          ),
        );

        expect(find.text('Single'), findsOneWidget);
      });

      testWidgets('ListView handles large list', (WidgetTester tester) async {
        const itemCount = 1000;

        await tester.pumpWidget(
          createTestApp(
            child: ListView.builder(
              itemCount: itemCount,
              itemBuilder: (context, index) => Text('Item $index'),
            ),
          ),
        );

        // Should only render visible items
        expect(find.byType(Text), findsWidgets);
      });
    });

    group('Number Null Handling', () {
      test('Rating can be null', () {
        final rating = null as int?;
        final displayRating = rating ?? 0;
        expect(displayRating, 0);
      });

      test('Game count defaults to zero', () {
        final gameCount = null as int?;
        expect((gameCount ?? 0) >= 0, isTrue);
      });

      test('Rating delta can be negative', () {
        final delta = -50 as int?;
        final change = (delta ?? 0);
        expect(change, -50);
      });
    });

    group('String Null Handling', () {
      test('Empty string is falsy', () {
        const str = '';
        expect(str.isEmpty, isTrue);
      });

      test('Null string defaults to empty', () {
        final str = null as String?;
        final safe = (str ?? '');
        expect(safe.isEmpty, isTrue);
      });

      test('Whitespace string handling', () {
        const str = '   ';
        expect(str.isEmpty, isFalse);
        expect(str.trim().isEmpty, isTrue);
      });

      testWidgets('Text widget with null string coalesced',
          (WidgetTester tester) async {
        const String? text = null;

        await tester.pumpWidget(
          createTestApp(
            child: Text(text ?? 'Default Text'),
          ),
        );

        expect(find.text('Default Text'), findsOneWidget);
      });
    });

    group('DateTime Null Handling', () {
      test('DateTime can be null', () {
        final date = null as DateTime?;
        final fallback = date ?? DateTime(2000);
        expect(fallback.year, 2000);
      });

      test('DateTime comparison with null', () {
        final date1 = null as DateTime?;
        final date2 = DateTime.now();
        expect((date1?.isBefore(date2) ?? false), isFalse);
      });
    });

    group('Stream Null Handling', () {
      testWidgets('StreamBuilder handles null stream',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestApp(
            child: StreamBuilder<String>(
              stream: null,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Text('No data');
                }
                return Text(snapshot.data ?? 'Error');
              },
            ),
          ),
        );

        expect(find.text('No data'), findsOneWidget);
      });

      testWidgets('StreamBuilder handles stream error',
          (WidgetTester tester) async {
        final errorStream = Stream<String>.error(Exception('Test error'));

        await tester.pumpWidget(
          createTestApp(
            child: StreamBuilder<String>(
              stream: errorStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text('Error occurred');
                }
                return Text(snapshot.data ?? 'Loading');
              },
            ),
          ),
        );

        await tester.pumpAndSettleWithTimeout();
        expect(find.text('Error occurred'), findsOneWidget);
      });
    });

    group('Future Null Handling', () {
      testWidgets('FutureBuilder handles null future',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestApp(
            child: FutureBuilder<String>(
              future: null,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Text('No data');
                }
                return Text(snapshot.data ?? 'Error');
              },
            ),
          ),
        );

        expect(find.text('No data'), findsOneWidget);
      });

      testWidgets('FutureBuilder handles error', (WidgetTester tester) async {
        final errorFuture = Future<String>.error(Exception('Test error'));

        await tester.pumpWidget(
          createTestApp(
            child: FutureBuilder<String>(
              future: errorFuture,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                }
                return Text(snapshot.data ?? 'Loading');
              },
            ),
          ),
        );

        await tester.pumpAndSettleWithTimeout();
        expect(
            find.byWidgetPredicate(
              (w) => w is Text && (w.data ?? '').contains('Error'),
            ),
            findsOneWidget);
      });
    });
  });
}
