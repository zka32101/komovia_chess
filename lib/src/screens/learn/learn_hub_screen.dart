import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/lesson.dart' show ContentType;
import '../../models/weakness_profile.dart';
import '../../providers/phase_i_providers.dart';
import '../../providers/weakness_analysis_provider.dart';
import 'how_to_play_screen.dart';
import 'opening_course_screen.dart';
import 'opening_explorer_screen.dart';
import 'repertoire_screen.dart';
import 'strategy_screen.dart';
import 'tactics_screen.dart';

/// Entry point for all built-in learning content: how to play, structured
/// opening courses, tactical patterns, and strategy guides.
class LearnHubScreen extends ConsumerWidget {
  const LearnHubScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(lessonCompletionSummaryProvider);
    final weaknessAsync = ref.watch(weaknessProfileProvider);

    return Scaffold(
        appBar: AppBar(title: const Text('学習センター')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            weaknessAsync.when(
              data: (profile) => _buildWeaknessCard(context, profile),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            Text(
              '初めての方はこちら',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            _LearnCard(
              icon: Icons.school_outlined,
              iconColor: Colors.green,
              title: '遊び方',
              subtitle: 'チェスのルールと、各駒の動かし方を学びます',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const HowToPlayScreen()),
                );
              },
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'もっと上達したい方へ',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (summary.started > 0)
                  Chip(
                    label: Text(summary.averageMastery > 0
                        ? '完了 ${summary.completed}/${summary.started}'
                            ' · 理解度 ${summary.averageMastery.toStringAsFixed(1)}'
                        : '完了 ${summary.completed}/${summary.started}'),
                    avatar: const Icon(Icons.check_circle_outline, size: 18),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _LearnCard(
              icon: Icons.route_outlined,
              iconColor: Colors.deepPurple,
              title: 'オープニング講座',
              subtitle: 'レベル別に整理された、体系的なオープニング学習',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const OpeningCourseScreen()),
                );
              },
            ),
            const SizedBox(height: 12),
            _LearnCard(
              icon: Icons.manage_search_outlined,
              iconColor: Colors.teal,
              title: 'マイオープニング統計',
              subtitle: '自分の過去の対局から、よく指す局面の勝率を振り返る',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const OpeningExplorerScreen()),
                );
              },
            ),
            const SizedBox(height: 12),
            _LearnCard(
              icon: Icons.repeat_outlined,
              iconColor: Colors.indigo,
              title: 'レパートリー復習',
              subtitle: '覚えたいオープニングの手順を登録し、間隔反復で記憶を定着',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RepertoireScreen()),
                );
              },
            ),
            const SizedBox(height: 12),
            _LearnCard(
              icon: Icons.bolt_outlined,
              iconColor: Colors.orange,
              title: '戦術パターン',
              subtitle: 'フォーク・ピン・スキュワーなど、勝負を決める手筋',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TacticsScreen()),
                );
              },
            ),
            const SizedBox(height: 12),
            _LearnCard(
              icon: Icons.psychology_outlined,
              iconColor: Colors.blue,
              title: '戦略ガイド',
              subtitle: '駒の活用・キングの安全など、盤面全体の考え方',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const StrategyScreen()),
                );
              },
            ),
          ],
        ),
      );
  }

  /// Shows nothing until the player has had at least a handful of moves
  /// analyzed (WeaknessProfile.hasEnoughData) - a single analyzed game
  /// isn't enough signal to recommend anything specific yet, and an
  /// empty/misleading recommendation would be worse than none.
  Widget _buildWeaknessCard(BuildContext context, WeaknessProfile profile) {
    final weakest = profile.weakestPhase;
    if (!profile.hasEnoughData || weakest == null) {
      return const SizedBox.shrink();
    }
    final stats = profile.byPhase[weakest]!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Card(
        color: Colors.deepOrange.shade50,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openContentType(context, weakest.recommendedContentType),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.insights, color: Colors.deepOrange, size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '苦手分野: ${weakest.label}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '直近${profile.gamesAnalyzed}局の分析から、'
                        '${weakest.label}でのミスが${stats.errorCount}回見つかりました。'
                        'おすすめのレッスンへ',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade700,
                            ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openContentType(BuildContext context, ContentType type) {
    final Widget screen;
    switch (type) {
      case ContentType.opening:
        screen = const OpeningCourseScreen();
        break;
      case ContentType.tactic:
        screen = const TacticsScreen();
        break;
      case ContentType.strategy:
        screen = const StrategyScreen();
        break;
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}

class _LearnCard extends StatelessWidget {
  const _LearnCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      );
}
