import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_chess/src/models/active_cpu_game.dart';
import 'package:komovia_chess/src/providers/cpu_game_provider.dart';
import 'package:komovia_chess/src/services/ai_opponent_engine.dart';

void main() {
  group('CpuGameNotifier.resumeFrom', () {
    test('restores the saved FEN, difficulty, and player color', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(cpuGameProvider.notifier);

      // A position after 1.e4 e5 2.Nf3, black to move.
      const savedFen =
          'rnbqkbnr/pppp1ppp/8/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq - 1 2';

      notifier.resumeFrom(
        ActiveCpuGame(
          uid: 'u1',
          fen: savedFen,
          difficultyName: 'hard',
          playerIsWhite: false,
          startTime: DateTime(2026, 1, 1),
        ),
      );

      final state = container.read(cpuGameProvider);
      expect(state.gameState.fen, savedFen);
      expect(state.difficulty, AIDifficulty.hard);
      expect(state.playerIsWhite, isFalse);
      expect(state.moves, isEmpty);
      expect(state.isGameOver, isFalse);
      expect(state.startingFen, isNull);
    });

    test('restores a custom starting position (practice FEN) correctly',
        () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(cpuGameProvider.notifier);
      const startingFen = '8/8/8/4k3/8/4K3/8/8 w - - 0 1';

      notifier.resumeFrom(
        ActiveCpuGame(
          uid: 'u1',
          fen: startingFen,
          difficultyName: 'medium',
          playerIsWhite: true,
          startingFen: startingFen,
          startTime: DateTime(2026, 1, 1),
        ),
      );

      final state = container.read(cpuGameProvider);
      expect(state.gameState.fen, startingFen);
      expect(state.startingFen, startingFen);
    });

    test('an unrecognized difficulty name falls back to medium', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(cpuGameProvider.notifier);

      notifier.resumeFrom(
        ActiveCpuGame(
          uid: 'u1',
          fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
          difficultyName: 'not-a-real-difficulty',
          playerIsWhite: true,
          startTime: DateTime(2026, 1, 1),
        ),
      );

      expect(container.read(cpuGameProvider).difficulty, AIDifficulty.medium);
    });

    test('preserves the original startTime for game-duration display', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(cpuGameProvider.notifier);
      final originalStart = DateTime(2025, 6, 1, 10, 30);

      notifier.resumeFrom(
        ActiveCpuGame(
          uid: 'u1',
          fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
          difficultyName: 'easy',
          playerIsWhite: true,
          startTime: originalStart,
        ),
      );

      expect(container.read(cpuGameProvider).startTime, originalStart);
    });
  });
}
