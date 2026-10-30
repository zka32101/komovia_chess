import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_chess/src/services/repertoire_scheduler.dart';

void main() {
  group('RepertoireScheduler', () {
    test('a correct answer advances the box by one', () {
      expect(RepertoireScheduler.nextBox(1, correct: true), 2);
      expect(RepertoireScheduler.nextBox(3, correct: true), 4);
    });

    test('a correct answer never advances past maxBox', () {
      expect(
        RepertoireScheduler.nextBox(RepertoireScheduler.maxBox, correct: true),
        RepertoireScheduler.maxBox,
      );
    });

    test('a wrong answer always resets to box 1, regardless of current box',
        () {
      expect(RepertoireScheduler.nextBox(1, correct: false), 1);
      expect(RepertoireScheduler.nextBox(3, correct: false), 1);
      expect(
        RepertoireScheduler.nextBox(RepertoireScheduler.maxBox,
            correct: false),
        1,
      );
    });

    test('later boxes have strictly longer review intervals', () {
      var previous = Duration.zero;
      for (var box = 2; box <= RepertoireScheduler.maxBox; box++) {
        final interval = RepertoireScheduler.intervalForBox(box);
        expect(interval, greaterThan(previous),
            reason: 'box $box should wait longer than box ${box - 1}');
        previous = interval;
      }
    });

    test('a correct review\'s due date is after a wrong review\'s due date',
        () {
      final now = DateTime(2026, 1, 1);
      final correctResult = RepertoireScheduler.review(
        2,
        correct: true,
        reviewedAt: now,
      );
      final wrongResult = RepertoireScheduler.review(
        2,
        correct: false,
        reviewedAt: now,
      );

      expect(correctResult.box, 3);
      expect(wrongResult.box, 1);
      expect(correctResult.dueAt.isAfter(wrongResult.dueAt), isTrue);
    });

    group('isDue', () {
      test('a line due exactly now counts as due', () {
        final now = DateTime(2026, 5, 1, 12);
        expect(RepertoireScheduler.isDue(now, now), isTrue);
      });

      test('a line due in the past counts as due', () {
        final now = DateTime(2026, 5, 1, 12);
        final due = now.subtract(const Duration(days: 1));
        expect(RepertoireScheduler.isDue(due, now), isTrue);
      });

      test('a line due in the future does not count as due', () {
        final now = DateTime(2026, 5, 1, 12);
        final due = now.add(const Duration(days: 1));
        expect(RepertoireScheduler.isDue(due, now), isFalse);
      });
    });

    test(
        'several correct answers in a row climb through the boxes in order, '
        'one at a time, with increasing intervals', () {
      var box = 1;
      var now = DateTime(2026, 1, 1);
      final observedBoxes = <int>[box];
      final observedIntervals = <Duration>[];

      for (var i = 0; i < RepertoireScheduler.maxBox + 2; i++) {
        final result = RepertoireScheduler.review(
          box,
          correct: true,
          reviewedAt: now,
        );
        observedIntervals.add(result.dueAt.difference(now));
        box = result.box;
        now = result.dueAt;
        observedBoxes.add(box);
      }

      // Climbs 1 -> 2 -> 3 -> 4 -> 5, then stays at 5 for the remaining
      // reviews (maxBox is 5; we ran maxBox + 2 = 7 reviews).
      expect(
        observedBoxes,
        [1, 2, 3, 4, 5, 5, 5, 5],
      );
      // Each interval while still climbing is strictly longer than the
      // previous one; once pinned at maxBox the interval repeats.
      expect(observedIntervals[0], lessThan(observedIntervals[1]));
      expect(observedIntervals[1], lessThan(observedIntervals[2]));
      expect(observedIntervals[2], lessThan(observedIntervals[3]));
      expect(observedIntervals[3], equals(observedIntervals[4]));
      expect(observedIntervals[4], equals(observedIntervals[5]));
    });

    test(
        'a wrong answer after climbing several boxes drops straight back to '
        'box 1, undoing all prior progress on that line', () {
      var box = 1;
      for (var i = 0; i < 3; i++) {
        box = RepertoireScheduler.nextBox(box, correct: true);
      }
      expect(box, 4);

      box = RepertoireScheduler.nextBox(box, correct: false);
      expect(box, 1);
    });
  });
}
