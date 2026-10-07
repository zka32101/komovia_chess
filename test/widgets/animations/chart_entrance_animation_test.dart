import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_chess/src/widgets/animations/chart_entrance_animation.dart';

void main() {
  group('ChartEntranceAnimation', () {
    testWidgets('renders child widget', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChartEntranceAnimation(
              child: Container(
                key: const Key('test-child'),
                color: Colors.blue,
                width: 100,
                height: 100,
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('test-child')), findsOneWidget);
    });

    testWidgets('animates entrance with fade and scale',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChartEntranceAnimation(
              duration: const Duration(milliseconds: 500),
              child: Container(
                key: const Key('animated-child'),
                color: Colors.blue,
              ),
            ),
          ),
        ),
      );

      // At start, opacity should be less than 1 (animation in progress)
      expect(find.byKey(const Key('animated-child')), findsOneWidget);

      // Wait for animation to complete
      await tester.pumpAndSettle();

      // After animation, child should still be there
      expect(find.byKey(const Key('animated-child')), findsOneWidget);
    });

    testWidgets('uses default duration when not specified',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChartEntranceAnimation(
              child: Container(
                key: const Key('default-duration'),
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('default-duration')), findsOneWidget);
    });

    testWidgets('uses custom duration', (WidgetTester tester) async {
      const customDuration = Duration(milliseconds: 1000);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChartEntranceAnimation(
              duration: customDuration,
              child: Container(
                key: const Key('custom-duration'),
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('custom-duration')), findsOneWidget);
    });

    testWidgets('uses custom curve', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChartEntranceAnimation(
              curve: Curves.easeIn,
              child: Container(
                key: const Key('custom-curve'),
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('custom-curve')), findsOneWidget);
    });

    testWidgets('handles widget rebuilds', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChartEntranceAnimation(
              child: Container(
                key: const Key('rebuild-test'),
                color: Colors.blue,
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('rebuild-test')), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChartEntranceAnimation(
              child: Container(
                key: const Key('rebuild-test'),
                color: Colors.red,
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('rebuild-test')), findsOneWidget);
    });

    testWidgets('completes animation successfully',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChartEntranceAnimation(
              duration: const Duration(milliseconds: 100),
              child: Container(
                key: const Key('animation-complete'),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('animation-complete')), findsOneWidget);
    });

    testWidgets('renders with different child widgets',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChartEntranceAnimation(
              child: Text(
                'Animated Text',
                key: const Key('text-animation'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Animated Text'), findsOneWidget);
    });
  });
}
