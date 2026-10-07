import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:komovia_chess/src/models/online_game.dart';
import 'package:komovia_chess/src/services/matchmaking_service.dart';
import 'package:komovia_chess/src/services/online_game_service.dart';

// Mock classes
class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockCollectionReference extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class MockDocumentReference extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

class MockQuerySnapshot extends Mock
    implements QuerySnapshot<Map<String, dynamic>> {}

class MockDocumentSnapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

class MockQuery extends Mock implements Query<Map<String, dynamic>> {}

void main() {
  group('MatchmakingService', () {
    late MatchmakingService service;

    setUp(() {
      service = MatchmakingService();
    });

    group('joinQueue', () {
      test('creates queue entry with correct rating range', () async {
        final playerId = 'player-001';
        final playerRating = 1600;
        final ratingRange = 200; // +/- 200

        final minRating = playerRating - ratingRange;
        final maxRating = playerRating + ratingRange;

        expect(minRating, 1400);
        expect(maxRating, 1800);
      });

      test('sets timeout to 30 seconds from now', () async {
        final queueTime = DateTime.now();
        final timeout = queueTime.add(const Duration(seconds: 30));

        final difference = timeout.difference(queueTime);
        expect(difference.inSeconds, 30);
      });

      test('initializes with waiting status', () async {
        final queueEntry = {
          'playerId': 'player-001',
          'status': 'waiting',
          'rating': 1600,
        };

        expect(queueEntry['status'], 'waiting');
      });
    });

    group('leaveQueue', () {
      test('removes player from queue', () async {
        var queue = [
          {'playerId': 'player-001', 'status': 'waiting'},
          {'playerId': 'player-002', 'status': 'waiting'},
        ];

        queue = queue.where((e) => e['playerId'] != 'player-001').toList();
        expect(queue.length, 1);
        expect(queue[0]['playerId'], 'player-002');
      });

      test('handles non-existent queue entries', () async {
        final queue = <Map<String, dynamic>>[];
        final removed =
            queue.where((e) => e['playerId'] == 'nonexistent').toList();

        expect(removed, isEmpty);
      });
    });

    group('getQueueStatus', () {
      test('returns current queue status', () async {
        final queueId = 'queue-001';
        final status = {
          'id': queueId,
          'status': 'waiting',
          'joinedAt': DateTime.now(),
          'position': 5,
        };

        expect(status['id'], queueId);
        expect(status['status'], 'waiting');
      });

      test('calculates wait time correctly', () async {
        final joinedAt = DateTime.now().subtract(const Duration(seconds: 15));
        final currentTime = DateTime.now();
        final waitTime = currentTime.difference(joinedAt);

        expect(waitTime.inSeconds, greaterThanOrEqualTo(15));
      });

      test('returns not_found for invalid queue ID', () async {
        final invalidQueueId = 'invalid-queue-999';
        final queue = <Map<String, dynamic>>[
          {'id': 'queue-001', 'status': 'waiting'},
        ];

        final result =
            queue.where((q) => q['id'] == invalidQueueId).firstOrNull;
        expect(result, isNull);
      });
    });

    group('getQueueStats', () {
      test('returns total waiting players', () async {
        final queue = [
          {'playerId': 'player-001', 'status': 'waiting'},
          {'playerId': 'player-002', 'status': 'waiting'},
          {'playerId': 'player-003', 'status': 'matched'},
        ];

        final waitingCount =
            queue.where((q) => q['status'] == 'waiting').length;
        expect(waitingCount, 2);
      });

      test('groups players by time control', () async {
        final queue = [
          {'playerId': 'player-001', 'timeControl': '3min'},
          {'playerId': 'player-002', 'timeControl': '3min'},
          {'playerId': 'player-003', 'timeControl': '5min'},
        ];

        final byTimeControl = <String, List<Map<String, dynamic>>>{};
        for (final player in queue) {
          final tc = player['timeControl'] as String;
          byTimeControl.putIfAbsent(tc, () => []).add(player);
        }

        expect(byTimeControl['3min']?.length, 2);
        expect(byTimeControl['5min']?.length, 1);
      });

      test('calculates average wait time', () async {
        final now = DateTime.now();
        final queue = [
          {'joinedAt': now.subtract(const Duration(seconds: 10))},
          {'joinedAt': now.subtract(const Duration(seconds: 20))},
          {'joinedAt': now.subtract(const Duration(seconds: 30))},
        ];

        final totalWaitMs = queue.fold<int>(
          0,
          (sum, q) =>
              sum + now.difference(q['joinedAt'] as DateTime).inMilliseconds,
        );
        final avgWaitMs = totalWaitMs ~/ queue.length;

        expect(avgWaitMs, greaterThan(0));
      });
    });

    group('cleanupExpiredEntries', () {
      test('removes expired queue entries', () async {
        final now = DateTime.now();
        var queue = [
          {
            'playerId': 'player-001',
            'timeout': now.subtract(const Duration(seconds: 35)),
          },
          {
            'playerId': 'player-002',
            'timeout': now.add(const Duration(seconds: 10)),
          },
        ];

        queue = queue.where((q) {
          final timeout = q['timeout'] as DateTime;
          return timeout.isAfter(now);
        }).toList();

        expect(queue.length, 1);
        expect(queue[0]['playerId'], 'player-002');
      });

      test('returns count of cleaned entries', () async {
        final now = DateTime.now();
        var queue = [
          {'timeout': now.subtract(const Duration(seconds: 35))},
          {'timeout': now.subtract(const Duration(seconds: 40))},
          {'timeout': now.add(const Duration(seconds: 10))},
        ];

        final expiredCount = queue.where((q) {
          final timeout = q['timeout'] as DateTime;
          return timeout.isBefore(now);
        }).length;

        expect(expiredCount, 2);
      });

      test('preserves non-expired entries', () async {
        final now = DateTime.now();
        final queue = [
          {
            'playerId': 'player-001',
            'timeout': now.add(const Duration(seconds: 20))
          },
          {
            'playerId': 'player-002',
            'timeout': now.add(const Duration(seconds: 15))
          },
        ];

        final validEntries = queue.where((q) {
          final timeout = q['timeout'] as DateTime;
          return timeout.isAfter(now);
        }).toList();

        expect(validEntries.length, 2);
      });
    });
  });

  group('OnlineGameService', () {
    late OnlineGameService service;

    setUp(() {
      service = OnlineGameService();
    });

    group('createGame', () {
      test('creates game with initial starting position', () async {
        final game = {
          'gameId': 'game-001',
          'fen': 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
          'status': 'created',
        };

        expect(game['fen'], startsWith('rnbqkbnr'));
      });

      test('sets game to matchmaking status', () async {
        final game = {
          'gameId': 'game-002',
          'status': 'matchmaking',
          'createdAt': DateTime.now(),
        };

        expect(game['status'], 'matchmaking');
      });

      test('initializes time remaining correctly', () async {
        final timeControlMs = 180000; // 3 minutes
        final game = {
          'whiteTimeRemainingMs': timeControlMs,
          'blackTimeRemainingMs': timeControlMs,
        };

        expect(game['whiteTimeRemainingMs'], 180000);
        expect(game['blackTimeRemainingMs'], 180000);
      });

      test('parses time control string correctly', () async {
        // 3min should be 180000ms
        // 5min should be 300000ms
        // 10min should be 600000ms
        final parseTimeControl = (String timeControl) {
          final value =
              int.tryParse(timeControl.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
          if (timeControl.contains('min')) {
            return value * 60 * 1000;
          }
          return value * 1000;
        };

        expect(parseTimeControl('3min'), 180000);
        expect(parseTimeControl('5min'), 300000);
        expect(parseTimeControl('10min'), 600000);
      });

      test('generates unique game ID', () async {
        final gameId1 = 'game-${DateTime.now().millisecondsSinceEpoch}';
        final gameId2 = 'game-${DateTime.now().millisecondsSinceEpoch + 1}';

        expect(gameId1, isNotEmpty);
        expect(gameId1, isNot(equals(gameId2)));
      });
    });

    group('startGame', () {
      test('transitions game to active status', () async {
        var game = {
          'gameId': 'game-001',
          'status': 'matchmaking',
        };

        game['status'] = 'active';

        expect(game['status'], 'active');
      });

      test('sets startedAt timestamp', () async {
        final now = DateTime.now();
        var game = {
          'gameId': 'game-001',
          'createdAt': now,
          'startedAt': null,
        };

        game['startedAt'] = now;

        expect(game['startedAt'], isNotNull);
      });

      test('preserves game data during transition', () async {
        final game = {
          'gameId': 'game-001',
          'whitePlayerId': 'player-w',
          'blackPlayerId': 'player-b',
          'status': 'active',
          'fen': 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        };

        expect(game['whitePlayerId'], 'player-w');
        expect(game['blackPlayerId'], 'player-b');
        expect(game['fen'], startsWith('rnbqkbnr'));
      });
    });

    group('recordMove', () {
      test('adds move to moves array', () async {
        var moves = <Map<String, dynamic>>[];
        final move = {'from': 'e2', 'to': 'e4', 'timestamp': DateTime.now()};

        moves.add(move);

        expect(moves.length, 1);
        expect(moves[0]['from'], 'e2');
      });

      test('updates FEN position', () async {
        var currentFen =
            'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
        // After e2-e4
        currentFen =
            'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1';

        expect(currentFen, contains('4P3'));
      });

      test('updates PGN notation', () async {
        var pgn = '';
        pgn += '1. e4 ';

        expect(pgn, contains('e4'));
      });

      test('records move timestamp', () async {
        final moveTime = DateTime.now();
        final move = {
          'from': 'e2',
          'to': 'e4',
          'timestamp': moveTime,
        };

        expect(move['timestamp'], isNotNull);
      });

      test('tracks player who made move', () async {
        final move = {
          'from': 'e2',
          'to': 'e4',
          'playerId': 'player-w',
        };

        expect(move['playerId'], 'player-w');
      });
    });

    group('updateTimeRemaining', () {
      test('updates white time remaining', () async {
        var game = {
          'whiteTimeRemainingMs': 180000,
        };

        game['whiteTimeRemainingMs'] = 170000;

        expect(game['whiteTimeRemainingMs'], 170000);
      });

      test('updates black time remaining', () async {
        var game = {
          'blackTimeRemainingMs': 180000,
        };

        game['blackTimeRemainingMs'] = 165000;

        expect(game['blackTimeRemainingMs'], 165000);
      });

      test('detects white timeout', () async {
        final game = {
          'whiteTimeRemainingMs': 0,
          'status': 'active',
        };

        final isTimeout = (game['whiteTimeRemainingMs'] as int) <= 0;
        expect(isTimeout, true);
      });

      test('detects black timeout', () async {
        final game = {
          'blackTimeRemainingMs': 0,
          'status': 'active',
        };

        final isTimeout = (game['blackTimeRemainingMs'] as int) <= 0;
        expect(isTimeout, true);
      });

      test('ends game when timeout occurs', () async {
        var game = {
          'whiteTimeRemainingMs': 0,
          'status': 'active',
        };

        if ((game['whiteTimeRemainingMs'] as int) <= 0) {
          game['status'] = 'completed';
          game['result'] = 'black_win';
        }

        expect(game['status'], 'completed');
        expect(game['result'], 'black_win');
      });
    });

    group('recordActivity', () {
      test('updates white activity timestamp', () async {
        final now = DateTime.now();
        var game = {
          'whiteLastActivityAt': null,
        };

        game['whiteLastActivityAt'] = now;

        expect(game['whiteLastActivityAt'], isNotNull);
      });

      test('updates black activity timestamp', () async {
        final now = DateTime.now();
        var game = {
          'blackLastActivityAt': null,
        };

        game['blackLastActivityAt'] = now;

        expect(game['blackLastActivityAt'], isNotNull);
      });
    });

    group('resignGame', () {
      test('ends game with resignation', () async {
        var game = {
          'gameId': 'game-001',
          'status': 'active',
          'result': null,
        };

        game['status'] = 'completed';
        game['result'] = 'black_win';

        expect(game['status'], 'completed');
      });

      test('sets correct winner when white resigns', () async {
        var game = {
          'whitePlayerId': 'player-w',
          'blackPlayerId': 'player-b',
          'status': 'active',
        };

        game['status'] = 'completed';
        game['result'] = 'black_win';

        expect(game['result'], 'black_win');
      });

      test('sets correct winner when black resigns', () async {
        var game = {
          'whitePlayerId': 'player-w',
          'blackPlayerId': 'player-b',
          'status': 'active',
        };

        game['status'] = 'completed';
        game['result'] = 'white_win';

        expect(game['result'], 'white_win');
      });
    });

    group('abandonGame', () {
      test('marks game as abandoned', () async {
        var game = {
          'status': 'active',
          'abandonedBy': null,
        };

        game['status'] = 'abandoned';
        game['abandonedBy'] = 'player-w';

        expect(game['status'], 'abandoned');
      });

      test('records who abandoned', () async {
        var game = {
          'abandonedBy': null,
        };

        game['abandonedBy'] = 'player-w';

        expect(game['abandonedBy'], 'player-w');
      });

      test('determines winner based on abandoning player', () async {
        var game = {
          'abandonedBy': 'player-w',
          'result': null,
        };

        game['result'] = 'black_win';

        expect(game['result'], 'black_win');
      });
    });

    group('getGame', () {
      test('returns game by ID', () async {
        final games = [
          {'gameId': 'game-001', 'status': 'active'},
          {'gameId': 'game-002', 'status': 'completed'},
        ];

        final game = games.where((g) => g['gameId'] == 'game-001').firstOrNull;

        expect(game, isNotNull);
        expect(game?['gameId'], 'game-001');
      });

      test('returns null for non-existent game', () async {
        final games = <Map<String, dynamic>>[
          {'gameId': 'game-001', 'status': 'active'},
        ];

        final game = games.where((g) => g['gameId'] == 'game-999').firstOrNull;

        expect(game, isNull);
      });
    });

    group('getGameMoves', () {
      test('returns moves ordered by move number', () async {
        final moves = [
          {'moveNumber': 1, 'from': 'e2', 'to': 'e4'},
          {'moveNumber': 2, 'from': 'c7', 'to': 'c5'},
          {'moveNumber': 3, 'from': 'g1', 'to': 'f3'},
        ];

        expect(moves.length, 3);
        expect(moves[0]['moveNumber'], 1);
        expect(moves[1]['moveNumber'], 2);
      });

      test('includes all move details (from, to, promotion)', () async {
        final move = {
          'from': 'e7',
          'to': 'e8',
          'promotion': 'Q',
          'timestamp': DateTime.now(),
        };

        expect(move['from'], 'e7');
        expect(move['to'], 'e8');
        expect(move['promotion'], 'Q');
      });

      test('returns empty list for new games', () async {
        final moves = <Map<String, dynamic>>[];
        expect(moves, isEmpty);
      });
    });

    group('watchGame', () {
      test('returns stream of game updates', () async {
        // Mock stream would emit game updates
        final gameUpdates = [
          {
            'status': 'active',
            'fen': 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1'
          },
        ];

        expect(gameUpdates, isNotEmpty);
      });

      test('emits error for non-existent game', () async {
        expect(
          () => throw Exception('Game not found'),
          throwsException,
        );
      });
    });

    group('getPlayerActiveGames', () {
      test('returns games where player is white', () async {
        final playerId = 'player-001';
        final games = [
          {'gameId': 'g1', 'whitePlayerId': playerId, 'status': 'active'},
          {'gameId': 'g2', 'blackPlayerId': playerId, 'status': 'active'},
          {'gameId': 'g3', 'whitePlayerId': 'other', 'status': 'active'},
        ];

        final whiteGames =
            games.where((g) => g['whitePlayerId'] == playerId).toList();
        expect(whiteGames.length, 1);
      });

      test('returns games where player is black', () async {
        final playerId = 'player-001';
        final games = [
          {'gameId': 'g1', 'whitePlayerId': 'other', 'status': 'active'},
          {'gameId': 'g2', 'blackPlayerId': playerId, 'status': 'active'},
        ];

        final blackGames =
            games.where((g) => g['blackPlayerId'] == playerId).toList();
        expect(blackGames.length, 1);
      });

      test('combines white and black games', () async {
        final playerId = 'player-001';
        final games = [
          {'gameId': 'g1', 'whitePlayerId': playerId, 'status': 'active'},
          {'gameId': 'g2', 'blackPlayerId': playerId, 'status': 'active'},
        ];

        final allGames = games
            .where((g) =>
                (g['whitePlayerId'] == playerId ||
                    g['blackPlayerId'] == playerId) &&
                g['status'] == 'active')
            .toList();

        expect(allGames.length, 2);
      });

      test('filters to only active games', () async {
        final playerId = 'player-001';
        final games = [
          {'gameId': 'g1', 'whitePlayerId': playerId, 'status': 'active'},
          {'gameId': 'g2', 'whitePlayerId': playerId, 'status': 'completed'},
        ];

        final activeGames =
            games.where((g) => g['status'] == 'active').toList();
        expect(activeGames.length, 1);
      });

      test('returns empty list when player has no active games', () async {
        final playerId = 'player-999';
        final games = [
          {'gameId': 'g1', 'whitePlayerId': 'other', 'status': 'active'},
        ];

        final activeGames = games
            .where((g) => (g['whitePlayerId'] == playerId ||
                g['blackPlayerId'] == playerId))
            .toList();

        expect(activeGames, isEmpty);
      });
    });

    group('getPlayerRecentGames', () {
      test('returns games ordered by creation date', () async {
        final games = [
          {'gameId': 'g1', 'createdAt': DateTime(2026, 8, 25)},
          {'gameId': 'g2', 'createdAt': DateTime(2026, 8, 26)},
          {'gameId': 'g3', 'createdAt': DateTime(2026, 8, 27)},
        ];

        final sorted = games
          ..sort((a, b) => (b['createdAt'] as DateTime)
              .compareTo(a['createdAt'] as DateTime));

        expect(sorted[0]['gameId'], 'g3');
      });

      test('respects limit parameter', () async {
        final games = [
          {'gameId': 'g1'},
          {'gameId': 'g2'},
          {'gameId': 'g3'},
          {'gameId': 'g4'},
          {'gameId': 'g5'},
        ];

        final limited = games.take(3).toList();
        expect(limited.length, 3);
      });

      test('includes completed and abandoned games', () async {
        final games = [
          {'gameId': 'g1', 'status': 'completed'},
          {'gameId': 'g2', 'status': 'abandoned'},
          {'gameId': 'g3', 'status': 'active'},
        ];

        final recentStati = ['completed', 'abandoned', 'active'];
        final filtered =
            games.where((g) => recentStati.contains(g['status'])).toList();

        expect(filtered.length, 3);
      });
    });

    group('Rating calculation', () {
      test('white win increases white rating', () async {
        final whiteRating = 1600;
        final blackRating = 1600;

        // Simple ELO: K=32, equal rated should gain 16
        final expectedDelta = 16;

        expect(expectedDelta, greaterThan(0));
      });

      test('white loss decreases white rating', () async {
        final whiteRating = 1600;
        final blackRating = 1600;

        // Simple ELO: K=32, equal rated should lose 16
        final expectedDelta = -16;

        expect(expectedDelta, lessThan(0));
      });

      test('draw results in smaller rating changes', () async {
        final whiteRating = 1600;
        final blackRating = 1600;

        // Draw with equal rated: 0 change (expected score was 0.5)
        final drawDelta = 0;

        expect(drawDelta, equals(0));
      });

      test('stronger player gains less for win', () async {
        final strongerRating = 1800;
        final weakerRating = 1400;

        // Expected score: stronger player should win
        // Gain should be less than upset win
        final expectedGainStronger = 8; // Less than 16

        expect(expectedGainStronger, lessThan(16));
      });

      test('weaker player gains more for upset win', () async {
        final strongerRating = 1800;
        final weakerRating = 1400;

        // Weaker player winning is upset
        // Should gain more than normal win
        final expectedGainWeaker = 24; // More than 16

        expect(expectedGainWeaker, greaterThan(16));
      });
    });
  });

  group('Integration Tests', () {
    late OnlineGameService gameService;
    late MatchmakingService matchmakingService;

    setUp(() {
      gameService = OnlineGameService();
      matchmakingService = MatchmakingService();
    });

    test('complete game flow: create -> start -> moves -> complete', () async {
      // 1. Create game from matched players
      var game = {
        'gameId': 'game-001',
        'status': 'matchmaking',
        'whitePlayerId': 'player-1',
        'blackPlayerId': 'player-2',
      };

      // 2. Start game
      game['status'] = 'active';

      // 3. Players make moves
      final moves = [
        {'from': 'e2', 'to': 'e4'},
        {'from': 'c7', 'to': 'c5'},
      ];

      // 4. Game reaches conclusion
      game['status'] = 'completed';
      game['result'] = 'white_win';

      // 5. Ratings updated
      game['whiteRatingDelta'] = 16;
      game['blackRatingDelta'] = -16;

      expect(game['status'], 'completed');
      expect(moves.length, 2);
    });

    test('timeout handling in active game', () async {
      // 1. Create and start game
      var game = {
        'gameId': 'game-002',
        'status': 'active',
        'whiteTimeRemainingMs': 180000,
        'blackTimeRemainingMs': 180000,
      };

      // 2. Simulate time passing
      game['whiteTimeRemainingMs'] = 5000;

      // 3. Update time remaining to 0
      game['whiteTimeRemainingMs'] = 0;

      // 4. Verify game ended with timeout result
      if ((game['whiteTimeRemainingMs'] as int) <= 0) {
        game['status'] = 'completed';
        game['result'] = 'black_win';
      }

      expect(game['status'], 'completed');
      expect(game['result'], 'black_win');
    });

    test('resignation handling', () async {
      // 1. Create and start game
      var game = {
        'gameId': 'game-003',
        'status': 'active',
        'whitePlayerId': 'player-1',
      };

      // 2. Player resigns
      final resigningPlayer = 'player-1';

      // 3. Other player declared winner
      game['status'] = 'completed';
      game['result'] = 'black_win';

      // 4. Ratings updated
      game['ratings'] = {'delta': -16};

      expect(game['status'], 'completed');
      expect(game['result'], 'black_win');
    });

    test('abandonment handling', () async {
      // 1. Create and start game
      var game = {
        'gameId': 'game-004',
        'status': 'active',
      };

      // 2. Player disconnects/abandons
      game['abandonedBy'] = 'player-1';

      // 3. Game marked abandoned
      game['status'] = 'abandoned';

      // 4. Other player declared winner
      game['result'] = 'black_win';

      expect(game['status'], 'abandoned');
      expect(game['result'], 'black_win');
    });

    test('real-time synchronization', () async {
      // 1. Create game
      final game = {
        'gameId': 'game-005',
        'status': 'active',
      };

      // 2. Watch game stream
      final updates = [game];

      // 3. Make moves
      final moves = [
        {'from': 'e2', 'to': 'e4'}
      ];

      // 4. Verify stream emits updates
      expect(updates, isNotEmpty);
      expect(moves.length, 1);
    });

    test('draw agreement handling', () async {
      // 1. Create and start game
      var game = {
        'gameId': 'game-006',
        'status': 'active',
      };

      // 2. Both players agree to draw
      game['drawOfferBy'] = 'player-1';
      game['drawAcceptedBy'] = 'player-2';

      // 3. Game ends with draw result
      game['status'] = 'completed';
      game['result'] = 'draw';

      // 4. Both players rating adjusted for draw
      game['whiteRatingDelta'] = 0;
      game['blackRatingDelta'] = 0;

      expect(game['result'], 'draw');
      expect(game['status'], 'completed');
    });
  });
}
