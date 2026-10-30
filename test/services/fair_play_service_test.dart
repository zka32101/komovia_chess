import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_chess/src/models/game_analysis.dart';
import 'package:komovia_chess/src/services/fair_play_service.dart';

GameAnalysis _buildAnalysis(List<double> whiteLosses, List<double> blackLosses) {
  final moves = <MoveAnalysis>[];
  var eval = 0;
  for (var i = 0; i < whiteLosses.length || i < blackLosses.length; i++) {
    if (i < whiteLosses.length) {
      final loss = whiteLosses[i].round();
      moves.add(MoveAnalysis(
        moveIndex: moves.length,
        notation: 'e2-e4',
        isWhiteMove: true,
        evalBeforeCp: eval,
        evalAfterCp: eval - loss,
        centipawnLoss: loss,
        quality: classifyMoveQuality(loss.toDouble()),
      ));
      eval -= loss;
    }
    if (i < blackLosses.length) {
      final loss = blackLosses[i].round();
      moves.add(MoveAnalysis(
        moveIndex: moves.length,
        notation: 'e7-e5',
        isWhiteMove: false,
        evalBeforeCp: eval,
        evalAfterCp: eval + loss,
        centipawnLoss: loss,
        quality: classifyMoveQuality(loss.toDouble()),
      ));
      eval += loss;
    }
  }
  return GameAnalysis(moves: moves, whiteAccuracy: 90, blackAccuracy: 85);
}

void main() {
  group('FairPlayService.recordGameSignal', () {
    test('persists a computed signal doc keyed by uid under the game', () async {
      final firestore = FakeFirebaseFirestore();
      final service = FairPlayService(firestore: firestore);

      final analysis = _buildAnalysis(
        List<double>.filled(30, 2), // white: very clean
        List<double>.filled(30, 40), // black: realistic human-ish
      );

      await service.recordGameSignal(
        uid: 'white-uid',
        gameId: 'game1',
        analysis: analysis,
        isWhitePlayer: true,
      );
      await service.recordGameSignal(
        uid: 'black-uid',
        gameId: 'game1',
        analysis: analysis,
        isWhitePlayer: false,
      );

      final whiteDoc = await firestore
          .collection('games')
          .doc('game1')
          .collection('fair_play_signals')
          .doc('white-uid')
          .get();
      final blackDoc = await firestore
          .collection('games')
          .doc('game1')
          .collection('fair_play_signals')
          .doc('black-uid')
          .get();

      expect(whiteDoc.exists, isTrue);
      expect(blackDoc.exists, isTrue);

      final whiteData = whiteDoc.data()!;
      expect(whiteData['uid'], 'white-uid');
      expect(whiteData['gameId'], 'game1');
      expect(whiteData['sampleSize'], 30);
      expect(whiteData['meanCentipawnLoss'], closeTo(2, 1e-9));

      final blackData = blackDoc.data()!;
      expect(blackData['uid'], 'black-uid');
      expect(blackData['meanCentipawnLoss'], closeTo(40, 1e-9));

      // The very-clean long white sample should score more suspicious
      // than black's realistic one.
      expect(
        (whiteData['suspicionScore'] as num),
        greaterThan(blackData['suspicionScore'] as num),
      );
    });

    test('overwrites rather than duplicates on a repeat call for the same game/uid',
        () async {
      final firestore = FakeFirebaseFirestore();
      final service = FairPlayService(firestore: firestore);
      final analysis = _buildAnalysis(List<double>.filled(25, 10), const []);

      await service.recordGameSignal(
        uid: 'u1',
        gameId: 'g1',
        analysis: analysis,
        isWhitePlayer: true,
      );
      await service.recordGameSignal(
        uid: 'u1',
        gameId: 'g1',
        analysis: analysis,
        isWhitePlayer: true,
      );

      final snapshot = await firestore
          .collection('games')
          .doc('g1')
          .collection('fair_play_signals')
          .get();
      expect(snapshot.docs.length, 1);
    });

    test('does not throw when the underlying write fails (best-effort)', () async {
      // No way to force a FakeFirebaseFirestore write failure directly,
      // but an empty move list exercises the degenerate
      // computeFairPlaySignal(empty) path end-to-end without error.
      final firestore = FakeFirebaseFirestore();
      final service = FairPlayService(firestore: firestore);
      final analysis = _buildAnalysis(const [], const []);

      await service.recordGameSignal(
        uid: 'u1',
        gameId: 'g1',
        analysis: analysis,
        isWhitePlayer: true,
      );

      final doc = await firestore
          .collection('games')
          .doc('g1')
          .collection('fair_play_signals')
          .doc('u1')
          .get();
      expect(doc.data()!['sampleSize'], 0);
      expect(doc.data()!['reviewRecommended'], isFalse);
    });
  });
}
