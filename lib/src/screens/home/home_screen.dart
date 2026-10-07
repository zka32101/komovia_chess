import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../utils/animations.dart';
import '../puzzle/puzzle_screen.dart';
import '../settings/settings_screen.dart';
import '../profile/profile_screen.dart';
import '../online/matchmaking_screen.dart';
import '../game/cpu_game_selection_screen.dart';
import '../premium/premium_screen.dart';
import '../notifications_screen.dart';
import '../ranking/leaderboard_screen.dart';
import '../learn/learn_hub_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Widget _buildNotificationButton(
    BuildContext context,
    AsyncValue<UserModel?> userAsync,
  ) =>
      userAsync.when(
        loading: () => const SizedBox(),
        error: (_, __) => const SizedBox(),
        data: (user) {
          if (user == null) return const SizedBox();

          return Consumer(
            builder: (context, ref, _) {
              final unreadCount = ref.watch(unreadNotificationsCountProvider);

              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    onPressed: () {
                      Navigator.of(context).push(
                        SmoothPageTransition(page: const NotificationsScreen()),
                      );
                    },
                    tooltip: 'Notifications',
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            unreadCount > 99 ? '99+' : '$unreadCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      );

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(authStateNotifierProvider);

    return userAsync.when(
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Text('Error: $error'),
        ),
      ),
      data: (user) {
        if (user == null) {
          // User not authenticated, redirect to login
          // This should be handled by the root navigation
          return const Scaffold(
            body: Center(
              child: Text('Not authenticated'),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('♟️ Chess Tactics Master'),
            centerTitle: true,
            elevation: 0,
            actions: [
              _buildNotificationButton(context, userAsync),
              IconButton(
                icon: const Icon(Icons.school_outlined),
                onPressed: () {
                  Navigator.of(context).push(
                    SmoothPageTransition(page: const LearnHubScreen()),
                  );
                },
                tooltip: 'Learn',
              ),
              IconButton(
                icon: const Icon(Icons.leaderboard_outlined),
                onPressed: () {
                  Navigator.of(context).push(
                    SmoothPageTransition(page: const LeaderboardScreen()),
                  );
                },
                tooltip: 'Leaderboard',
              ),
              IconButton(
                icon: const Icon(Icons.star_outline),
                onPressed: () {
                  Navigator.of(context).push(
                    SmoothPageTransition(page: const PremiumScreen()),
                  );
                },
                tooltip: 'Premium',
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                onPressed: () {
                  Navigator.of(context).push(
                    SmoothPageTransition(page: const SettingsScreen()),
                  );
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            child: Column(
              children: [
                // User Status Section
                _UserStatusSection(user: user),

                // Learn Section
                const _LearnSection(),

                // Daily Challenge Section
                const _DailyChallengeSection(),

                // Recent Games Section
                const _RecentGamesSection(),

                // Bottom spacer
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _UserStatusSection extends StatelessWidget {
  const _UserStatusSection({required this.user});
  final UserModel user;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).primaryColor,
              Theme.of(context).primaryColor.withOpacity(0.7),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User info
            Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundImage: user.photoUrl != null
                      ? NetworkImage(user.photoUrl!)
                      : null,
                  child: user.photoUrl == null
                      ? Text(
                          user.displayName?.substring(0, 1).toUpperCase() ??
                              '?',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName ?? 'Player',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        user.email,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white70,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Rating and stats
            Row(
              children: [
                _StatCard(
                  label: 'Rating',
                  value: user.rating.toString(),
                  icon: Icons.trending_up,
                ),
                const SizedBox(width: 12),
                _StatCard(
                  label: 'Games',
                  value: user.gamesPlayed.toString(),
                  icon: Icons.sports_esports,
                ),
                const SizedBox(width: 12),
                _StatCard(
                  label: 'Win Rate',
                  value: user.gamesPlayed > 0
                      ? '${(user.wins / user.gamesPlayed * 100).toStringAsFixed(0)}%'
                      : '--',
                  icon: Icons.emoji_events,
                ),
              ],
            ),
          ],
        ),
      );
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Expanded(
        child: BounceAnimation(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _DailyChallengeSection extends StatelessWidget {
  const _DailyChallengeSection();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Today\'s Challenge',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).primaryColor,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.emoji_events,
                    size: 48,
                    color: Colors.amber,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Fork Tactic Challenge',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '5 puzzles • Rating 800-1200',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          SmoothPageTransition(page: const PuzzleScreen()),
                        );
                      },
                      child: const Text('Start Challenge'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _LearnSection extends StatelessWidget {
  const _LearnSection();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Card(
          color:
              Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              Navigator.of(context).push(
                SmoothPageTransition(page: const LearnHubScreen()),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.school_outlined, size: 32),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '遊び方・戦術・戦略を学ぶ',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '初めての方はここから。ルールからオープニングまで、ステップで学べます。',
                          style: Theme.of(context).textTheme.bodySmall,
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

class _RecentGamesSection extends StatelessWidget {
  const _RecentGamesSection();

  @override
  Widget build(BuildContext context) {
    // Mock data for now
    final mockGames = [
      {
        'opponent': 'AlexChess',
        'result': 'Win',
        'ratingChange': '+18',
        'time': '2 hours ago',
      },
      {
        'opponent': 'ChessMaster99',
        'result': 'Loss',
        'ratingChange': '-12',
        'time': 'Yesterday',
      },
      {
        'opponent': 'PuzzleKing',
        'result': 'Draw',
        'ratingChange': '+0',
        'time': '3 days ago',
      },
    ];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick play buttons
          Row(
            children: [
              Expanded(
                child: FilledButton.tonal(
                  onPressed: () {
                    Navigator.of(context).push(
                      SmoothPageTransition(page: const MatchmakingScreen()),
                    );
                  },
                  child: const Text('Find Opponent'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      SmoothPageTransition(
                          page: const CPUGameSelectionScreen()),
                    );
                  },
                  child: const Text('Play CPU'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Recent games header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Games',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    SmoothPageTransition(page: const ProfileScreen()),
                  );
                },
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...mockGames.asMap().entries.map((entry) {
            final index = entry.key;
            final game = entry.value;
            return SlideInAnimation(
              direction: SlideDirection.left,
              delay: Duration(milliseconds: index * 100),
              child: _GameCard(
                opponent: game['opponent']!,
                result: game['result']!,
                ratingChange: game['ratingChange']!,
                time: game['time']!,
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({
    required this.opponent,
    required this.result,
    required this.ratingChange,
    required this.time,
  });
  final String opponent;
  final String result;
  final String ratingChange;
  final String time;

  Color _getResultColor() {
    switch (result.toLowerCase()) {
      case 'win':
        return Colors.green;
      case 'loss':
        return Colors.red;
      case 'draw':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              child: Text(opponent.substring(0, 1).toUpperCase()),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    opponent,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(
                    time,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getResultColor().withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    result,
                    style: TextStyle(
                      color: _getResultColor(),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  ratingChange,
                  style: TextStyle(
                    color:
                        ratingChange.contains('-') ? Colors.red : Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
}
