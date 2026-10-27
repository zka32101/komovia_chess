import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_chess/src/models/active_cpu_game.dart';
import 'package:komovia_chess/src/services/active_cpu_game_service.dart';

void main() {
  group('ActiveCpuGameService', () {
    test('save then getActive round-trips the same fields', () async {
      final firestore = FakeFirebaseFirestore();
      final service = ActiveCpuGameService(firestore: firestore);
      final game = ActiveCpuGame(
        uid: 'u1',
        moveUcis: const ['e2e4', 'e7e5', 'g1f3'],
        difficultyName: 'hard',
        playerIsWhite: false,
        startTime: DateTime(2026, 1, 1),
      );

      await service.save(game);
      final fetched = await service.getActive('u1');

      expect(fetched, isNotNull);
      expect(fetched!.uid, 'u1');
      expect(fetched.moveUcis, game.moveUcis);
      expect(fetched.difficultyName, 'hard');
      expect(fetched.playerIsWhite, isFalse);
      expect(fetched.startingFen, isNull);
    });

    test('getActive returns null when nothing is saved', () async {
      final firestore = FakeFirebaseFirestore();
      final service = ActiveCpuGameService(firestore: firestore);

      expect(await service.getActive('nobody'), isNull);
    });

    test('clear removes the saved game', () async {
      final firestore = FakeFirebaseFirestore();
      final service = ActiveCpuGameService(firestore: firestore);
      await service.save(
        ActiveCpuGame(
          uid: 'u1',
          moveUcis: const ['e2e4'],
          difficultyName: 'easy',
          playerIsWhite: true,
          startTime: DateTime.now(),
        ),
      );

      await service.clear('u1');

      expect(await service.getActive('u1'), isNull);
    });

    test('saving again for the same uid overwrites rather than duplicating',
        () async {
      final firestore = FakeFirebaseFirestore();
      final service = ActiveCpuGameService(firestore: firestore);
      await service.save(
        ActiveCpuGame(
          uid: 'u1',
          moveUcis: const ['e2e4'],
          difficultyName: 'easy',
          playerIsWhite: true,
          startTime: DateTime.now(),
        ),
      );
      await service.save(
        ActiveCpuGame(
          uid: 'u1',
          moveUcis: const ['e2e4', 'e7e5'],
          difficultyName: 'hard',
          playerIsWhite: false,
          startTime: DateTime.now(),
        ),
      );

      final fetched = await service.getActive('u1');
      expect(fetched!.moveUcis, ['e2e4', 'e7e5']);
      expect(fetched.difficultyName, 'hard');
    });

    test('a promotion move round-trips with its promotion-piece suffix',
        () async {
      final firestore = FakeFirebaseFirestore();
      final service = ActiveCpuGameService(firestore: firestore);
      await service.save(
        ActiveCpuGame(
          uid: 'u1',
          moveUcis: const ['e7e8q'],
          difficultyName: 'medium',
          playerIsWhite: true,
          startTime: DateTime.now(),
        ),
      );

      final fetched = await service.getActive('u1');
      expect(fetched!.moveUcis, ['e7e8q']);
    });

    test('a custom starting position (practice FEN) round-trips too',
        () async {
      final firestore = FakeFirebaseFirestore();
      final service = ActiveCpuGameService(firestore: firestore);
      const startingFen = '8/8/8/4k3/8/4K3/8/8 w - - 0 1';
      await service.save(
        ActiveCpuGame(
          uid: 'u1',
          moveUcis: const [],
          difficultyName: 'medium',
          playerIsWhite: true,
          startingFen: startingFen,
          startTime: DateTime.now(),
        ),
      );

      final fetched = await service.getActive('u1');
      expect(fetched!.startingFen, startingFen);
    });
  });

  group('ActiveCpuGame.fromFirestore', () {
    test('falls back to defaults for a document missing newer fields',
        () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('active_cpu_games').doc('u1').set({});
      final doc =
          await firestore.collection('active_cpu_games').doc('u1').get();

      final game = ActiveCpuGame.fromFirestore(doc);

      expect(game.uid, 'u1');
      expect(game.moveUcis, isEmpty);
      expect(game.difficultyName, 'medium');
      expect(game.playerIsWhite, isTrue);
      expect(game.startingFen, isNull);
    });
  });
}
