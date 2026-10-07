import 'package:flutter/material.dart';
import 'how_to_play_screen.dart';
import 'opening_course_screen.dart';
import 'strategy_screen.dart';
import 'tactics_screen.dart';

/// Entry point for all built-in learning content: how to play, structured
/// opening courses, tactical patterns, and strategy guides.
class LearnHubScreen extends StatelessWidget {
  const LearnHubScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('学習センター')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
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
            Text(
              'もっと上達したい方へ',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
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
