import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_chess/src/widgets/charts/chart_utils.dart';

void main() {
  group('ChartColors', () {
    testWidgets('getPerformanceColor returns green for high percentage (light)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final color = ChartColors.getPerformanceColor(70, context);
                expect(color, const Color(0xFF2CA02C));
                return Container();
              },
            ),
          ),
        ),
      );
    });

    testWidgets(
        'getPerformanceColor returns orange for medium percentage (light)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final color = ChartColors.getPerformanceColor(50, context);
                expect(color, const Color(0xFFFF7F0E));
                return Container();
              },
            ),
          ),
        ),
      );
    });

    testWidgets('getPerformanceColor returns red for low percentage (light)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final color = ChartColors.getPerformanceColor(30, context);
                expect(color, const Color(0xFFD62728));
                return Container();
              },
            ),
          ),
        ),
      );
    });

    testWidgets('getStreakColor returns green for win streak (light)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final color = ChartColors.getStreakColor(true, context);
                expect(color, const Color(0xFF2CA02C));
                return Container();
              },
            ),
          ),
        ),
      );
    });

    testWidgets('getStreakColor returns red for loss streak (light)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final color = ChartColors.getStreakColor(false, context);
                expect(color, const Color(0xFFD62728));
                return Container();
              },
            ),
          ),
        ),
      );
    });

    testWidgets('getPrimaryColor returns correct color (light)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final color = ChartColors.getPrimaryColor(context);
                expect(color, const Color(0xFF1F77B4));
                return Container();
              },
            ),
          ),
        ),
      );
    });

    testWidgets('getGradientColors returns list of two colors',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final colors = ChartColors.getGradientColors(context);
                expect(colors.length, 2);
                expect(colors[0], isA<Color>());
                expect(colors[1], isA<Color>());
                return Container();
              },
            ),
          ),
        ),
      );
    });
  });

  group('ChartConfig', () {
    test('getGridInterval returns 20 for range <= 100', () {
      expect(ChartConfig.getGridInterval(1000, 1100), 20);
    });

    test('getGridInterval returns 50 for range <= 200', () {
      expect(ChartConfig.getGridInterval(1000, 1150), 50);
    });

    test('getGridInterval returns 100 for range <= 500', () {
      expect(ChartConfig.getGridInterval(1000, 1300), 100);
    });

    test('getGridInterval returns 200 for range > 500', () {
      expect(ChartConfig.getGridInterval(1000, 1600), 200);
    });

    test('formatRating returns string representation', () {
      expect(ChartConfig.formatRating(1500), '1500');
      expect(ChartConfig.formatRating(2000), '2000');
    });

    test('formatDate formats date correctly', () {
      final date = DateTime(2026, 8, 26);
      expect(ChartConfig.formatDate(date), '8/26');
    });

    test('formatPercentage adds % symbol', () {
      expect(ChartConfig.formatPercentage(75), '75%');
      expect(ChartConfig.formatPercentage(100), '100%');
    });

    test('constants have correct values', () {
      expect(ChartConfig.gridInterval, 200.0);
      expect(ChartConfig.borderWidth, 2.0);
      expect(ChartConfig.dotRadius, 6.0);
      expect(ChartConfig.animationDuration, const Duration(milliseconds: 300));
      expect(
          ChartConfig.chartEntranceDuration, const Duration(milliseconds: 500));
    });
  });

  group('ColorExtension', () {
    testWidgets('ColorExtension getPerformanceColor works correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final color = context.getPerformanceColor(65);
                expect(color, isA<Color>());
                return Container();
              },
            ),
          ),
        ),
      );
    });

    testWidgets('ColorExtension getStreakColor works correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final color = context.getStreakColor(true);
                expect(color, isA<Color>());
                return Container();
              },
            ),
          ),
        ),
      );
    });

    testWidgets('ColorExtension getPrimaryChartColor works correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final color = context.getPrimaryChartColor();
                expect(color, isA<Color>());
                return Container();
              },
            ),
          ),
        ),
      );
    });

    testWidgets('ColorExtension getGradientColors works correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final colors = context.getGradientColors();
                expect(colors, isA<List<Color>>());
                expect(colors.length, 2);
                return Container();
              },
            ),
          ),
        ),
      );
    });
  });
}
