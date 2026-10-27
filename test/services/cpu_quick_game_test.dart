import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_chess/src/models/active_cpu_game.dart';
import 'package:komovia_chess/src/services/active_cpu_game_service.dart';
import 'package:komovia_chess/src/services/ai_opponent_engine.dart';
import 'package:komovia_chess/src/services/stockfish_engine_service.dart';

void main() {
  group('AIDifficultyStockfishExt.quickMoveTimeMs', () {
    test('is always shorter than the normal stockfishMoveTimeMs', () {
      for (final difficulty in AIDifficulty.values) {
        expect(
          difficulty.quickMoveTimeMs,
          lessThan(difficulty.stockfishMoveTimeMs),
        );
      }
    });

    test('a stronger difficulty still gets a longer quick-game time budget',
        () {
      expect(
        AIDifficulty.master.quickMoveTimeMs,
        greaterThan(AIDifficulty.hard.quickMoveTimeMs),
      );
      expect(
        AIDifficulty.hard.quickMoveTimeMs,
        greaterThan(AIDifficulty.medium.quickMoveTimeMs),
      );
      expect(
        AIDifficulty.medium.quickMoveTimeMs,
        greaterThan(AIDifficulty.easy.quickMoveTimeMs),
      );
      expect(
        AIDifficulty.easy.quickMoveTimeMs,
        greaterThan(AIDifficulty.beginner.quickMoveTimeMs),
      );
    });
  });

  group('ActiveCpuGame.quickGame', () {
    test('defaults to false and round-trips through Firestore', () async {
      final firestore = FakeFirebaseFirestore();
      final service = ActiveCpuGameService(firestore: firestore);

      await service.save(
        ActiveCpuGame(
          uid: 'u1',
          moveUcis: const [],
          difficultyName: 'medium',
          playerIsWhite: true,
          startTime: DateTime.now(),
        ),
      );
      expect((await service.getActive('u1'))!.quickGame, isFalse);

      await service.save(
        ActiveCpuGame(
          uid: 'u1',
          moveUcis: const [],
          difficultyName: 'medium',
          playerIsWhite: true,
          startTime: DateTime.now(),
          quickGame: true,
        ),
      );
      expect((await service.getActive('u1'))!.quickGame, isTrue);
    });

    test('falls back to false for a document missing the field', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('active_cpu_games').doc('u1').set({});
      final doc =
          await firestore.collection('active_cpu_games').doc('u1').get();

      expect(ActiveCpuGame.fromFirestore(doc).quickGame, isFalse);
    });
  });
}
