import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_chess/src/widgets/time_clock.dart';

/// Regression coverage for TimeClock's komovia_core clock.dart adoption
/// (formatClock/warningLevelFor replacing this widget's own duplicated
/// mm:ss digit math and color thresholds) — confirms the externally
/// observable display/color behavior is unchanged.
void main() {
  Future<void> pump(WidgetTester tester, int timeMs, {bool showCentiseconds = true}) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TimeClock(timeMs: timeMs, showCentiseconds: showCentiseconds),
        ),
      ),
    );
  }

  testWidgets('formats under a minute as mm:ss.cs when showCentiseconds is true', (tester) async {
    await pump(tester, 9340); // 9.34s
    expect(find.text('00:09.34'), findsOneWidget);
  });

  testWidgets('omits centiseconds when showCentiseconds is false', (tester) async {
    await pump(tester, 9340, showCentiseconds: false);
    expect(find.text('00:09'), findsOneWidget);
  });

  testWidgets('formats at or above a minute (and under an hour) as mm:ss, no centiseconds', (tester) async {
    await pump(tester, 65000); // 1:05
    expect(find.text('01:05'), findsOneWidget);
  });

  testWidgets('formats an hour or more as Xh YYm (correspondence-scale, unaffected by core.formatClock)', (tester) async {
    await pump(tester, Duration(hours: 2, minutes: 15).inMilliseconds);
    expect(find.text('2h 15m'), findsOneWidget);
  });

  testWidgets('formats a day or more as Xd YYh (correspondence-scale, unaffected by core.formatClock)', (tester) async {
    await pump(tester, Duration(days: 3, hours: 4).inMilliseconds);
    expect(find.text('3d 04h'), findsOneWidget);
  });

  testWidgets('shows the "Low Time" label under 1 minute but not above', (tester) async {
    await pump(tester, 30000);
    expect(find.text('Low Time'), findsOneWidget);

    await pump(tester, 65000);
    expect(find.text('Low Time'), findsNothing);
  });

  testWidgets('does not show "Low Time" once time has fully expired (timeMs == 0)', (tester) async {
    await pump(tester, 0);
    expect(find.text('Low Time'), findsNothing);
  });
}
