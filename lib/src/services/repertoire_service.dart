import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/repertoire_line.dart';
import 'repertoire_scheduler.dart';

/// Firestore CRUD for opening repertoire lines, plus the one write that
/// actually applies spaced-repetition scheduling (`recordReview`) - the
/// scheduling math itself lives in `RepertoireScheduler`, kept pure and
/// Firestore-free, same split `ActiveCpuGameService`/`ActiveCpuGame`
/// keep between storage and the plain data class.
class RepertoireService {
  RepertoireService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _lines(String uid) =>
      _firestore.collection('repertoire_lines').doc(uid).collection('lines');

  /// Adds a new line, starting in box 1 and due immediately (see
  /// `RepertoireLine`'s doc comment for why).
  Future<RepertoireLine> addLine({
    required String uid,
    required String name,
    required bool playerIsWhite,
    required List<String> moveUcis,
  }) async {
    final now = DateTime.now();
    final doc = _lines(uid).doc();
    final line = RepertoireLine(
      id: doc.id,
      uid: uid,
      name: name,
      playerIsWhite: playerIsWhite,
      moveUcis: moveUcis,
      box: 1,
      dueAt: now,
      createdAt: now,
    );
    await doc.set(line.toFirestore());
    return line;
  }

  Future<List<RepertoireLine>> getLines(String uid) async {
    final snapshot = await _lines(uid).get();
    return snapshot.docs.map(RepertoireLine.fromFirestore).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  /// Every line of [uid]'s whose `dueAt` is now or in the past, sorted
  /// soonest-due first - the set a review session should quiz.
  Future<List<RepertoireLine>> getDueLines(
    String uid, {
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();
    final lines = await getLines(uid);
    final due = lines.where((l) => RepertoireScheduler.isDue(l.dueAt, at)).toList()
      ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
    return due;
  }

  Future<void> deleteLine(String uid, String lineId) =>
      _lines(uid).doc(lineId).delete();

  /// Applies one review outcome to [lineId]: advances (or resets) its
  /// Leitner box via `RepertoireScheduler` and persists the new
  /// box/dueAt/lastReviewedAt. Returns the updated line.
  Future<RepertoireLine> recordReview({
    required String uid,
    required RepertoireLine line,
    required bool correct,
  }) async {
    final now = DateTime.now();
    final result = RepertoireScheduler.review(
      line.box,
      correct: correct,
      reviewedAt: now,
    );
    final updated = line.copyWith(
      box: result.box,
      dueAt: result.dueAt,
      lastReviewedAt: now,
    );
    await _lines(uid).doc(line.id).set(updated.toFirestore());
    return updated;
  }
}
