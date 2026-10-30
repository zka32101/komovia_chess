import 'package:cloud_firestore/cloud_firestore.dart';

/// A single memorized opening repertoire line: a fixed sequence of moves
/// (UCI tokens, same `'e2e4'`/`'e7e8q'` format as `ActiveCpuGame.moveUcis`
/// and `PuzzleModel.moves` elsewhere in this app) the player wants to
/// drill with spaced repetition, for one side only.
///
/// Persisted per-user under `repertoire_lines/{uid}/lines/{lineId}` (a
/// subcollection, since one player has many lines - same shape as
/// `match_history/{playerId}/matches/{matchId}`, not the single
/// one-doc-per-uid shape `ActiveCpuGame` uses).
///
/// [box]/[dueAt] are this line's current Leitner-box scheduling state -
/// see `RepertoireScheduler` for how they're updated. A freshly-added line
/// starts in box 1, due immediately (so it shows up for review the first
/// time the player opens the review screen, rather than silently waiting
/// out an interval it never actually earned).
class RepertoireLine {
  RepertoireLine({
    required this.id,
    required this.uid,
    required this.name,
    required this.playerIsWhite,
    required this.moveUcis,
    this.box = 1,
    required this.dueAt,
    this.lastReviewedAt,
    required this.createdAt,
  });

  final String id;
  final String uid;
  final String name;

  /// Which side the player is memorizing this line *for*. The opponent's
  /// replies (the moves at the other parity of [moveUcis]) are always
  /// auto-played during review, never quizzed - this mirrors how a real
  /// repertoire trainer only drills "my" side of a line.
  final bool playerIsWhite;

  /// The full line, both sides' moves, in order. Must have at least one
  /// move belonging to [playerIsWhite]'s side or there's nothing to quiz.
  final List<String> moveUcis;

  /// Current Leitner box, 1-based. See `RepertoireScheduler.maxBox`.
  final int box;

  /// When this line next becomes due for review. A line is due whenever
  /// `!dueAt.isAfter(now)`.
  final DateTime dueAt;
  final DateTime? lastReviewedAt;
  final DateTime createdAt;

  RepertoireLine copyWith({
    int? box,
    DateTime? dueAt,
    DateTime? lastReviewedAt,
  }) =>
      RepertoireLine(
        id: id,
        uid: uid,
        name: name,
        playerIsWhite: playerIsWhite,
        moveUcis: moveUcis,
        box: box ?? this.box,
        dueAt: dueAt ?? this.dueAt,
        lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
        createdAt: createdAt,
      );

  factory RepertoireLine.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    final rawMoves = data['moveUcis'] as List<dynamic>?;
    return RepertoireLine(
      id: doc.id,
      uid: data['uid'] as String? ?? '',
      name: data['name'] as String? ?? '',
      playerIsWhite: data['playerIsWhite'] as bool? ?? true,
      moveUcis: rawMoves != null
          ? rawMoves.map((m) => m as String).toList()
          : const [],
      box: (data['box'] as num?)?.toInt() ?? 1,
      dueAt: data['dueAt'] != null
          ? (data['dueAt'] as Timestamp).toDate()
          : DateTime.now(),
      lastReviewedAt: data['lastReviewedAt'] != null
          ? (data['lastReviewedAt'] as Timestamp).toDate()
          : null,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'uid': uid,
        'name': name,
        'playerIsWhite': playerIsWhite,
        'moveUcis': moveUcis,
        'box': box,
        'dueAt': Timestamp.fromDate(dueAt),
        'lastReviewedAt':
            lastReviewedAt != null ? Timestamp.fromDate(lastReviewedAt!) : null,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
