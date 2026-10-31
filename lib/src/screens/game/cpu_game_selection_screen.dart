import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
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
  bool _quickGame = false;
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
    final l10n = AppLocalizations.of(context);

    return Scaffold(
        appBar: AppBar(
          title: Text(l10n.cpuSelectTitle),
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
                    l10n.cpuSelectDifficulty,
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
                    l10n.cpuSelectColor,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  _buildColorOptions(),
                  const SizedBox(height: 32),

                  // Starting position section
                  Text(
                    l10n.cpuSelectStartPos,
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
                    l10n.cpuStartPosHint,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
                  const SizedBox(height: 16),
                  _buildStartingPositionOptions(),
                  const SizedBox(height: 8),
                  Text(
                    _startPositionDescription(l10n, _selectedStartingPosition),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
                  const SizedBox(height: 16),

                  // クイック対局（持ち時間短縮）
                  CheckboxListTile(
                    value: _quickGame,
                    onChanged: (value) =>
                        setState(() => _quickGame = value ?? false),
                    title: Text(l10n.cpuQuickGame),
                    subtitle: Text(l10n.cpuQuickGameDesc),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 24),

                  // Start button - made more prominent (larger, bolder,
                  // with an icon and a subtle elevation) so it reads
                  // clearly as the primary action on this screen rather
                  // than blending in with the option cards above it.
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _startGame,
                      icon: const Icon(Icons.play_arrow, size: 26),
                      label: Text(
                        l10n.cpuStartGame,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        minimumSize: const Size(double.infinity, 60),
                        elevation: 3,
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
    final l10n = AppLocalizations.of(context);
    final percent = (recommendation.recentWinRate * 100).toStringAsFixed(0);
    final difficulty = difficultyName(l10n, recommendation.difficulty);
    final message = switch (recommendation.reason) {
      'strong' || 'struggling' => l10n.cpuHintRecommend(
          percent, recommendation.gamesConsidered, difficulty),
      _ => l10n.cpuHintSelected(recommendation.gamesConsidered, difficulty),
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
                    difficultyName(AppLocalizations.of(context), difficulty),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    difficultyDescription(
                        AppLocalizations.of(context), difficulty),
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

  Widget _buildColorOptions() {
    final l10n = AppLocalizations.of(context);
    return Row(
        children: [
          Expanded(
            child: _buildColorCard(
              isWhite: true,
              label: l10n.cpuColorWhite,
              isSelected: _playerIsWhite,
              onTap: () => setState(() => _playerIsWhite = true),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildColorCard(
              isWhite: false,
              label: l10n.cpuColorBlack,
              isSelected: !_playerIsWhite,
              onTap: () => setState(() => _playerIsWhite = false),
            ),
          ),
        ],
    );
  }

  Widget _buildColorCard({
    required bool isWhite,
    required String label,
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
                  color: isWhite
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
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              if (isSelected)
                Text(
                  AppLocalizations.of(context).cpuSelected,
                  style: const TextStyle(
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
            _startPositionName(AppLocalizations.of(context), position),
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
          quickGame: _quickGame,
        ),
      ),
    );
  }

  Widget _buildResumeCard(ActiveCpuGame activeGame) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: ListTile(
        leading: const Icon(Icons.play_circle_outline),
        title: Text(AppLocalizations.of(context).cpuResume),
        subtitle: Text(
          _resumeSubtitle(AppLocalizations.of(context), activeGame),
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

/// Localized name of an AI strength level (shared with the in-game screen).
String difficultyName(AppLocalizations l10n, AIDifficulty difficulty) =>
    switch (difficulty) {
      AIDifficulty.beginner => l10n.cpuDiffBeginner,
      AIDifficulty.easy => l10n.cpuDiffEasy,
      AIDifficulty.medium => l10n.cpuDiffMedium,
      AIDifficulty.hard => l10n.cpuDiffHard,
      AIDifficulty.master => l10n.cpuDiffMaster,
    };

String difficultyDescription(AppLocalizations l10n, AIDifficulty difficulty) =>
    switch (difficulty) {
      AIDifficulty.beginner => l10n.cpuDiffBeginnerDesc,
      AIDifficulty.easy => l10n.cpuDiffEasyDesc,
      AIDifficulty.medium => l10n.cpuDiffMediumDesc,
      AIDifficulty.hard => l10n.cpuDiffHardDesc,
      AIDifficulty.master => l10n.cpuDiffMasterDesc,
    };

String _startPositionName(AppLocalizations l10n, CpuStartingPosition p) =>
    switch (p) {
      CpuStartingPosition.opening => l10n.cpuStartOpening,
      CpuStartingPosition.midgame => l10n.cpuStartMidgame,
      CpuStartingPosition.endgame => l10n.cpuStartEndgame,
    };

String _startPositionDescription(AppLocalizations l10n, CpuStartingPosition p) =>
    switch (p) {
      CpuStartingPosition.opening => l10n.cpuStartOpeningDesc,
      CpuStartingPosition.midgame => l10n.cpuStartMidgameDesc,
      CpuStartingPosition.endgame => l10n.cpuStartEndgameDesc,
    };

/// The saved game stores the difficulty by enum name ("medium").
String _resumeSubtitle(AppLocalizations l10n, ActiveCpuGame game) {
  final difficulty = AIDifficulty.values.firstWhere(
    (d) => d.name == game.difficultyName,
    orElse: () => AIDifficulty.medium,
  );
  return l10n.cpuResumeSubtitle(
    game.playerIsWhite ? l10n.cpuColorWhite : l10n.cpuColorBlack,
    difficultyName(l10n, difficulty),
  );
}
