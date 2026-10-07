import 'package:flutter/material.dart';
import '../services/ai_opponent_engine.dart';

/// Widget for selecting AI difficulty level
class DifficultySelector extends StatefulWidget {
  const DifficultySelector({
    required this.onDifficultySelected,
    Key? key,
    this.initialDifficulty,
  }) : super(key: key);
  final Function(AIDifficulty) onDifficultySelected;
  final AIDifficulty? initialDifficulty;

  @override
  State<DifficultySelector> createState() => _DifficultySelectorState();
}

class _DifficultySelectorState extends State<DifficultySelector> {
  late AIDifficulty _selectedDifficulty;

  @override
  void initState() {
    super.initState();
    _selectedDifficulty = widget.initialDifficulty ?? AIDifficulty.medium;
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Select AI Difficulty',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            ...AIDifficulty.values.map((difficulty) => Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Card(
                    child: ListTile(
                      title: Text(difficulty.displayName),
                      subtitle: Text(difficulty.description),
                      trailing: Radio<AIDifficulty>(
                        value: difficulty,
                        groupValue: _selectedDifficulty,
                        onChanged: (value) {
                          setState(() {
                            if (value != null) {
                              _selectedDifficulty = value;
                            }
                          });
                        },
                      ),
                      onTap: () {
                        setState(() {
                          _selectedDifficulty = difficulty;
                        });
                      },
                    ),
                  ),
                )),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        widget.onDifficultySelected(_selectedDifficulty);
                        Navigator.of(context).pop();
                      },
                      child: const Text('Start Game'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}
