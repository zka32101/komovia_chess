import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_chess/src/models/active_cpu_game.dart';
import 'package:komovia_chess/src/providers/cpu_game_provider.dart';
import 'package:komovia_chess/src/services/ai_opponent_engine.dart';

void main() {
  group('CpuGameNotifier.resumeFrom', () {
    test(
        'replays the saved move list from the start, restoring the '
        'position, difficulty, and player color', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(cpuGameProvider.notifier);

      // 1.e4 e5 2.Nf3, black to move.
      notifier.resumeFrom(
        ActiveCpuGame(
          uid: 'u1',
          moveUcis: const ['e2e4', 'e7e5', 'g1f3'],
          difficultyName: 'hard',
          playerIsWhite: false,
          startTime: DateTime(2026, 1, 1),
        ),
      );

      final state = container.read(cpuGameProvider);
      expect(
        state.gameState.fen,
        'rnbqkbnr/pppp1ppp/8/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq - 1 2',
      );
      expect(state.difficulty, AIDifficulty.hard);
      expect(state.playerIsWhite, isFalse);
      expect(state.isGameOver, isFalse);
      expect(state.startingFen, isNull);
    });

    test('a resumed game keeps enough move history for undo to work', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(cpuGameProvider.notifier);

      notifier.resumeFrom(
        ActiveCpuGame(
          uid: 'u1',
          moveUcis: const ['e2e4', 'e7e5'],
          difficultyName: 'medium',
          playerIsWhite: true,
          startTime: DateTime(2026, 1, 1),
        ),
      );

      expect(container.read(cpuGameProvider).moves, hasLength(2));

      notifier.undoMove();

      final afterUndo = container.read(cpuGameProvider);
      expect(afterUndo.moves, isEmpty);
      expect(
        afterUndo.gameState.fen,
        'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
      );
    });

    test('an empty move list (just-started, no moves yet) restores the '
        'initial position', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(cpuGameProvider.notifier);

      notifier.resumeFrom(
        ActiveCpuGame(
          uid: 'u1',
          moveUcis: const [],
          difficultyName: 'easy',
          playerIsWhite: true,
          startTime: DateTime(2026, 1, 1),
        ),
      );

      final state = container.read(cpuGameProvider);
      expect(
        state.gameState.fen,
        'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
      );
      expect(state.moves, isEmpty);
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
          moveUcis: const [],
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
          moveUcis: const [],
          difficultyName: 'not-a-real-difficulty',
          playerIsWhite: true,
          startTime: DateTime(2026, 1, 1),
        ),
      );

      expect(container.read(cpuGameProvider).difficulty, AIDifficulty.medium);
    });

    test('counts only the time actually played, not the time spent away', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(cpuGameProvider.notifier);

      notifier.resumeFrom(
        ActiveCpuGame(
          uid: 'u1',
          moveUcis: const [],
          difficultyName: 'easy',
          playerIsWhite: true,
          // 何時間も前に始めた対局でも、実際に打った時間は5分。
          startTime: DateTime(2025, 6, 1, 10, 30),
          elapsedMs: const Duration(minutes: 5).inMilliseconds,
        ),
      );

      final duration = container.read(cpuGameProvider).gameDuration;
      expect(duration, greaterThanOrEqualTo(const Duration(minutes: 5)));
      expect(duration, lessThan(const Duration(minutes: 6)));
    });

    test('a malformed move string is skipped rather than throwing', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(cpuGameProvider.notifier);

      expect(
        () => notifier.resumeFrom(
          ActiveCpuGame(
            uid: 'u1',
            moveUcis: const ['e2e4', 'x', 'e7e5'],
            difficultyName: 'medium',
            playerIsWhite: true,
            startTime: DateTime(2026, 1, 1),
          ),
        ),
        returnsNormally,
      );
    });

    test('restores a saved quickGame flag', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(cpuGameProvider.notifier);

      expect(notifier.isQuickGame, isFalse);

      notifier.resumeFrom(
        ActiveCpuGame(
          uid: 'u1',
          moveUcis: const [],
          difficultyName: 'medium',
          playerIsWhite: true,
          startTime: DateTime(2026, 1, 1),
          quickGame: true,
        ),
      );

      expect(notifier.isQuickGame, isTrue);
    });
  });

  group('CpuGameNotifier.resumeFrom on a finished game', () {
    test('shows the final result without resuming play', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(cpuGameProvider.notifier);

      // Fool's mate: 1.f3 e5 2.g4 Qh4#, white (the player) is mated.
      notifier.resumeFrom(
        ActiveCpuGame(
          uid: 'u1',
          moveUcis: const ['f2f3', 'e7e5', 'g2g4', 'd8h4'],
          difficultyName: 'medium',
          playerIsWhite: true,
          startTime: DateTime(2026, 1, 1),
        ),
      );

      final state = container.read(cpuGameProvider);
      expect(state.isGameOver, isTrue);
      expect(state.result, 'black_win');
      expect(state.endReason, 'checkmate');
    });
  });

  group('CpuGameNotifier.initGame', () {
    test('quickGame defaults to false and is settable', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(cpuGameProvider.notifier);

      notifier.initGame();
      expect(notifier.isQuickGame, isFalse);

      notifier.initGame(quickGame: true);
      expect(notifier.isQuickGame, isTrue);
    });
  });
}
