import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_chess/src/models/repertoire_line.dart';
import 'package:komovia_chess/src/services/repertoire_scheduler.dart';
import 'package:komovia_chess/src/services/repertoire_service.dart';

void main() {
  group('RepertoireLine Firestore round-trip', () {
    test('toFirestore/fromFirestore preserves every field', () async {
      final firestore = FakeFirebaseFirestore();
      final line = RepertoireLine(
        id: 'line1',
        uid: 'u1',
        name: 'シシリアン・ドラゴン',
        playerIsWhite: false,
        moveUcis: const ['e2e4', 'c7c5', 'g1f3', 'd7d6'],
        box: 3,
        dueAt: DateTime(2026, 2, 1),
        lastReviewedAt: DateTime(2026, 1, 25),
        createdAt: DateTime(2026, 1, 1),
      );

      await firestore
          .collection('repertoire_lines')
          .doc('u1')
          .collection('lines')
          .doc('line1')
          .set(line.toFirestore());

      final doc = await firestore
          .collection('repertoire_lines')
          .doc('u1')
          .collection('lines')
          .doc('line1')
          .get();
      final fetched = RepertoireLine.fromFirestore(doc);

      expect(fetched.id, 'line1');
      expect(fetched.uid, 'u1');
      expect(fetched.name, 'シシリアン・ドラゴン');
      expect(fetched.playerIsWhite, isFalse);
      expect(fetched.moveUcis, line.moveUcis);
      expect(fetched.box, 3);
      expect(fetched.dueAt, DateTime(2026, 2, 1));
      expect(fetched.lastReviewedAt, DateTime(2026, 1, 25));
      expect(fetched.createdAt, DateTime(2026, 1, 1));
    });

    test('a document missing lastReviewedAt falls back to null', () async {
      final firestore = FakeFirebaseFirestore();
      final line = RepertoireLine(
        id: 'line1',
        uid: 'u1',
        name: 'Queen\'s Gambit',
        playerIsWhite: true,
        moveUcis: const ['d2d4', 'd7d5'],
        box: 1,
        dueAt: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
      );
      await firestore
          .collection('repertoire_lines')
          .doc('u1')
          .collection('lines')
          .doc('line1')
          .set(line.toFirestore());

      final doc = await firestore
          .collection('repertoire_lines')
          .doc('u1')
          .collection('lines')
          .doc('line1')
          .get();
      final fetched = RepertoireLine.fromFirestore(doc);

      expect(fetched.lastReviewedAt, isNull);
    });
  });

  group('RepertoireService', () {
    test('addLine persists a new line starting in box 1, due immediately',
        () async {
      final firestore = FakeFirebaseFirestore();
      final service = RepertoireService(firestore: firestore);

      final line = await service.addLine(
        uid: 'u1',
        name: "King's Indian",
        playerIsWhite: false,
        moveUcis: const ['d2d4', 'g8f6', 'c2c4', 'g7g6'],
      );

      expect(line.box, 1);
      expect(
        RepertoireScheduler.isDue(line.dueAt, DateTime.now()),
        isTrue,
      );

      final lines = await service.getLines('u1');
      expect(lines, hasLength(1));
      expect(lines.first.name, "King's Indian");
    });

    test('getLines only returns the given uid\'s own lines', () async {
      final firestore = FakeFirebaseFirestore();
      final service = RepertoireService(firestore: firestore);
      await service.addLine(
        uid: 'u1',
        name: 'Line A',
        playerIsWhite: true,
        moveUcis: const ['e2e4'],
      );
      await service.addLine(
        uid: 'u2',
        name: 'Line B',
        playerIsWhite: true,
        moveUcis: const ['d2d4'],
      );

      final u1Lines = await service.getLines('u1');
      expect(u1Lines, hasLength(1));
      expect(u1Lines.first.name, 'Line A');
    });

    test('deleteLine removes the line', () async {
      final firestore = FakeFirebaseFirestore();
      final service = RepertoireService(firestore: firestore);
      final line = await service.addLine(
        uid: 'u1',
        name: 'Temp line',
        playerIsWhite: true,
        moveUcis: const ['e2e4'],
      );

      await service.deleteLine('u1', line.id);

      expect(await service.getLines('u1'), isEmpty);
    });

    test('getDueLines only returns lines whose dueAt has arrived', () async {
      final firestore = FakeFirebaseFirestore();
      final service = RepertoireService(firestore: firestore);
      final now = DateTime(2026, 6, 1);

      // Due now.
      await firestore
          .collection('repertoire_lines')
          .doc('u1')
          .collection('lines')
          .doc('due')
          .set(RepertoireLine(
            id: 'due',
            uid: 'u1',
            name: 'Due line',
            playerIsWhite: true,
            moveUcis: const ['e2e4'],
            box: 1,
            dueAt: now,
            createdAt: now,
          ).toFirestore());

      // Not due until well into the future.
      await firestore
          .collection('repertoire_lines')
          .doc('u1')
          .collection('lines')
          .doc('notdue')
          .set(RepertoireLine(
            id: 'notdue',
            uid: 'u1',
            name: 'Not due line',
            playerIsWhite: true,
            moveUcis: const ['d2d4'],
            box: 4,
            dueAt: now.add(const Duration(days: 7)),
            createdAt: now,
          ).toFirestore());

      final due = await service.getDueLines('u1', now: now);
      expect(due, hasLength(1));
      expect(due.first.name, 'Due line');
    });

    test(
        'recordReview with a correct answer advances the box and pushes '
        'dueAt into the future', () async {
      final firestore = FakeFirebaseFirestore();
      final service = RepertoireService(firestore: firestore);
      final line = await service.addLine(
        uid: 'u1',
        name: 'Line',
        playerIsWhite: true,
        moveUcis: const ['e2e4'],
      );

      final updated = await service.recordReview(
        uid: 'u1',
        line: line,
        correct: true,
      );

      expect(updated.box, 2);
      expect(updated.lastReviewedAt, isNotNull);
      expect(updated.dueAt.isAfter(DateTime.now()), isTrue);

      final persisted = await service.getLines('u1');
      expect(persisted.single.box, 2);
    });

    test('recordReview with a wrong answer resets the box to 1', () async {
      final firestore = FakeFirebaseFirestore();
      final service = RepertoireService(firestore: firestore);
      var line = await service.addLine(
        uid: 'u1',
        name: 'Line',
        playerIsWhite: true,
        moveUcis: const ['e2e4'],
      );

      // Climb a couple of boxes first.
      line = await service.recordReview(uid: 'u1', line: line, correct: true);
      line = await service.recordReview(uid: 'u1', line: line, correct: true);
      expect(line.box, 3);

      final afterWrong = await service.recordReview(
        uid: 'u1',
        line: line,
        correct: false,
      );

      expect(afterWrong.box, 1);
    });
  });
}
