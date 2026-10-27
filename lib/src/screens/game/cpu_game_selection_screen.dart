import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/cpu_starting_positions.dart';
import '../../models/active_cpu_game.dart';
import '../../providers/active_cpu_game_provider.dart';
import '../../providers/adaptive_difficulty_provider.dart';
import '../../services/adaptive_difficulty_service.dart';
import '../../services/ai_opponent_engine.dart';
import '../../utils/animations.dart';
import 'cpu_game_screen.dart';

class CPUGameSelectionScreen extends ConsumerStatefulWidget {
  const CPUGameSelectionScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<CPUGameSelectionScreen> createState() =>
      _CPUGameSelectionScreenState();
}

class _CPUGameSelectionScreenState
    extends ConsumerState<CPUGameSelectionScreen> {
  late AIDifficulty _selectedDifficulty;
  bool _playerIsWhite = true;
  CpuStartingPosition _selectedStartingPosition = CpuStartingPosition.opening;

  /// Guards against re-applying the recommendation after the player has
  /// already made their own choice (e.g. the provider resolves a moment
  /// after they've already tapped a different difficulty card).
  bool _appliedRecommendation = false;

  @override
  void initState() {
    super.initState();
    _selectedDifficulty = AIDifficulty.medium;
  }

  @override
  Widget build(BuildContext context) {
    final recommendationAsync = ref.watch(difficultyRecommendationProvider);
    recommendationAsync.whenData((recommendation) {
      if (_appliedRecommendation || recommendation == null) return;
      if (recommendation.reason == 'default') return;
      _appliedRecommendation = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedDifficulty = recommendation.difficulty);
      });
    });

    final activeGameAsync = ref.watch(activeCpuGameProvider);

    return Scaffold(
        appBar: AppBar(
          title: const Text('Play vs Computer'),
          centerTitle: true,
          elevation: 0,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 中断・再開機能: 進行中の対局があれば一番上に「続きから」
                  // を出す（無ければ何も表示しない）。
                  if (activeGameAsync.valueOrNull != null) ...[
                    _buildResumeCard(activeGameAsync.valueOrNull!),
                    const SizedBox(height: 32),
                  ],

                  // Difficulty section
                  Text(
                    'Select Difficulty',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  _buildRecommendationHint(recommendationAsync.value),
                  const SizedBox(height: 16),
                  _buildDifficultyOptions(),
                  const SizedBox(height: 32),

                  // Player color section
                  Text(
                    'Select Your Color',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  _buildColorOptions(),
                  const SizedBox(height: 32),

                  // Starting position section
                  Text(
                    'Starting Position',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  // Previously this whole feature's only explanation was
                  // the short card labels themselves ("中盤から"/
                  // "終盤から") - easy to miss as anything more than a
                  // cosmetic toggle.
                  Text(
                    'Practice from a specific position instead of always '
                    'starting from scratch.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
                  const SizedBox(height: 16),
                  _buildStartingPositionOptions(),
                  const SizedBox(height: 8),
                  Text(
                    _selectedStartingPosition.description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
                  const SizedBox(height: 40),

                  // Start button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _startGame,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        minimumSize: const Size(double.infinity, 48),
                      ),
                      child: const Text(
                        'Start Game',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
  }

  Widget _buildRecommendationHint(DifficultyRecommendation? recommendation) {
    if (recommendation == null || recommendation.reason == 'default') {
      return const SizedBox.shrink();
    }
    final percent = (recommendation.recentWinRate * 100).toStringAsFixed(0);
    final message = switch (recommendation.reason) {
      'strong' => '直近${recommendation.gamesConsidered}局で勝率$percent% - '
          '${recommendation.difficulty.displayName}をおすすめします',
      'struggling' => '直近${recommendation.gamesConsidered}局で勝率$percent% - '
          '${recommendation.difficulty.displayName}をおすすめします',
      _ => '直近${recommendation.gamesConsidered}局の実績から'
          '${recommendation.difficulty.displayName}が選択されています',
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.deepOrange.shade700,
            ),
      ),
    );
  }

  Widget _buildDifficultyOptions() => Column(
        children: [
          ...AIDifficulty.values.asMap().entries.map((entry) {
            final index = entry.key;
            final difficulty = entry.value;
            return SlideInAnimation(
              direction: SlideDirection.left,
              delay: Duration(milliseconds: index * 100),
              child: Column(
                children: [
                  _buildDifficultyCard(
                    difficulty: difficulty,
                  ),
                  if (index < AIDifficulty.values.length - 1)
                    const SizedBox(height: 12),
                ],
              ),
            );
          }),
        ],
      );

  Widget _buildDifficultyCard({
    required AIDifficulty difficulty,
  }) {
    final isSelected = _selectedDifficulty == difficulty;
    final Icon icon = switch (difficulty) {
      AIDifficulty.beginner => const Icon(Icons.sentiment_satisfied_alt),
      AIDifficulty.easy => const Icon(Icons.psychology_alt),
      AIDifficulty.medium => const Icon(Icons.trending_up),
      AIDifficulty.hard => const Icon(Icons.star),
      AIDifficulty.master => const Icon(Icons.military_tech),
    };

    return GestureDetector(
      onTap: () => setState(() => _selectedDifficulty = difficulty),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color:
              isSelected ? Colors.blue.withOpacity(0.05) : Colors.transparent,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: icon,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    difficulty.displayName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    difficulty.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 16,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorOptions() => Row(
        children: [
          Expanded(
            child: _buildColorCard(
              color: 'White',
              isSelected: _playerIsWhite,
              onTap: () => setState(() => _playerIsWhite = true),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildColorCard(
              color: 'Black',
              isSelected: !_playerIsWhite,
              onTap: () => setState(() => _playerIsWhite = false),
            ),
          ),
        ],
      );

  Widget _buildColorCard({
    required String color,
    required bool isSelected,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? Colors.blue : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
            color:
                isSelected ? Colors.blue.withOpacity(0.05) : Colors.transparent,
          ),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: color == 'White'
                      ? Colors.grey.shade300
                      : Colors.grey.shade800,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.grey.shade600,
                    width: 2,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                color,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              if (isSelected)
                const Text(
                  '✓ Selected',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ),
      );

  Widget _buildStartingPositionOptions() => Row(
        children: CpuStartingPosition.values
            .map(
              (position) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: position != CpuStartingPosition.values.last ? 8 : 0,
                  ),
                  child: _buildStartingPositionCard(position),
                ),
              ),
            )
            .toList(),
      );

  Widget _buildStartingPositionCard(CpuStartingPosition position) {
    final isSelected = _selectedStartingPosition == position;
    return GestureDetector(
      onTap: () => setState(() => _selectedStartingPosition = position),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color:
              isSelected ? Colors.blue.withOpacity(0.05) : Colors.transparent,
        ),
        child: Center(
          child: Text(
            position.displayName,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  void _startGame() {
    Navigator.of(context).push(
      SmoothPageTransition(
        page: CPUGameScreen(
          difficulty: _selectedDifficulty,
          playerIsWhite: _playerIsWhite,
          startingFen: _selectedStartingPosition.fen,
        ),
      ),
    );
  }

  Widget _buildResumeCard(ActiveCpuGame activeGame) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: ListTile(
        leading: const Icon(Icons.play_circle_outline),
        title: const Text('続きから (Resume game)'),
        subtitle: Text(
          '${activeGame.playerIsWhite ? "White" : "Black"} · '
          '${activeGame.difficultyName}',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          SmoothPageTransition(
            page: CPUGameScreen(resumeGame: activeGame),
          ),
        ),
      ),
    );
  }
}
