import 'package:flutter/material.dart';
import '../../models/lesson.dart';

String difficultyLabel(DifficultyLevel level) {
  switch (level) {
    case DifficultyLevel.beginner:
      return '初級';
    case DifficultyLevel.intermediate:
      return '中級';
    case DifficultyLevel.advanced:
      return '上級';
    case DifficultyLevel.expert:
      return 'エキスパート';
  }
}

Color difficultyColor(DifficultyLevel level) {
  switch (level) {
    case DifficultyLevel.beginner:
      return Colors.green;
    case DifficultyLevel.intermediate:
      return Colors.blue;
    case DifficultyLevel.advanced:
      return Colors.orange;
    case DifficultyLevel.expert:
      return Colors.red;
  }
}

/// Small colored chip showing a lesson/pattern's difficulty level.
class DifficultyBadge extends StatelessWidget {
  const DifficultyBadge({required this.difficulty, Key? key}) : super(key: key);
  final DifficultyLevel difficulty;

  @override
  Widget build(BuildContext context) {
    final color = difficultyColor(difficulty);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        difficultyLabel(difficulty),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
