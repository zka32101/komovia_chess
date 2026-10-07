import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_chess/src/widgets/difficulty_selector.dart';
import 'package:komovia_chess/src/services/ai_opponent_engine.dart';

void main() {
  group('DifficultySelector', () {
    testWidgets('renders all difficulty options', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DifficultySelector(
              onDifficultySelected: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Easy'), findsWidgets);
      expect(find.text('Medium'), findsWidgets);
      expect(find.text('Hard'), findsWidgets);
    });

    testWidgets('displays difficulty descriptions',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DifficultySelector(
              onDifficultySelected: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Perfect for beginners. AI plays basic moves.'),
          findsOneWidget);
      expect(
          find.text('Good challenge. AI plays with strategy.'), findsOneWidget);
      expect(find.text('Very challenging. AI plays strongly.'), findsOneWidget);
    });

    testWidgets('has radio buttons for selection', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DifficultySelector(
              onDifficultySelected: (_) {},
            ),
          ),
        ),
      );

      expect(find.byType(Radio<AIDifficulty>), findsWidgets);
    });

    testWidgets('medium is selected by default', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DifficultySelector(
              onDifficultySelected: (_) {},
            ),
          ),
        ),
      );

      final radios = find.byType(Radio<AIDifficulty>);
      expect(radios, findsWidgets);
    });

    testWidgets('respects initial difficulty', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DifficultySelector(
              initialDifficulty: AIDifficulty.hard,
              onDifficultySelected: (_) {},
            ),
          ),
        ),
      );

      // Hard should be pre-selected
      expect(find.byType(Radio<AIDifficulty>), findsWidgets);
    });

    testWidgets('calls callback when difficulty selected',
        (WidgetTester tester) async {
      AIDifficulty? selectedDifficulty;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DifficultySelector(
              onDifficultySelected: (difficulty) {
                selectedDifficulty = difficulty;
              },
            ),
          ),
        ),
      );

      // Select Hard difficulty
      final hardRadio = find.byWidgetPredicate(
        (widget) =>
            widget is Radio<AIDifficulty> && widget.value == AIDifficulty.hard,
      );
      await tester.tap(hardRadio.first);
      await tester.pumpAndSettle();

      // Click Start Game
      await tester.tap(find.text('Start Game'));
      await tester.pumpAndSettle();

      expect(selectedDifficulty, AIDifficulty.hard);
    });

    testWidgets('closes dialog when Cancel is tapped',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DifficultySelector(
              onDifficultySelected: (_) {},
            ),
          ),
        ),
      );

      expect(find.byType(DifficultySelector), findsOneWidget);
    });

    testWidgets('updates selection when radio button tapped',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DifficultySelector(
              onDifficultySelected: (_) {},
            ),
          ),
        ),
      );

      final easyRadio = find.byWidgetPredicate(
        (widget) =>
            widget is Radio<AIDifficulty> && widget.value == AIDifficulty.easy,
      );

      await tester.tap(easyRadio.first);
      await tester.pump();

      // Easy should now be selected
      expect(find.byType(Radio<AIDifficulty>), findsWidgets);
    });

    testWidgets('updates selection when card tapped',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DifficultySelector(
              onDifficultySelected: (_) {},
            ),
          ),
        ),
      );

      // Tap on the Medium card
      final mediumCards = find.ancestor(
        of: find.text('Medium'),
        matching: find.byType(ListTile),
      );

      await tester.tap(mediumCards.first);
      await tester.pump();

      expect(find.byType(Radio<AIDifficulty>), findsWidgets);
    });
  });
}
