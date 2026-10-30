/// Pure Leitner-box spaced-repetition scheduling logic for opening
/// repertoire review, with no Firestore (or any I/O) dependency at all -
/// same separation `chess_analysis_service.dart`'s pure move-quality
/// logic keeps from its Firestore-touching callers, so this can be
/// exercised with plain unit tests.
///
/// A Leitner system (rather than full SM-2) was chosen deliberately: it's
/// a simpler, still-legitimate, production-used spaced-repetition method
/// (used by real flashcard tools), and "wrong -> box 1, right -> box+1
/// with a longer interval" is trivial to get correct and test
/// exhaustively, unlike SM-2's continuous ease-factor arithmetic. This
/// repo has no existing SM-2-style scheduler anywhere to reuse (grepped
/// for "SM-2"/"ease factor"/"spaced repetition" - no hits before this
/// feature).
class RepertoireScheduler {
  const RepertoireScheduler._();

  /// Box 1 is the newest/most-recently-missed box, reviewed immediately;
  /// box [maxBox] is the most deeply memorized, reviewed least often.
  static const int maxBox = 5;

  /// How long a line in each box waits before it's due again, indexed by
  /// box number (1-based; `_intervals[0]` is unused padding so the box
  /// number can index directly without an off-by-one subtraction at every
  /// call site).
  static const List<Duration> _intervals = [
    Duration.zero,
    Duration.zero, // box 1: due again immediately (same session/day)
    Duration(days: 1), // box 2
    Duration(days: 3), // box 3
    Duration(days: 7), // box 4
    Duration(days: 16), // box 5
  ];

  static Duration intervalForBox(int box) {
    final clamped = box.clamp(1, maxBox);
    return _intervals[clamped];
  }

  /// The box a line moves to after one review outcome. A correct answer
  /// advances one box (capped at [maxBox]); a wrong answer drops all the
  /// way back to box 1, regardless of how high it had climbed - the
  /// standard Leitner rule, and the reason this scheduler is forgiving of
  /// a single slip without erasing all progress on a line that's wrong
  /// only occasionally.
  static int nextBox(int currentBox, {required bool correct}) {
    if (!correct) return 1;
    return (currentBox + 1).clamp(1, maxBox);
  }

  /// The next due date for a line that was just reviewed from [from],
  /// landing in [newBox] as a result of that review.
  static DateTime nextDueDate(int newBox, DateTime from) =>
      from.add(intervalForBox(newBox));

  /// A line is due for review once its [dueAt] is now or in the past -
  /// deliberately `!isAfter` rather than `isBefore` so a line due at
  /// exactly `now` (e.g. a freshly-added line, box 1's zero interval) is
  /// still picked up rather than needing the clock to tick past it first.
  static bool isDue(DateTime dueAt, DateTime now) => !dueAt.isAfter(now);

  /// Convenience wrapper combining [nextBox] and [nextDueDate] for a
  /// review just performed at [reviewedAt] (defaults to now).
  static ({int box, DateTime dueAt}) review(
    int currentBox, {
    required bool correct,
    DateTime? reviewedAt,
  }) {
    final at = reviewedAt ?? DateTime.now();
    final box = nextBox(currentBox, correct: correct);
    return (box: box, dueAt: nextDueDate(box, at));
  }
}
