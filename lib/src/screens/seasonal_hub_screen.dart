import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/phase_u_providers.dart';
import '../widgets/phase_u_seasonal_widgets.dart';
import '../services/season_management_service.dart';
import '../services/seasonal_event_service.dart';

/// Main Seasonal Hub Screen
/// Displays all seasonal features: seasons, battle pass, challenges, events
class SeasonalHubScreen extends ConsumerStatefulWidget {
  const SeasonalHubScreen({required this.playerId, Key? key}) : super(key: key);
  final String playerId;

  @override
  ConsumerState<SeasonalHubScreen> createState() => _SeasonalHubScreenState();
}

class _SeasonalHubScreenState extends ConsumerState<SeasonalHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentSeasonAsync = ref.watch(currentSeasonProvider);

    return currentSeasonAsync.when(
      data: (season) {
        if (season == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Seasonal Hub')),
            body: const Center(
              child: Text('No active season at this time'),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Seasonal Hub'),
            elevation: 0,
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Season'),
                Tab(text: 'Battle Pass'),
                Tab(text: 'Challenges'),
                Tab(text: 'Events'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildSeasonTab(context, season),
              _buildBattlePassTab(context, season),
              _buildChallengesTab(context, season),
              _buildEventsTab(context, season),
            ],
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Seasonal Hub')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, st) => Scaffold(
        appBar: AppBar(title: const Text('Seasonal Hub')),
        body: Center(
          child: Text('Error loading season: $e'),
        ),
      ),
    );
  }

  Widget _buildSeasonTab(BuildContext context, Season season) =>
      SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SeasonProgressCard(
              playerId: widget.playerId,
              seasonId: season.seasonId,
            ),
            const SizedBox(height: 16),
            SeasonStatisticsCard(
              playerId: widget.playerId,
              seasonId: season.seasonId,
            ),
            const SizedBox(height: 16),
            _buildSeasonInfoCard(context, season),
          ],
        ),
      );

  Widget _buildSeasonInfoCard(BuildContext context, Season season) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Season Information',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              _buildInfoRow('Theme:', season.theme),
              _buildInfoRow('Max Level:', '${season.maxLevel}'),
              _buildInfoRow(
                'Duration:',
                '${season.startDate.toString().split(' ')[0]} - '
                    '${season.endDate.toString().split(' ')[0]}',
              ),
              _buildInfoRow('Status:', season.status),
            ],
          ),
        ),
      );

  Widget _buildInfoRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      );

  Widget _buildBattlePassTab(BuildContext context, Season season) =>
      SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            BattlePassProgressCard(
              playerId: widget.playerId,
              seasonId: season.seasonId,
            ),
            const SizedBox(height: 16),
            _buildBattlePassInfo(context),
          ],
        ),
      );

  Widget _buildBattlePassInfo(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Battle Pass Features',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              _buildFeatureItem(
                'Free Track',
                'Earn rewards with free battle pass',
              ),
              _buildFeatureItem(
                'Premium Track',
                'Unlock exclusive rewards with premium',
              ),
              _buildFeatureItem(
                'Weekly Rewards',
                'Claim milestone rewards at each level',
              ),
              _buildFeatureItem(
                'Progression',
                'Earn XP from matches and challenges',
              ),
            ],
          ),
        ),
      );

  Widget _buildFeatureItem(String title, String description) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(description, style: const TextStyle(fontSize: 12)),
          ],
        ),
      );

  Widget _buildChallengesTab(BuildContext context, Season season) =>
      SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ChallengeTrackerCard(
              playerId: widget.playerId,
              seasonId: season.seasonId,
            ),
            const SizedBox(height: 16),
            _buildChallengeFilters(context, season),
          ],
        ),
      );

  Widget _buildChallengeFilters(BuildContext context, Season season) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Challenge Types',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              _buildFilterChip('Daily', 'Complete daily challenges'),
              _buildFilterChip('Weekly', 'Complete weekly challenges'),
              _buildFilterChip('Seasonal', 'Complete seasonal challenges'),
            ],
          ),
        ),
      );

  Widget _buildFilterChip(String label, String description) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(description, style: const TextStyle(fontSize: 12)),
          ],
        ),
      );

  Widget _buildEventsTab(BuildContext context, Season season) {
    final activeEventsAsync = ref.watch(activeEventsProvider(season.seasonId));

    return activeEventsAsync.when(
      data: (events) {
        if (events.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No active events',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              ...events.map((event) => _buildEventCard(context, event)),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildEventCard(BuildContext context, SeasonalEvent event) {
    final isActive = DateTime.now().isAfter(event.startDate) &&
        DateTime.now().isBefore(event.endDate);
    final daysRemaining = event.endDate.difference(DateTime.now()).inDays;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        event.type,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.green : Colors.grey,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isActive ? 'Active' : 'Upcoming',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(event.description),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Participants: ${event.currentParticipants}/'
                  '${event.maxParticipants}',
                ),
                Text('$daysRemaining days left'),
              ],
            ),
            const SizedBox(height: 12),
            if (isActive)
              ElevatedButton(
                onPressed: () {
                  // Handle participation
                },
                child: const Text('Join Event'),
              ),
          ],
        ),
      ),
    );
  }
}
