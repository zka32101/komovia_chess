import 'package:flutter/material.dart';
import '../../services/ai_opponent_engine.dart';
import '../../utils/animations.dart';
import 'cpu_game_screen.dart';

class CPUGameSelectionScreen extends StatefulWidget {
  const CPUGameSelectionScreen({Key? key}) : super(key: key);

  @override
  State<CPUGameSelectionScreen> createState() => _CPUGameSelectionScreenState();
}

class _CPUGameSelectionScreenState extends State<CPUGameSelectionScreen> {
  late AIDifficulty _selectedDifficulty;
  bool _playerIsWhite = true;

  @override
  void initState() {
    super.initState();
    _selectedDifficulty = AIDifficulty.medium;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
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
                  // Difficulty section
                  Text(
                    'Select Difficulty',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
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
                  const SizedBox(height: 48),

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
    final Icon icon = difficulty == AIDifficulty.easy
        ? const Icon(Icons.psychology_alt)
        : difficulty == AIDifficulty.medium
            ? const Icon(Icons.trending_up)
            : const Icon(Icons.star);

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

  void _startGame() {
    Navigator.of(context).push(
      SmoothPageTransition(
        page: CPUGameScreen(
          difficulty: _selectedDifficulty,
          playerIsWhite: _playerIsWhite,
        ),
      ),
    );
  }
}
