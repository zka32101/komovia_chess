import 'package:flutter/material.dart';
import '../../data/chess_curriculum_data.dart';
import '../../models/lesson.dart';
import '../../widgets/learn/difficulty_badge.dart';

/// Chessable-style structured opening course: openings are grouped into
/// difficulty "modules" so beginners are guided toward simpler openings
/// before advanced theory, backed by [OpeningExplanation].
class OpeningCourseScreen extends StatelessWidget {
  const OpeningCourseScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final openings = ChessCurriculumData.openingCourse;
    final modules = <DifficultyLevel, List<OpeningExplanation>>{};
    for (final opening in openings) {
      modules.putIfAbsent(opening.difficulty, () => []).add(opening);
    }

    const moduleOrder = [
      DifficultyLevel.beginner,
      DifficultyLevel.intermediate,
      DifficultyLevel.advanced,
      DifficultyLevel.expert,
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('オープニング講座')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'レベル別に整理されたオープニング講座です。まずは初級モジュールから始めましょう。',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 20),
          for (final level in moduleOrder)
            if (modules[level] != null) ...[
              _ModuleHeader(level: level, count: modules[level]!.length),
              const SizedBox(height: 8),
              for (final opening in modules[level]!)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _OpeningCard(opening: opening),
                ),
              const SizedBox(height: 16),
            ],
        ],
      ),
    );
  }
}

class _ModuleHeader extends StatelessWidget {
  const _ModuleHeader({required this.level, required this.count});
  final DifficultyLevel level;
  final int count;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          DifficultyBadge(difficulty: level),
          const SizedBox(width: 8),
          Text(
            'モジュール ($count講座)',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
        ],
      );
}

class _OpeningCard extends StatelessWidget {
  const _OpeningCard({required this.opening});
  final OpeningExplanation opening;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          contentPadding: const EdgeInsets.all(12),
          leading: CircleAvatar(
            child: Text(
              opening.ecoCode.substring(0, 1),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          title: Text(
            opening.name,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('${opening.ecoCode} · ${opening.description}'),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => OpeningDetailScreen(opening: opening),
              ),
            );
          },
        ),
      );
}

class OpeningDetailScreen extends StatelessWidget {
  const OpeningDetailScreen({required this.opening, Key? key})
      : super(key: key);
  final OpeningExplanation opening;

  Widget _section(
    BuildContext context, {
    required String title,
    required List<String> items,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(item),
            ),
        ],
      ),
    );
  }

  Widget _statRow(BuildContext context) => Row(
        children: [
          Expanded(
            child: _statTile(context, '白の勝率', opening.winRateWhite),
          ),
          Expanded(
            child: _statTile(context, '黒の勝率', opening.winRateBlack),
          ),
          Expanded(
            child: _statTile(context, '引き分け率', opening.drawRate),
          ),
        ],
      );

  Widget _statTile(BuildContext context, String label, double value) => Column(
        children: [
          Text(
            '${(value * 100).toStringAsFixed(0)}%',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(opening.name)),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${opening.ecoCode} · ${opening.description}',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                  const SizedBox(width: 12),
                  DifficultyBadge(difficulty: opening.difficulty),
                ],
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _statRow(context),
                ),
              ),
              const SizedBox(height: 24),
              if (opening.mainLinesPgn.isNotEmpty) ...[
                Text(
                  '基本ライン',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                for (final line in opening.mainLinesPgn)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      line,
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ),
                const SizedBox(height: 16),
              ],
              _section(context,
                  title: '戦略的な考え方', items: opening.strategicIdeas),
              _section(context, title: '典型的なプラン', items: opening.typicalPlans),
              _section(context, title: '注意すべき罠', items: opening.commonTrapsPgn),
              _section(context, title: '歴史的背景', items: opening.historyNotes),
            ],
          ),
        ),
      );
}
