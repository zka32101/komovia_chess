import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../providers/online_game_provider.dart';
import '../../models/user.dart';
import '../../models/online_game.dart';
import '../online/game_review_screen.dart';
import '../friends/friends_screen.dart';
import '../tournaments/tournaments_screen.dart';
import '../challenges/challenges_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({
    Key? key,
    this.userId,
  }) : super(key: key);
  final String? userId;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  int _selectedTab = 0; // 0: Stats, 1: Games, 2: Achievements

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final gameHistory = ref.watch(userRecentGamesProvider).whenData(
          (games) => games.where((g) => g.status == 'completed').toList(),
        );

    // If userId is provided, fetch that user's profile (TODO)
    // For now, show current user's profile
    final userAsyncValue = currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: true,
        elevation: 0,
        actions: [
          if (widget.userId == null) // Only shown for own profile
            IconButton(
              icon: const Icon(Icons.emoji_events_outlined),
              tooltip: 'Tournaments',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TournamentsScreen()),
              ),
            ),
          if (widget.userId == null) // Only shown for own profile
            IconButton(
              icon: const Icon(Icons.people_outline),
              tooltip: 'Friends',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FriendsScreen()),
              ),
            ),
          if (widget.userId == null) // Only shown for own profile
            IconButton(
              icon: const Icon(Icons.bolt_outlined),
              tooltip: 'Challenges',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ChallengesScreen()),
              ),
            ),
          if (widget.userId == null) // Only show edit for own profile
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                // TODO: Navigate to edit profile screen
              },
            ),
        ],
      ),
      body: userAsyncValue.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => Center(
          child: Text('Error: $error'),
        ),
        data: (user) {
          if (user == null) {
            return const Center(
              child: Text('User not found'),
            );
          }

          return SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Profile header
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        // Avatar
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.blue.shade100,
                          backgroundImage: user.photoUrl != null
                              ? NetworkImage(user.photoUrl!)
                              : null,
                          child: user.photoUrl == null
                              ? Text(
                                  (user.displayName ?? 'User')
                                      .substring(0, 1)
                                      .toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(height: 16),

                        // Name
                        Text(
                          user.displayName ?? 'Anonymous',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),

                        // Email
                        Text(
                          user.email,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Rating badges
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildRatingBadge(
                              label: 'Blitz',
                              rating: user.onlineRating ?? 1600,
                            ),
                            const SizedBox(width: 16),
                            _buildRatingBadge(
                              label: 'Puzzles',
                              rating: 1600, // TODO: Use actual puzzle rating
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Stats overview
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStatColumn(
                            label: 'Games',
                            value: user.gamesPlayed.toString(),
                          ),
                          _buildStatColumn(
                            label: 'Wins',
                            value: user.wins.toString(),
                          ),
                          _buildStatColumn(
                            label: 'Draws',
                            value: user.draws.toString(),
                          ),
                          _buildStatColumn(
                            label: 'Losses',
                            value: user.losses.toString(),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Tab navigation
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildTabButton(
                            label: 'Statistics',
                            isSelected: _selectedTab == 0,
                            onTap: () => setState(() => _selectedTab = 0),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTabButton(
                            label: 'Games',
                            isSelected: _selectedTab == 1,
                            onTap: () => setState(() => _selectedTab = 1),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTabButton(
                            label: 'Achievements',
                            isSelected: _selectedTab == 2,
                            onTap: () => setState(() => _selectedTab = 2),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Tab content
                  if (_selectedTab == 0)
                    _buildStatisticsTab(user)
                  else if (_selectedTab == 1)
                    _buildGamesTab(gameHistory)
                  else
                    _buildAchievementsTab(),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRatingBadge({
    required String label,
    required int rating,
  }) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          border: Border.all(color: Colors.blue.shade200),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              rating.toString(),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );

  Widget _buildStatColumn({
    required String label,
    required String value,
  }) =>
      Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      );

  Widget _buildTabButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? Colors.blue : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.blue : Colors.grey.shade600,
            ),
          ),
        ),
      );

  Widget _buildStatisticsTab(UserModel user) {
    final winRate = user.gamesPlayed > 0
        ? ((user.wins / user.gamesPlayed) * 100).toStringAsFixed(1)
        : '0.0';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatCard(
            title: 'Win Rate',
            value: '$winRate%',
            description: '${user.wins} wins out of ${user.gamesPlayed} games',
          ),
          const SizedBox(height: 12),
          _buildStatCard(
            title: 'Current Rating',
            value: user.onlineRating.toString() ?? '1600',
            description: 'Online blitz rating',
          ),
          const SizedBox(height: 12),
          _buildStatCard(
            title: 'Member Since',
            value: user.createdAt?.year.toString() ?? '2024',
            description:
                'Joined on ${user.createdAt?.toString().split(' ')[0] ?? 'N/A'}',
          ),
        ],
      ),
    );
  }

  Widget _buildGamesTab(AsyncValue<List<OnlineGame>> gameHistory) =>
      gameHistory.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Error loading games: $error'),
        ),
        data: (games) {
          if (games.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(Icons.history, size: 48, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No games yet'),
                ],
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: games.length,
              itemBuilder: (context, index) {
                final game = games[index];
                return _buildGameCard(game);
              },
            ),
          );
        },
      );

  Widget _buildGameCard(OnlineGame game) {
    final isWhiteWin = game.result == 'white_win';
    final isBlackWin = game.result == 'black_win';
    final isDraw = game.result == 'draw';

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GameReviewScreen(gameId: game.gameId, game: game),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${game.whitePlayerName} vs ${game.blackPlayerName}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    game.timeControl,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDraw
                    ? Colors.grey.shade100
                    : isWhiteWin
                        ? Colors.green.shade100
                        : Colors.red.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                isDraw
                    ? 'Draw'
                    : isWhiteWin
                        ? '1-0'
                        : '0-1',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDraw
                      ? Colors.grey.shade700
                      : isWhiteWin
                          ? Colors.green.shade700
                          : Colors.red.shade700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String description,
  }) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );

  Widget _buildAchievementsTab() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Icon(Icons.emoji_events, size: 48, color: Colors.amber),
                  const SizedBox(height: 16),
                  const Text(
                    'Achievements Coming Soon',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Unlock achievements by completing milestones',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}
