import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../../lib/src/services/ranking_service.dart';
import '../../lib/src/providers/leaderboard_provider.dart';

// Mock classes
class MockRankingService extends Mock implements RankingService {}

void main() {
  late ProviderContainer container;
  late MockRankingService mockRankingService;

  setUp(() {
    mockRankingService = MockRankingService();
    container = ProviderContainer(
      overrides: [
        rankingServiceProvider.overrideWithValue(mockRankingService),
      ],
    );
  });

  group('LeaderboardNotifier', () {
    testAsync('initializes with empty entries', (tester) async {
      when(mockRankingService.getGlobalRanking(
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
      )).thenAnswer((_) async => []);

      when(mockRankingService.getRankingStats())
          .thenAnswer((_) async => null);

      final state = container.read(leaderboardProvider);

      expect(state.entries, isEmpty);
      expect(state.isLoading, isFalse);
    });

    testAsync('loads global ranking', (tester) async {
      final mockEntries = [
        RankingEntry(
          uid: 'uid1',
          displayName: 'Player 1',
          photoUrl: null,
          rating: 1600,
          shogiRankString: '5級',
          gamesPlayed: 10,
          winRate: 0.6,
          rank: 1,
          lastGameAt: DateTime.now(),
        ),
      ];

      when(mockRankingService.getGlobalRanking(
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
      )).thenAnswer((_) async => mockEntries);

      when(mockRankingService.getRankingStats())
          .thenAnswer((_) async => RankingStats(
            totalPlayers: 100,
            averageRating: 1550,
            topRating: 1900,
            lastUpdated: DateTime.now(),
          ));

      final notifier = container.read(leaderboardProvider.notifier);
      await notifier.loadGlobalRanking();

      final state = container.read(leaderboardProvider);

      expect(state.entries, hasLength(1));
      expect(state.entries[0].displayName, equals('Player 1'));
      expect(state.filter, equals(LeaderboardFilter.global));
      expect(state.stats?.totalPlayers, equals(100));
    });

    testAsync('loads ranking by shogi rank', (tester) async {
      final mockEntries = [
        RankingEntry(
          uid: 'uid1',
          displayName: 'Player 1',
          photoUrl: null,
          rating: 1400,
          shogiRankString: '5級',
          gamesPlayed: 15,
          winRate: 0.55,
          rank: 1,
          lastGameAt: DateTime.now(),
        ),
      ];

      when(mockRankingService.getRankingByShogi(
        '5級',
        limit: anyNamed('limit'),
      )).thenAnswer((_) async => mockEntries);

      when(mockRankingService.getRankingStats())
          .thenAnswer((_) async => RankingStats(
            totalPlayers: 50,
            averageRating: 1400,
            topRating: 1700,
            lastUpdated: DateTime.now(),
          ));

      final notifier = container.read(leaderboardProvider.notifier);
      await notifier.loadRankingByShogi('5級');

      final state = container.read(leaderboardProvider);

      expect(state.entries, hasLength(1));
      expect(state.filter, equals(LeaderboardFilter.byShogi));
      expect(state.shogiRankFilter, equals('5級'));
    });

    testAsync('loads monthly ranking', (tester) async {
      final mockEntries = [
        RankingEntry(
          uid: 'uid2',
          displayName: 'Player 2',
          photoUrl: null,
          rating: 1550,
          shogiRankString: '4級',
          gamesPlayed: 25,
          winRate: 0.65,
          rank: 1,
          lastGameAt: DateTime.now(),
        ),
      ];

      when(mockRankingService.getMonthlyRanking(
        limit: anyNamed('limit'),
        monthKey: anyNamed('monthKey'),
      )).thenAnswer((_) async => mockEntries);

      when(mockRankingService.getRankingStats())
          .thenAnswer((_) async => RankingStats(
            totalPlayers: 200,
            averageRating: 1500,
            topRating: 1850,
            lastUpdated: DateTime.now(),
          ));

      final notifier = container.read(leaderboardProvider.notifier);
      await notifier.loadMonthlyRanking();

      final state = container.read(leaderboardProvider);

      expect(state.entries, hasLength(1));
      expect(state.filter, equals(LeaderboardFilter.monthly));
    });

    testAsync('handles next page', (tester) async {
      final mockEntries = List.generate(50, (i) => RankingEntry(
        uid: 'uid$i',
        displayName: 'Player $i',
        photoUrl: null,
        rating: 1600 - i * 10,
        shogiRankString: '5級',
        gamesPlayed: 10 + i,
        winRate: 0.5,
        rank: i + 1 + 50,
        lastGameAt: DateTime.now(),
      ));

      when(mockRankingService.getGlobalRanking(
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
      )).thenAnswer((_) async => mockEntries);

      when(mockRankingService.getRankingStats())
          .thenAnswer((_) async => null);

      final notifier = container.read(leaderboardProvider.notifier);
      await notifier.loadGlobalRanking(page: 0);
      await notifier.nextPage();

      final state = container.read(leaderboardProvider);
      expect(state.currentPage, equals(1));
    });

    testAsync('handles previous page', (tester) async {
      final mockEntries = [
        RankingEntry(
          uid: 'uid1',
          displayName: 'Player 1',
          photoUrl: null,
          rating: 1600,
          shogiRankString: '5级',
          gamesPlayed: 10,
          winRate: 0.6,
          rank: 1,
          lastGameAt: DateTime.now(),
        ),
      ];

      when(mockRankingService.getGlobalRanking(
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
      )).thenAnswer((_) async => mockEntries);

      when(mockRankingService.getRankingStats())
          .thenAnswer((_) async => null);

      final notifier = container.read(leaderboardProvider.notifier);
      await notifier.loadGlobalRanking(page: 1);
      await notifier.previousPage();

      final state = container.read(leaderboardProvider);
      expect(state.currentPage, equals(0));
    });

    testAsync('does not allow previous page when at page 0', (tester) async {
      final mockEntries = [];

      when(mockRankingService.getGlobalRanking(
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
      )).thenAnswer((_) async => mockEntries);

      when(mockRankingService.getRankingStats())
          .thenAnswer((_) async => null);

      final notifier = container.read(leaderboardProvider.notifier);
      await notifier.loadGlobalRanking(page: 0);
      await notifier.previousPage();

      final state = container.read(leaderboardProvider);
      expect(state.currentPage, equals(0));
    });

    testAsync('handles refresh', (tester) async {
      final mockEntries = [
        RankingEntry(
          uid: 'uid1',
          displayName: 'Player 1',
          photoUrl: null,
          rating: 1600,
          shogiRankString: '5级',
          gamesPlayed: 10,
          winRate: 0.6,
          rank: 1,
          lastGameAt: DateTime.now(),
        ),
      ];

      when(mockRankingService.getGlobalRanking(
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
      )).thenAnswer((_) async => mockEntries);

      when(mockRankingService.getRankingStats())
          .thenAnswer((_) async => null);

      final notifier = container.read(leaderboardProvider.notifier);
      await notifier.loadGlobalRanking();

      final stateBefore = container.read(leaderboardProvider);
      final refreshedBefore = stateBefore.lastRefreshed;

      // Simulate time passing
      await Future.delayed(const Duration(milliseconds: 10));

      await notifier.refresh();

      final stateAfter = container.read(leaderboardProvider);
      expect(stateAfter.lastRefreshed!.isAfter(refreshedBefore!), isTrue);
    });

    testAsync('sets loading state during fetch', (tester) async {
      when(mockRankingService.getGlobalRanking(
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
      )).thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 100));
        return [];
      });

      when(mockRankingService.getRankingStats())
          .thenAnswer((_) async => null);

      final notifier = container.read(leaderboardProvider.notifier);
      final future = notifier.loadGlobalRanking();

      // Check loading state immediately
      var state = container.read(leaderboardProvider);
      expect(state.isLoading, isTrue);

      await future;

      // After completion, loading should be false
      state = container.read(leaderboardProvider);
      expect(state.isLoading, isFalse);
    });

    testAsync('handles errors gracefully', (tester) async {
      when(mockRankingService.getGlobalRanking(
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
      )).thenThrow(Exception('Network error'));

      when(mockRankingService.getRankingStats())
          .thenThrow(Exception('Network error'));

      final notifier = container.read(leaderboardProvider.notifier);
      await notifier.loadGlobalRanking();

      final state = container.read(leaderboardProvider);
      expect(state.error, isNotNull);
      expect(state.error, contains('Failed to load rankings'));
      expect(state.isLoading, isFalse);
    });
  });

  group('UserRankNotifier', () {
    testAsync('loads user rank', (tester) async {
      when(mockRankingService.getUserRank('uid1'))
          .thenAnswer((_) async => 42);

      final notifier = container.read(userRankProvider('uid1').notifier);
      await notifier.loadUserRank();

      final rank = container.read(userRankProvider('uid1'));
      expect(rank, equals(42));
    });

    testAsync('handles rank not found', (tester) async {
      when(mockRankingService.getUserRank('unknown'))
          .thenAnswer((_) async => null);

      final notifier = container.read(userRankProvider('unknown').notifier);
      await notifier.loadUserRank();

      final rank = container.read(userRankProvider('unknown'));
      expect(rank, isNull);
    });
  });

  group('NearbyRankingsNotifier', () {
    testAsync('loads nearby rankings', (tester) async {
      final mockEntries = [
        RankingEntry(
          uid: 'uid1',
          displayName: 'Player 1',
          photoUrl: null,
          rating: 1600,
          shogiRankString: '5级',
          gamesPlayed: 10,
          winRate: 0.6,
          rank: 1,
          lastGameAt: DateTime.now(),
        ),
        RankingEntry(
          uid: 'uid2',
          displayName: 'Player 2',
          photoUrl: null,
          rating: 1550,
          shogiRankString: '6级',
          gamesPlayed: 8,
          winRate: 0.5,
          rank: 2,
          lastGameAt: DateTime.now(),
        ),
      ];

      when(mockRankingService.getNearbyRankings(
        'uid1',
        proximityCount: anyNamed('proximityCount'),
      )).thenAnswer((_) async => mockEntries);

      final notifier = container.read(nearbyRankingsProvider('uid1').notifier);
      await notifier.loadNearbyRankings();

      final rankings = container.read(nearbyRankingsProvider('uid1'));
      expect(rankings, hasLength(2));
      expect(rankings[0].displayName, equals('Player 1'));
    });
  });
}
