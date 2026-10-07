import 'package:flutter/material.dart';
import '../../data/chess_curriculum_data.dart';
import '../../models/lesson.dart';
import '../../widgets/learn/difficulty_badge.dart';

/// Lists the built-in strategy guides (positional principles, evaluation
/// criteria, planning guidelines) backed by [StrategyGuide].
class StrategyScreen extends StatelessWidget {
  const StrategyScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final guides = ChessCurriculumData.strategyGuides;

    return Scaffold(
      appBar: AppBar(title: const Text('戦略ガイド')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: guides.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final guide = guides[index];
          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(12),
              leading: const Icon(Icons.psychology_outlined, size: 32),
              title: Text(
                guide.title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(guide.description),
              ),
              trailing: DifficultyBadge(difficulty: guide.difficulty),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => StrategyDetailScreen(guide: guide),
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

class StrategyDetailScreen extends StatelessWidget {
  const StrategyDetailScreen({required this.guide, Key? key}) : super(key: key);
  final StrategyGuide guide;

  Widget _section(
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
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Icon(Icons.circle, size: 6),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(item)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(guide.title)),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      guide.description,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                  const SizedBox(width: 12),
                  DifficultyBadge(difficulty: guide.difficulty),
                ],
              ),
              const SizedBox(height: 24),
              _section(
                context,
                title: '重要な考え方',
                icon: Icons.lightbulb_outline,
                items: guide.keyConceptsExplained,
              ),
              _section(
                context,
                title: '局面の評価ポイント',
                icon: Icons.fact_check_outlined,
                items: guide.positionEvaluationCriteria,
              ),
              _section(
                context,
                title: '指し手の方針',
                icon: Icons.route_outlined,
                items: guide.planFormationGuidelines,
              ),
              _section(
                context,
                title: '終盤への移行のコツ',
                icon: Icons.flag_outlined,
                items: guide.endgameTransitionTips,
              ),
            ],
          ),
        ),
      );
}
