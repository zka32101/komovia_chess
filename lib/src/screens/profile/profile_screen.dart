import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../config/deployment_config.dart';
import '../../providers/auth_provider.dart';
import '../../providers/achievement_provider.dart';
import '../../services/achievement_service.dart'
    show AchievementDefinition, AchievementProgress;
import '../../providers/puzzle_provider.dart' show puzzleRatingProvider;
import '../../providers/online_game_provider.dart';
import '../../models/user.dart';
import '../../models/online_game.dart';
import '../online/game_review_screen.dart';
import 'edit_profile_screen.dart';
import '../friends/friends_screen.dart';
import '../tournaments/tournaments_screen.dart';
import '../challenges/challenges_screen.dart';
import '../comparison/player_comparison_screen.dart';
import '../ranking/my_ranking_screen.dart';
import '../analytics/performance_analytics_screen.dart';
import '../analytics/match_history_screen.dart';
import '../analytics_dashboard_screen.dart';
import '../seasonal_hub_screen.dart';

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

  bool get _isOwnProfile => widget.userId == null;

  @override
  Widget build(BuildContext context) {
    // Viewing someone else's profile (a friend, an opponent) resolves
    // their own doc via userByIdProvider instead of always showing the
    // signed-in user's - this used to ignore widget.userId entirely.
    final userAsyncValue = _isOwnProfile
        ? ref.watch(currentUserProvider)
        : ref.watch(userByIdProvider(widget.userId!));
    final gameHistory = ref.watch(userRecentGamesProvider).whenData(
          (games) => games.where((g) => g.status == 'completed').toList(),
        );

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
              onPressed: userAsyncValue.value == null
                  ? null
                  : () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              EditProfileScreen(user: userAsyncValue.value!),
                        ),
                      ),
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
                              rating:
                                  ref.watch(puzzleRatingProvider(user.uid)).value ??
                                      1600,
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

                  // Tab content. Games/Achievements aren't viewable for
                  // another user yet - userRecentGamesProvider/
                  // userAchievementProgressProvider are both hardcoded to
                  // the signed-in user, not parameterized by uid, so
                  // showing them here would silently display the
                  // viewer's own data under someone else's name.
                  if (_selectedTab == 0)
                    _buildStatisticsTab(user)
                  else if (_selectedTab == 1)
                    (_isOwnProfile
                        ? _buildGamesTab(gameHistory, user)
                        : _buildNotAvailableForOtherUsers())
                  else
                    (_isOwnProfile
                        ? _buildAchievementsTab()
                        : _buildNotAvailableForOtherUsers()),

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

  Widget _buildNotAvailableForOtherUsers() => const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Text(
            'Game history and achievements are only available on your own profile',
            textAlign: TextAlign.center,
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
          if (_isOwnProfile) ..._buildAnalyticsLinks(user),
          if (_isOwnProfile) ..._buildInviteSection(user),
        ],
      ),
    );
  }

  /// MyRankingScreen/PerformanceAnalyticsScreen/MatchHistoryScreen/
  /// SeasonalHubScreen were all fully built but had zero navigation entry
  /// points anywhere in the app - gated to the viewer's own profile since
  /// MyRankingScreen in particular always reads the *signed-in* user
  /// internally regardless of whose profile this is.
  List<Widget> _buildAnalyticsLinks(UserModel user) => [
        const SizedBox(height: 24),
        Text(
          'Rankings & Analytics',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        _buildLinkTile(
          icon: Icons.leaderboard,
          title: 'My Ranking',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const MyRankingScreen()),
          ),
        ),
        _buildLinkTile(
          icon: Icons.insights,
          title: 'Performance Analytics',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PerformanceAnalyticsScreen(
                playerId: user.uid,
                playerName: user.displayName ?? 'You',
              ),
            ),
          ),
        ),
        _buildLinkTile(
          icon: Icons.bar_chart,
          title: 'Analytics Dashboard',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AnalyticsDashboardScreen(userId: user.uid),
            ),
          ),
        ),
        _buildLinkTile(
          icon: Icons.history,
          title: 'Match History',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => MatchHistoryScreen(
                playerId: user.uid,
                playerName: user.displayName ?? 'You',
              ),
            ),
          ),
        ),
        _buildLinkTile(
          icon: Icons.event,
          title: 'Seasonal Hub',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SeasonalHubScreen(playerId: user.uid),
            ),
          ),
        ),
      ];

  /// No referral/invite mechanism existed anywhere in the app. This is a
  /// plain share-the-app-link action rather than a tracked referral system
  /// (no InviteService/Firestore attribution) - deliberately scoped small;
  /// the user's uid is included as a referral code string for a future
  /// attribution pass to parse out of shared text, but nothing reads it yet.
  List<Widget> _buildInviteSection(UserModel user) => [
        const SizedBox(height: 24),
        Text(
          'Invite Friends',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const Icon(Icons.person_add),
            title: const Text('友達を招待'),
            subtitle: const Text('Share Komovia Chess with a friend'),
            trailing: const Icon(Icons.share),
            onTap: () => _inviteFriend(user),
          ),
        ),
      ];

  Future<void> _inviteFriend(UserModel user) async {
    final referralCode = user.uid.substring(0, 8);
    await Share.share(
      'Play chess with me on Komovia Chess! ♟️ '
      '(referral: $referralCode)\n'
      'iOS: ${DeploymentConfig.iosAppStoreUrl}\n'
      'Android: ${DeploymentConfig.androidPlayStoreUrl}',
    );
  }

  Widget _buildLinkTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) =>
      Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: Icon(icon),
          title: Text(title),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      );

  Widget _buildGamesTab(
          AsyncValue<List<OnlineGame>> gameHistory, UserModel user) =>
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
                return _buildGameCard(game, user);
              },
            ),
          );
        },
      );

  Widget _buildGameCard(OnlineGame game, UserModel user) {
    final isWhiteWin = game.result == 'white_win';
    final isBlackWin = game.result == 'black_win';
    final isDraw = game.result == 'draw';
    final isUserWhite = game.whitePlayerId == user.uid;
    final opponentId = isUserWhite ? game.blackPlayerId : game.whitePlayerId;
    final opponentName =
        (isUserWhite ? game.blackPlayerName : game.whitePlayerName) ??
            'Opponent';
    final opponentRating = isUserWhite ? game.blackRating : game.whiteRating;

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
            IconButton(
              icon: const Icon(Icons.compare_arrows, size: 20),
              tooltip: 'Compare with $opponentName',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PlayerComparisonScreen(
                    player1Id: user.uid,
                    player1Name: user.displayName ?? 'You',
                    player1Rating: user.onlineRating ?? 1600,
                    player2Id: opponentId,
                    player2Name: opponentName,
                    player2Rating: opponentRating,
                  ),
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

  Widget _buildAchievementsTab() {
    final progressAsync = ref.watch(userAchievementProgressProvider);
    final definitionsAsync = ref.watch(achievementDefinitionsProvider);

    return progressAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Error loading achievements: $error'),
      ),
      data: (progressList) {
        final definitions = definitionsAsync.value ?? const {};
        if (progressList.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: Text('No achievements yet')),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: progressList.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final progress = progressList[index];
            final def = definitions[progress.achievementId];

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: progress.isUnlocked
                    ? Colors.amber.withOpacity(0.1)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: progress.isUnlocked
                    ? Border.all(color: Colors.amber)
                    : null,
              ),
              child: Row(
                children: [
                  Text(
                    def?.icon.isNotEmpty == true ? def!.icon : '🏆',
                    style: const TextStyle(fontSize: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          def?.name ?? progress.achievementId,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: progress.isUnlocked
                                ? null
                                : Colors.grey.shade600,
                          ),
                        ),
                        if (def?.description.isNotEmpty == true) ...[
                          const SizedBox(height: 4),
                          Text(
                            def!.description,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                        if (!progress.isUnlocked &&
                            progress.targetValue > 0) ...[
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress.progressPercentage / 100,
                              minHeight: 6,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${progress.currentValue}/${progress.targetValue}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (progress.isUnlocked) ...[
                    IconButton(
                      icon: const Icon(Icons.share, size: 20),
                      tooltip: 'Share',
                      onPressed: () => _shareAchievement(def, progress),
                    ),
                    const Icon(Icons.check_circle, color: Colors.amber),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Achievement unlocks have no board state to render as a GIF (unlike
  /// game/puzzle shares via GameGifService), so this is a plain text share
  /// through the OS share sheet rather than reusing that service.
  Future<void> _shareAchievement(
    AchievementDefinition? def,
    AchievementProgress progress,
  ) async {
    final icon = def?.icon.isNotEmpty == true ? def!.icon : '🏆';
    final name = def?.name ?? progress.achievementId;
    await Share.share(
      '$icon Unlocked "$name" on Komovia Chess! #chess',
    );
  }
}
