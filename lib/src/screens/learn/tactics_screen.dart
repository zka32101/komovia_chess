import 'package:flutter/material.dart';
import '../../data/chess_curriculum_data.dart';
import '../../models/lesson.dart';
import '../../widgets/learn/difficulty_badge.dart';

/// Lists the built-in tactical motifs (fork, pin, skewer, ...) backed by
/// [TacticsPattern].
class TacticsScreen extends StatelessWidget {
  const TacticsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final patterns = ChessCurriculumData.tacticsPatterns;

    return Scaffold(
      appBar: AppBar(title: const Text('戦術パターン')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: patterns.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final pattern = patterns[index];
          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(12),
              leading: const Icon(Icons.bolt_outlined, size: 32),
              title: Text(
                pattern.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(pattern.description),
              ),
              trailing: DifficultyBadge(difficulty: pattern.difficulty),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TacticsDetailScreen(pattern: pattern),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class TacticsDetailScreen extends StatelessWidget {
  const TacticsDetailScreen({required this.pattern, Key? key})
      : super(key: key);
  final TacticsPattern pattern;

  Widget _numberedSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<String> items,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final entry in items.asMap().entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 11,
                    child: Text(
                      '${entry.key + 1}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(entry.value)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(pattern.name)),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      pattern.description,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                  const SizedBox(width: 12),
                  DifficultyBadge(difficulty: pattern.difficulty),
                ],
              ),
              const SizedBox(height: 24),
              _numberedSection(
                context,
                title: '見分け方',
                icon: Icons.visibility_outlined,
                items: pattern.recognitionFeatures,
              ),
              _numberedSection(
                context,
                title: '実戦での手順',
                icon: Icons.format_list_numbered,
                items: pattern.executionSteps,
              ),
              if (pattern.relatedTactics.isNotEmpty) ...[
                Text(
                  '関連する戦術',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final relatedId in pattern.relatedTactics)
                      _relatedChip(context, relatedId),
                  ],
                ),
              ],
            ],
          ),
        ),
      );

  Widget _relatedChip(BuildContext context, String relatedId) {
    final related = ChessCurriculumData.tacticsPatterns
        .where((p) => p.id == relatedId)
        .toList();
    final label = related.isNotEmpty ? related.first.name : relatedId;

    return ActionChip(
      label: Text(label),
      onPressed: related.isEmpty
          ? null
          : () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => TacticsDetailScreen(pattern: related.first),
                ),
              );
            },
    );
  }
}
