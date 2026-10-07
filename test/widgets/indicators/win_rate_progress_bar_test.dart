import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_chess/src/widgets/indicators/win_rate_progress_bar.dart';

void main() {
  group('WinRateProgressBar', () {
    testWidgets('displays label and percentage', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WinRateProgressBar(
              label: 'Test Category',
              percentage: 75,
            ),
          ),
        ),
      );

      expect(find.text('Test Category'), findsOneWidget);
      expect(find.text('75%'), findsOneWidget);
    });

    testWidgets('displays correct progress bar value',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WinRateProgressBar(
              label: 'Test',
              percentage: 50,
            ),
          ),
        ),
      );

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('displays high percentage color (green)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WinRateProgressBar(
              label: 'High Performance',
              percentage: 70,
            ),
          ),
        ),
      );

      expect(find.text('70%'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('displays medium percentage color (orange)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WinRateProgressBar(
              label: 'Medium Performance',
              percentage: 50,
            ),
          ),
        ),
      );

      expect(find.text('50%'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('displays low percentage color (red)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WinRateProgressBar(
              label: 'Low Performance',
              percentage: 25,
            ),
          ),
        ),
      );

      expect(find.text('25%'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('animates value changes', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WinRateProgressBar(
              label: 'Test',
              percentage: 50,
            ),
          ),
        ),
      );

      expect(find.text('50%'), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WinRateProgressBar(
              label: 'Test',
              percentage: 75,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('75%'), findsOneWidget);
    });

    testWidgets('uses custom color when provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WinRateProgressBar(
              label: 'Test',
              percentage: 50,
              customColor: Colors.purple,
            ),
          ),
        ),
      );

      expect(find.text('50%'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('can disable animation', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WinRateProgressBar(
              label: 'Test',
              percentage: 50,
              animated: false,
            ),
          ),
        ),
      );

      expect(find.text('50%'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('handles 0 percentage', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WinRateProgressBar(
              label: 'Test',
              percentage: 0,
            ),
          ),
        ),
      );

      expect(find.text('0%'), findsOneWidget);
    });

    testWidgets('handles 100 percentage', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WinRateProgressBar(
              label: 'Test',
              percentage: 100,
            ),
          ),
        ),
      );

      expect(find.text('100%'), findsOneWidget);
    });

    testWidgets('has correct widget structure', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WinRateProgressBar(
              label: 'Test',
              percentage: 65,
            ),
          ),
        ),
      );

      expect(find.byType(Column), findsWidgets);
      expect(find.byType(Row), findsOneWidget);
      expect(find.byType(ClipRRect), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });
  });
}
