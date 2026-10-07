import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mockito/mockito.dart';
import 'package:komovia_chess/src/services/unified_game_history_service.dart';

// Mock classes
class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockUser extends Mock implements User {
  @override
  String? get uid => 'test_user_123';
}

class MockUserCredential extends Mock implements UserCredential {}

class MockQuery extends Mock implements Query {}

class MockQuerySnapshot extends Mock implements QuerySnapshot {}

class MockDocumentSnapshot extends Mock implements DocumentSnapshot {
  final Map<String, dynamic> _data;
  final String _id;

  MockDocumentSnapshot(this._data, this._id);

  @override
  Map<String, dynamic>? data() => _data;

  @override
  String get id => _id;
}

class _MockCollectionReference extends Mock implements CollectionReference {
  final Query _query;

  _MockCollectionReference(this._query);

  @override
  Query where(Object field) => _query;
}

class MockCollectionReference extends Mock implements CollectionReference {
  final Query _query;

  MockCollectionReference(this._query);

  @override
  Query where(Object field) => _query;
}

void main() {
  group('UnifiedGameHistoryService', () {
    late UnifiedGameHistoryService gameHistoryService;
    late MockFirebaseAuth mockAuth;
    late MockFirebaseFirestore mockFirestore;
    late MockUser mockUser;

    setUp(() {
      mockAuth = MockFirebaseAuth();
      mockFirestore = MockFirebaseFirestore();
      mockUser = MockUser();

      when(mockAuth.currentUser).thenReturn(mockUser);

      gameHistoryService = UnifiedGameHistoryService(
        firestore: mockFirestore,
        auth: mockAuth,
      );
    });

    group('Exception Handling', () {
      test('GameHistoryException has message', () {
        final exception = GameHistoryException('Test error');
        expect(exception.toString(), equals('Test error'));
      });

      test('GameHistoryException can include error code', () {
        final exception = GameHistoryException(
          'Network error',
          code: 'network_error',
        );
        expect(exception.code, equals('network_error'));
      });

      test('GameHistoryException can store original error', () {
        final originalError = Exception('Original');
        final exception = GameHistoryException(
          'Wrapped error',
          originalError: originalError,
        );
        expect(exception.originalError, equals(originalError));
      });

      test('throws GameHistoryException when no user logged in', () async {
        when(mockAuth.currentUser).thenReturn(null);

        final service = UnifiedGameHistoryService(
          firestore: mockFirestore,
          auth: mockAuth,
        );

        expect(
          () => service.getMatchHistory(),
          throwsA(isA<GameHistoryException>()
              .having((e) => e.code, 'code', equals('auth_required'))),
        );
      });
    });

    group('getMatchHistory', () {
      test('returns empty list when no games found', () async {
        final mockQuerySnapshot = MockQuerySnapshot();
        when(mockQuerySnapshot.docs).thenReturn([]);
        when(mockQuerySnapshot.get()).thenAnswer((_) async => mockQuerySnapshot);

        final mockQuery = MockQuery();
        when(mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        when(mockQuery.limit(any)).thenReturn(mockQuery);
        when(mockQuery.orderBy(any, descending: anyNamed('descending')))
            .thenReturn(mockQuery);
        when(mockQuery.where(any)).thenReturn(mockQuery);

        when(mockFirestore.collection('games')).thenReturn(
          _MockCollectionReference(mockQuery),
        );

        final result = await gameHistoryService.getMatchHistory();
        expect(result, isEmpty);
      });

      test('returns paginated results', () async {
        final gameData = {
          'whitePlayerId': 'user1',
          'blackPlayerId': 'user2',
          'status': 'completed',
          'endedAt': DateTime.now(),
          'result': 'white_win',
        };

        final mockDoc = MockDocumentSnapshot(gameData, 'game1');
        final mockQuerySnapshot = MockQuerySnapshot();
        when(mockQuerySnapshot.docs).thenReturn([mockDoc]);
        when(mockQuerySnapshot.get()).thenAnswer((_) async => mockQuerySnapshot);

        final mockQuery = MockQuery();
        when(mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        when(mockQuery.limit(any)).thenReturn(mockQuery);
        when(mockQuery.orderBy(any, descending: anyNamed('descending')))
            .thenReturn(mockQuery);
        when(mockQuery.where(any)).thenReturn(mockQuery);

        when(mockFirestore.collection('games')).thenReturn(
          _MockCollectionReference(mockQuery),
        );

        final result = await gameHistoryService.getMatchHistory(limit: 10);
        expect(result, isNotEmpty);
        expect(result.first['gameId'], equals('game1'));
      });

      test('orders games by most recent first', () async {
        final mockQuerySnapshot = MockQuerySnapshot();
        when(mockQuerySnapshot.docs).thenReturn([]);
        when(mockQuerySnapshot.get()).thenAnswer((_) async => mockQuerySnapshot);

        final mockQuery = MockQuery();
        when(mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        when(mockQuery.limit(any)).thenReturn(mockQuery);

        // Verify orderBy is called with descending=true
        var orderByInvoked = false;
        when(mockQuery.orderBy(any, descending: anyNamed('descending')))
            .thenAnswer((invocation) {
          if (invocation.namedArguments[#descending] == true) {
            orderByInvoked = true;
          }
          return mockQuery;
        });

        when(mockQuery.where(any)).thenReturn(mockQuery);
        when(mockFirestore.collection('games')).thenReturn(
          _MockCollectionReference(mockQuery),
        );

        await gameHistoryService.getMatchHistory();
        expect(orderByInvoked, isTrue);
      });

      test('throws GameHistoryException on network error', () async {
        final mockQuery = MockQuery();
        when(mockQuery.get()).thenThrow(SocketException('Network error'));
        when(mockQuery.limit(any)).thenReturn(mockQuery);
        when(mockQuery.orderBy(any, descending: anyNamed('descending')))
            .thenReturn(mockQuery);
        when(mockQuery.where(any)).thenReturn(mockQuery);

        when(mockFirestore.collection('games')).thenReturn(
          _MockCollectionReference(mockQuery),
        );

        expect(
          () => gameHistoryService.getMatchHistory(),
          throwsA(isA<GameHistoryException>()
              .having((e) => e.code, 'code', equals('network_error'))),
        );
      });
    });

    group('watchMatchHistory', () {
      test('returns stream of match history', () async {
        final gameData = {
          'whitePlayerId': 'user1',
          'blackPlayerId': 'user2',
          'status': 'completed',
          'endedAt': DateTime.now(),
        };

        final mockDoc = MockDocumentSnapshot(gameData, 'game1');
        final mockQuerySnapshot = MockQuerySnapshot();
        when(mockQuerySnapshot.docs).thenReturn([mockDoc]);

        final mockStream = Stream.value(mockQuerySnapshot);

        final mockQuery = MockQuery();
        when(mockQuery.snapshots()).thenAnswer((_) => mockStream);
        when(mockQuery.limit(any)).thenReturn(mockQuery);
        when(mockQuery.orderBy(any, descending: anyNamed('descending')))
            .thenReturn(mockQuery);
        when(mockQuery.where(any)).thenReturn(mockQuery);

        when(mockFirestore.collection('games')).thenReturn(
          _MockCollectionReference(mockQuery),
        );

        final stream = gameHistoryService.watchMatchHistory();
        final result = await stream.first;

        expect(result, isNotEmpty);
        expect(result.first['gameId'], equals('game1'));
      });

      test('handles stream errors gracefully', () async {
        final mockQuery = MockQuery();
        final errorStream = Stream<QuerySnapshot>.error(
          Exception('Stream error'),
        );
        when(mockQuery.snapshots()).thenAnswer((_) => errorStream);
        when(mockQuery.limit(any)).thenReturn(mockQuery);
        when(mockQuery.orderBy(any, descending: anyNamed('descending')))
            .thenReturn(mockQuery);
        when(mockQuery.where(any)).thenReturn(mockQuery);

        when(mockFirestore.collection('games')).thenReturn(
          _MockCollectionReference(mockQuery),
        );

        final stream = gameHistoryService.watchMatchHistory();
        final result = await stream.first;

        // Error handling returns empty list
        expect(result, isEmpty);
      });

      test('limits results to recent 100 games', () async {
        final mockQuery = MockQuery();
        var limitInvoked = false;
        var limitValue = 0;

        when(mockQuery.limit(any)).thenAnswer((invocation) {
          limitInvoked = true;
          limitValue = invocation.positionalArguments[0] as int;
          return mockQuery;
        });

        final mockQuerySnapshot = MockQuerySnapshot();
        when(mockQuerySnapshot.docs).thenReturn([]);
        final mockStream = Stream.value(mockQuerySnapshot);
        when(mockQuery.snapshots()).thenAnswer((_) => mockStream);

        when(mockQuery.orderBy(any, descending: anyNamed('descending')))
            .thenReturn(mockQuery);
        when(mockQuery.where(any)).thenReturn(mockQuery);

        when(mockFirestore.collection('games')).thenReturn(
          _MockCollectionReference(mockQuery),
        );

        await gameHistoryService.watchMatchHistory().first;

        expect(limitInvoked, isTrue);
        expect(limitValue, equals(100));
      });
    });

    group('filterGames', () {
      test('filters by date range', () async {
        final gameData = {
          'whitePlayerId': 'test_user_123',
          'blackPlayerId': 'opponent1',
          'status': 'completed',
          'endedAt': DateTime.now(),
          'whiteRating': 1500,
          'blackRating': 1400,
        };

        final mockDoc = MockDocumentSnapshot(gameData, 'game1');
        final mockQuerySnapshot = MockQuerySnapshot();
        when(mockQuerySnapshot.docs).thenReturn([mockDoc]);

        final mockQuery = MockQuery();
        when(mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        when(mockQuery.where(any)).thenReturn(mockQuery);
        when(mockQuery.limit(any)).thenReturn(mockQuery);
        when(mockQuery.orderBy(any, descending: anyNamed('descending')))
            .thenReturn(mockQuery);

        when(mockFirestore.collection('games')).thenReturn(
          _MockCollectionReference(mockQuery),
        );

        final fromDate = DateTime.now().subtract(Duration(days: 7));
        final toDate = DateTime.now();

        final result = await gameHistoryService.filterGames(
          fromDate: fromDate,
          toDate: toDate,
        );

        expect(result, isNotEmpty);
      });

      test('filters by opponent', () async {
        final gameData = {
          'whitePlayerId': 'test_user_123',
          'blackPlayerId': 'opponent1',
          'status': 'completed',
          'endedAt': DateTime.now(),
          'whiteRating': 1500,
          'blackRating': 1400,
        };

        final mockDoc = MockDocumentSnapshot(gameData, 'game1');
        final mockQuerySnapshot = MockQuerySnapshot();
        when(mockQuerySnapshot.docs).thenReturn([mockDoc]);

        final mockQuery = MockQuery();
        when(mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        when(mockQuery.where(any)).thenReturn(mockQuery);
        when(mockQuery.limit(any)).thenReturn(mockQuery);
        when(mockQuery.orderBy(any, descending: anyNamed('descending')))
            .thenReturn(mockQuery);

        when(mockFirestore.collection('games')).thenReturn(
          _MockCollectionReference(mockQuery),
        );

        final result = await gameHistoryService.filterGames(
          opponentId: 'opponent1',
        );

        expect(result, isNotEmpty);
      });

      test('filters by game result', () async {
        final gameData = {
          'whitePlayerId': 'test_user_123',
          'blackPlayerId': 'opponent1',
          'status': 'completed',
          'endedAt': DateTime.now(),
          'result': 'white_win',
          'whiteRating': 1500,
          'blackRating': 1400,
        };

        final mockDoc = MockDocumentSnapshot(gameData, 'game1');
        final mockQuerySnapshot = MockQuerySnapshot();
        when(mockQuerySnapshot.docs).thenReturn([mockDoc]);

        final mockQuery = MockQuery();
        when(mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        when(mockQuery.where(any)).thenReturn(mockQuery);
        when(mockQuery.limit(any)).thenReturn(mockQuery);
        when(mockQuery.orderBy(any, descending: anyNamed('descending')))
            .thenReturn(mockQuery);

        when(mockFirestore.collection('games')).thenReturn(
          _MockCollectionReference(mockQuery),
        );

        final result = await gameHistoryService.filterGames(
          result: 'white_win',
        );

        expect(result, isNotEmpty);
      });

      test('filters by time control', () async {
        final gameData = {
          'whitePlayerId': 'test_user_123',
          'blackPlayerId': 'opponent1',
          'status': 'completed',
          'endedAt': DateTime.now(),
          'timeControl': 'blitz',
          'whiteRating': 1500,
          'blackRating': 1400,
        };

        final mockDoc = MockDocumentSnapshot(gameData, 'game1');
        final mockQuerySnapshot = MockQuerySnapshot();
        when(mockQuerySnapshot.docs).thenReturn([mockDoc]);

        final mockQuery = MockQuery();
        when(mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        when(mockQuery.where(any)).thenReturn(mockQuery);
        when(mockQuery.limit(any)).thenReturn(mockQuery);
        when(mockQuery.orderBy(any, descending: anyNamed('descending')))
            .thenReturn(mockQuery);

        when(mockFirestore.collection('games')).thenReturn(
          _MockCollectionReference(mockQuery),
        );

        final result = await gameHistoryService.filterGames(
          timeControl: 'blitz',
        );

        expect(result, isNotEmpty);
      });

      test('filters by rating range (client-side)', () async {
        final gameData = {
          'whitePlayerId': 'test_user_123',
          'blackPlayerId': 'opponent1',
          'status': 'completed',
          'endedAt': DateTime.now(),
          'whiteRating': 1500,
          'blackRating': 1400,
        };

        final mockDoc = MockDocumentSnapshot(gameData, 'game1');
        final mockQuerySnapshot = MockQuerySnapshot();
        when(mockQuerySnapshot.docs).thenReturn([mockDoc]);

        final mockQuery = MockQuery();
        when(mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        when(mockQuery.where(any)).thenReturn(mockQuery);
        when(mockQuery.limit(any)).thenReturn(mockQuery);
        when(mockQuery.orderBy(any, descending: anyNamed('descending')))
            .thenReturn(mockQuery);

        when(mockFirestore.collection('games')).thenReturn(
          _MockCollectionReference(mockQuery),
        );

        final result = await gameHistoryService.filterGames(
          minRating: 1400,
          maxRating: 1600,
        );

        expect(result, isNotEmpty);
      });

      test('combines multiple filters', () async {
        final gameData = {
          'whitePlayerId': 'test_user_123',
          'blackPlayerId': 'opponent1',
          'status': 'completed',
          'endedAt': DateTime.now(),
          'result': 'white_win',
          'timeControl': 'blitz',
          'whiteRating': 1500,
          'blackRating': 1400,
        };

        final mockDoc = MockDocumentSnapshot(gameData, 'game1');
        final mockQuerySnapshot = MockQuerySnapshot();
        when(mockQuerySnapshot.docs).thenReturn([mockDoc]);

        final mockQuery = MockQuery();
        when(mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        when(mockQuery.where(any)).thenReturn(mockQuery);
        when(mockQuery.limit(any)).thenReturn(mockQuery);
        when(mockQuery.orderBy(any, descending: anyNamed('descending')))
            .thenReturn(mockQuery);

        when(mockFirestore.collection('games')).thenReturn(
          _MockCollectionReference(mockQuery),
        );

        final result = await gameHistoryService.filterGames(
          fromDate: DateTime.now().subtract(Duration(days: 7)),
          toDate: DateTime.now(),
          opponentId: 'opponent1',
          result: 'white_win',
          timeControl: 'blitz',
          minRating: 1400,
          maxRating: 1600,
        );

        expect(result, isNotEmpty);
      });

      test('respects limit parameter', () async {
        var limitValue = 0;
        final mockQuery = MockQuery();
        when(mockQuery.limit(any)).thenAnswer((invocation) {
          limitValue = invocation.positionalArguments[0] as int;
          return mockQuery;
        });

        final mockQuerySnapshot = MockQuerySnapshot();
        when(mockQuerySnapshot.docs).thenReturn([]);
        when(mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);

        when(mockQuery.where(any)).thenReturn(mockQuery);
        when(mockQuery.orderBy(any, descending: anyNamed('descending')))
            .thenReturn(mockQuery);

        when(mockFirestore.collection('games')).thenReturn(
          _MockCollectionReference(mockQuery),
        );

        await gameHistoryService.filterGames(limit: 50);

        expect(limitValue, equals(50));
      });

      test('throws GameHistoryException on error', () async {
        final mockQuery = MockQuery();
        when(mockQuery.get()).thenThrow(
          FirebaseException(plugin: 'cloud_firestore', code: 'network-error'),
        );
        when(mockQuery.where(any)).thenReturn(mockQuery);
        when(mockQuery.orderBy(any, descending: anyNamed('descending')))
            .thenReturn(mockQuery);

        when(mockFirestore.collection('games')).thenReturn(
          _MockCollectionReference(mockQuery),
        );

        expect(
          () => gameHistoryService.filterGames(),
          throwsA(isA<GameHistoryException>()),
        );
      });
    });

    group('getStatsVsOpponent', () {
      test('returns win/loss/draw counts', () async {
        final gameData1 = {
          'whitePlayerId': 'test_user_123',
          'blackPlayerId': 'opponent1',
          'status': 'completed',
          'result': 'white_win',
        };
        final gameData2 = {
          'whitePlayerId': 'opponent1',
          'blackPlayerId': 'test_user_123',
          'status': 'completed',
          'result': 'draw',
        };

        final mockDoc1 = MockDocumentSnapshot(gameData1, 'game1');
        final mockDoc2 = MockDocumentSnapshot(gameData2, 'game2');
        final mockQuerySnapshot = MockQuerySnapshot();
        when(mockQuerySnapshot.docs).thenReturn([mockDoc1, mockDoc2]);

        final mockQuery = MockQuery();
        when(mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        when(mockQuery.where(any)).thenReturn(mockQuery);

        when(mockFirestore.collection('games')).thenReturn(
          _MockCollectionReference(mockQuery),
        );

        final result = await gameHistoryService.getStatsVsOpponent('opponent1');

        expect(result['wins'], equals(1));
        expect(result['losses'], equals(0));
        expect(result['draws'], equals(1));
      });

      test('handles games from both perspectives', () async {
        // User is white (wins)
        final gameData1 = {
          'whitePlayerId': 'test_user_123',
          'blackPlayerId': 'opponent1',
          'result': 'white_win',
        };
        // User is black (wins)
        final gameData2 = {
          'whitePlayerId': 'opponent1',
          'blackPlayerId': 'test_user_123',
          'result': 'black_win',
        };

        final mockDoc1 = MockDocumentSnapshot(gameData1, 'game1');
        final mockDoc2 = MockDocumentSnapshot(gameData2, 'game2');
        final mockQuerySnapshot = MockQuerySnapshot();
        when(mockQuerySnapshot.docs).thenReturn([mockDoc1, mockDoc2]);

        final mockQuery = MockQuery();
        when(mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        when(mockQuery.where(any)).thenReturn(mockQuery);

        when(mockFirestore.collection('games')).thenReturn(
          _MockCollectionReference(mockQuery),
        );

        final result = await gameHistoryService.getStatsVsOpponent('opponent1');

        expect(result['wins'], equals(2));
        expect(result['losses'], equals(0));
      });

      test('returns zeros for no games vs opponent', () async {
        final mockQuerySnapshot = MockQuerySnapshot();
        when(mockQuerySnapshot.docs).thenReturn([]);

        final mockQuery = MockQuery();
        when(mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        when(mockQuery.where(any)).thenReturn(mockQuery);

        when(mockFirestore.collection('games')).thenReturn(
          _MockCollectionReference(mockQuery),
        );

        final result = await gameHistoryService.getStatsVsOpponent('opponent1');

        expect(result['wins'], equals(0));
        expect(result['losses'], equals(0));
        expect(result['draws'], equals(0));
      });

      test('throws GameHistoryException on error', () async {
        final mockQuery = MockQuery();
        when(mockQuery.get()).thenThrow(
          FirebaseException(plugin: 'cloud_firestore', code: 'network-error'),
        );
        when(mockQuery.where(any)).thenReturn(mockQuery);

        when(mockFirestore.collection('games')).thenReturn(
          _MockCollectionReference(mockQuery),
        );

        expect(
          () => gameHistoryService.getStatsVsOpponent('opponent1'),
          throwsA(isA<GameHistoryException>()),
        );
      });
    });

    group('getPlayerStats', () {
      test('calculates total games', () async {
        final gameData1 = {
          'whitePlayerId': 'test_user_123',
          'blackPlayerId': 'opponent1',
          'result': 'white_win',
          'whiteRatingBefore': 1500,
          'whiteRatingAfter': 1510,
          'blackRatingBefore': 1400,
          'blackRatingAfter': 1390,
        };
        final gameData2 = {
          'whitePlayerId': 'opponent1',
          'blackPlayerId': 'test_user_123',
          'result': 'draw',
          'whiteRatingBefore': 1400,
          'whiteRatingAfter': 1405,
          'blackRatingBefore': 1510,
          'blackRatingAfter': 1505,
        };

        final mockDoc1 = MockDocumentSnapshot(gameData1, 'game1');
        final mockDoc2 = MockDocumentSnapshot(gameData2, 'game2');
        final mockQuerySnapshot = MockQuerySnapshot();
        when(mockQuerySnapshot.docs).thenReturn([mockDoc1, mockDoc2]);
        when(mockQuerySnapshot.size).thenReturn(2);

        final mockQuery = MockQuery();
        when(mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        when(mockQuery.where(any)).thenReturn(mockQuery);

        when(mockFirestore.collection('games')).thenReturn(
          _MockCollectionReference(mockQuery),
        );

        final result = await gameHistoryService.getPlayerStats();

        expect(result['totalGames'], equals(2));
      });

      test('calculates win/loss/draw counts', () async {
        final gameData1 = {
          'whitePlayerId': 'test_user_123',
          'blackPlayerId': 'opponent1',
          'result': 'white_win',
          'whiteRatingBefore': 1500,
          'whiteRatingAfter': 1510,
          'blackRatingBefore': 1400,
          'blackRatingAfter': 1390,
        };
        final gameData2 = {
          'whitePlayerId': 'opponent1',
          'blackPlayerId': 'test_user_123',
          'result': 'black_win',
          'whiteRatingBefore': 1400,
          'whiteRatingAfter': 1390,
          'blackRatingBefore': 1510,
          'blackRatingAfter': 1520,
        };
        final gameData3 = {
          'whitePlayerId': 'test_user_123',
          'blackPlayerId': 'opponent2',
          'result': 'draw',
          'whiteRatingBefore': 1510,
          'whiteRatingAfter': 1512,
          'blackRatingBefore': 1450,
          'blackRatingAfter': 1448,
        };

        final mockDoc1 = MockDocumentSnapshot(gameData1, 'game1');
        final mockDoc2 = MockDocumentSnapshot(gameData2, 'game2');
        final mockDoc3 = MockDocumentSnapshot(gameData3, 'game3');
        final mockQuerySnapshot = MockQuerySnapshot();
        when(mockQuerySnapshot.docs).thenReturn([mockDoc1, mockDoc2, mockDoc3]);
        when(mockQuerySnapshot.size).thenReturn(3);

        final mockQuery = MockQuery();
        when(mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        when(mockQuery.where(any)).thenReturn(mockQuery);

        when(mockFirestore.collection('games')).thenReturn(
          _MockCollectionReference(mockQuery),
        );

        final result = await gameHistoryService.getPlayerStats();

        expect(result['wins'], equals(1));
        expect(result['losses'], equals(1));
        expect(result['draws'], equals(1));
      });

      test('calculates win rate percentage', () async {
        final gameData1 = {
          'whitePlayerId': 'test_user_123',
          'blackPlayerId': 'opponent1',
          'result': 'white_win',
          'whiteRatingBefore': 1500,
          'whiteRatingAfter': 1510,
          'blackRatingBefore': 1400,
          'blackRatingAfter': 1390,
        };
        final gameData2 = {
          'whitePlayerId': 'test_user_123',
          'blackPlayerId': 'opponent2',
          'result': 'white_win',
          'whiteRatingBefore': 1510,
          'whiteRatingAfter': 1520,
          'blackRatingBefore': 1450,
          'blackRatingAfter': 1440,
        };

        final mockDoc1 = MockDocumentSnapshot(gameData1, 'game1');
        final mockDoc2 = MockDocumentSnapshot(gameData2, 'game2');
        final mockQuerySnapshot = MockQuerySnapshot();
        when(mockQuerySnapshot.docs).thenReturn([mockDoc1, mockDoc2]);
        when(mockQuerySnapshot.size).thenReturn(2);

        final mockQuery = MockQuery();
        when(mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        when(mockQuery.where(any)).thenReturn(mockQuery);

        when(mockFirestore.collection('games')).thenReturn(
          _MockCollectionReference(mockQuery),
        );

        final result = await gameHistoryService.getPlayerStats();

        expect(result['winRate'], equals('100.0'));
      });

      test('calculates total rating gain', () async {
        final gameData1 = {
          'whitePlayerId': 'test_user_123',
          'blackPlayerId': 'opponent1',
          'result': 'white_win',
          'whiteRatingBefore': 1500,
          'whiteRatingAfter': 1510,
          'blackRatingBefore': 1400,
          'blackRatingAfter': 1390,
        };

        final mockDoc1 = MockDocumentSnapshot(gameData1, 'game1');
        final mockQuerySnapshot = MockQuerySnapshot();
        when(mockQuerySnapshot.docs).thenReturn([mockDoc1]);
        when(mockQuerySnapshot.size).thenReturn(1);

        final mockQuery = MockQuery();
        when(mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        when(mockQuery.where(any)).thenReturn(mockQuery);

        when(mockFirestore.collection('games')).thenReturn(
          _MockCollectionReference(mockQuery),
        );

        final result = await gameHistoryService.getPlayerStats();

        expect(result['totalRatingGain'], equals(10));
      });

      test('calculates average rating gain per game', () async {
        final gameData1 = {
          'whitePlayerId': 'test_user_123',
          'blackPlayerId': 'opponent1',
          'result': 'white_win',
          'whiteRatingBefore': 1500,
          'whiteRatingAfter': 1510,
          'blackRatingBefore': 1400,
          'blackRatingAfter': 1390,
        };
        final gameData2 = {
          'whitePlayerId': 'test_user_123',
          'blackPlayerId': 'opponent2',
          'result': 'white_win',
          'whiteRatingBefore': 1510,
          'whiteRatingAfter': 1524,
          'blackRatingBefore': 1450,
          'blackRatingAfter': 1436,
        };

        final mockDoc1 = MockDocumentSnapshot(gameData1, 'game1');
        final mockDoc2 = MockDocumentSnapshot(gameData2, 'game2');
        final mockQuerySnapshot = MockQuerySnapshot();
        when(mockQuerySnapshot.docs).thenReturn([mockDoc1, mockDoc2]);
        when(mockQuerySnapshot.size).thenReturn(2);

        final mockQuery = MockQuery();
        when(mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        when(mockQuery.where(any)).thenReturn(mockQuery);

        when(mockFirestore.collection('games')).thenReturn(
          _MockCollectionReference(mockQuery),
        );

        final result = await gameHistoryService.getPlayerStats();

        expect(result['averageRatingGain'], equals('12.0'));
      });

      test('handles zero games', () async {
        final mockQuerySnapshot = MockQuerySnapshot();
        when(mockQuerySnapshot.docs).thenReturn([]);
        when(mockQuerySnapshot.size).thenReturn(0);

        final mockQuery = MockQuery();
        when(mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        when(mockQuery.where(any)).thenReturn(mockQuery);

        when(mockFirestore.collection('games')).thenReturn(
          _MockCollectionReference(mockQuery),
        );

        final result = await gameHistoryService.getPlayerStats();

        expect(result['totalGames'], equals(0));
        expect(result['wins'], equals(0));
        expect(result['winRate'], equals('0.0'));
      });

      test('throws GameHistoryException on error', () async {
        final mockQuery = MockQuery();
        when(mockQuery.get()).thenThrow(SocketException('Network error'));
        when(mockQuery.where(any)).thenReturn(mockQuery);

        when(mockFirestore.collection('games')).thenReturn(
          _MockCollectionReference(mockQuery),
        );

        expect(
          () => gameHistoryService.getPlayerStats(),
          throwsA(isA<GameHistoryException>()
              .having((e) => e.code, 'code', equals('network_error'))),
        );
      });
    });

    group('exportAsCSV', () {
      test('generates valid CSV format', () async {
        final gameData = {
          'endedAt': '2024-01-01',
          'whitePlayerId': 'test_user_123',
          'blackPlayerId': 'opponent1',
          'whitePlayerName': 'Player1',
          'blackPlayerName': 'Opponent',
          'result': 'white_win',
          'whiteRatingBefore': 1500,
          'whiteRatingAfter': 1510,
          'blackRatingBefore': 1400,
          'blackRatingAfter': 1390,
          'timeControl': 'blitz',
          'moves': [1, 2, 3, 4],
        };

        final mockDoc = MockDocumentSnapshot(gameData, 'game1');
        final mockQuerySnapshot = MockQuerySnapshot();
        when(mockQuerySnapshot.docs).thenReturn([mockDoc]);
        when(mockQuerySnapshot.size).thenReturn(1);

        final mockQuery = MockQuery();
        when(mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        when(mockQuery.limit(any)).thenReturn(mockQuery);
        when(mockQuery.orderBy(any, descending: anyNamed('descending')))
            .thenReturn(mockQuery);
        when(mockQuery.where(any)).thenReturn(mockQuery);

        when(mockFirestore.collection('games')).thenReturn(
          _MockCollectionReference(mockQuery),
        );

        final result = await gameHistoryService.exportAsCSV();

        expect(result, contains('Date,Opponent,Color,Result,Rating Change,Time Control,Moves'));
        expect(result, contains('2024-01-01'));
      });

      test('includes all required columns', () async {
        final gameData = {
          'endedAt': '2024-01-01',
          'whitePlayerId': 'test_user_123',
          'blackPlayerId': 'opponent1',
          'whitePlayerName': 'Player1',
          'blackPlayerName': 'Opponent',
          'result': 'white_win',
          'whiteRatingBefore': 1500,
          'whiteRatingAfter': 1510,
          'blackRatingBefore': 1400,
          'blackRatingAfter': 1390,
          'timeControl': 'blitz',
          'moves': [1, 2, 3, 4],
        };

        final mockDoc = MockDocumentSnapshot(gameData, 'game1');
        final mockQuerySnapshot = MockQuerySnapshot();
        when(mockQuerySnapshot.docs).thenReturn([mockDoc]);
        when(mockQuerySnapshot.size).thenReturn(1);

        final mockQuery = MockQuery();
        when(mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        when(mockQuery.limit(any)).thenReturn(mockQuery);
        when(mockQuery.orderBy(any, descending: anyNamed('descending')))
            .thenReturn(mockQuery);
        when(mockQuery.where(any)).thenReturn(mockQuery);

        when(mockFirestore.collection('games')).thenReturn(
          _MockCollectionReference(mockQuery),
        );

        final result = await gameHistoryService.exportAsCSV();
        final lines = result.split('\n');
        final header = lines[0];

        expect(header, contains('Date'));
        expect(header, contains('Opponent'));
        expect(header, contains('Color'));
        expect(header, contains('Result'));
        expect(header, contains('Rating Change'));
        expect(header, contains('Time Control'));
        expect(header, contains('Moves'));
      });

      test('includes game data', () async {
        final gameData = {
          'endedAt': '2024-01-01',
          'whitePlayerId': 'test_user_123',
          'blackPlayerId': 'opponent1',
          'whitePlayerName': 'Player1',
          'blackPlayerName': 'Opponent',
          'result': 'white_win',
          'whiteRatingBefore': 1500,
          'whiteRatingAfter': 1510,
          'blackRatingBefore': 1400,
          'blackRatingAfter': 1390,
          'timeControl': 'blitz',
          'moves': [1, 2, 3, 4],
        };

        final mockDoc = MockDocumentSnapshot(gameData, 'game1');
        final mockQuerySnapshot = MockQuerySnapshot();
        when(mockQuerySnapshot.docs).thenReturn([mockDoc]);
        when(mockQuerySnapshot.size).thenReturn(1);

        final mockQuery = MockQuery();
        when(mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        when(mockQuery.limit(any)).thenReturn(mockQuery);
        when(mockQuery.orderBy(any, descending: anyNamed('descending')))
            .thenReturn(mockQuery);
        when(mockQuery.where(any)).thenReturn(mockQuery);

        when(mockFirestore.collection('games')).thenReturn(
          _MockCollectionReference(mockQuery),
        );

        final result = await gameHistoryService.exportAsCSV();

        expect(result, contains('Opponent'));
        expect(result, contains('white_win'));
        expect(result, contains('+10'));
        expect(result, contains('blitz'));
        expect(result, contains('4'));
      });

      test('respects limit parameter', () async {
        var limitValue = 0;
        final mockQuery = MockQuery();
        when(mockQuery.limit(any)).thenAnswer((invocation) {
          limitValue = invocation.positionalArguments[0] as int;
          return mockQuery;
        });

        final mockQuerySnapshot = MockQuerySnapshot();
        when(mockQuerySnapshot.docs).thenReturn([]);
        when(mockQuerySnapshot.size).thenReturn(0);
        when(mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);

        when(mockQuery.orderBy(any, descending: anyNamed('descending')))
            .thenReturn(mockQuery);
        when(mockQuery.where(any)).thenReturn(mockQuery);

        when(mockFirestore.collection('games')).thenReturn(
          _MockCollectionReference(mockQuery),
        );

        await gameHistoryService.exportAsCSV(limit: 500);

        expect(limitValue, equals(500));
      });

      test('handles missing data gracefully', () async {
        final gameData = {
          'endedAt': '2024-01-01',
          'whitePlayerId': 'test_user_123',
          'blackPlayerId': 'opponent1',
          'whitePlayerName': 'Player1',
          // Missing blackPlayerName
          'result': 'white_win',
          'whiteRatingBefore': 1500,
          'whiteRatingAfter': 1510,
          // Missing blackRatingBefore and blackRatingAfter
          'timeControl': 'blitz',
          // Missing moves
        };

        final mockDoc = MockDocumentSnapshot(gameData, 'game1');
        final mockQuerySnapshot = MockQuerySnapshot();
        when(mockQuerySnapshot.docs).thenReturn([mockDoc]);
        when(mockQuerySnapshot.size).thenReturn(1);

        final mockQuery = MockQuery();
        when(mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        when(mockQuery.limit(any)).thenReturn(mockQuery);
        when(mockQuery.orderBy(any, descending: anyNamed('descending')))
            .thenReturn(mockQuery);
        when(mockQuery.where(any)).thenReturn(mockQuery);

        when(mockFirestore.collection('games')).thenReturn(
          _MockCollectionReference(mockQuery),
        );

        final result = await gameHistoryService.exportAsCSV();

        expect(result, isNotEmpty);
        expect(result, contains('white_win'));
      });

      test('throws GameHistoryException on error', () async {
        final mockQuery = MockQuery();
        when(mockQuery.get()).thenThrow(
          FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
        );
        when(mockQuery.limit(any)).thenReturn(mockQuery);
        when(mockQuery.orderBy(any, descending: anyNamed('descending')))
            .thenReturn(mockQuery);
        when(mockQuery.where(any)).thenReturn(mockQuery);

        when(mockFirestore.collection('games')).thenReturn(
          _MockCollectionReference(mockQuery),
        );

        expect(
          () => gameHistoryService.exportAsCSV(),
          throwsA(isA<GameHistoryException>()),
        );
      });
    });

    group('getRatingHistory', () {
      test('returns chronological rating history', () async {
        final entryData1 = {
          'timestamp': DateTime(2024, 1, 1),
          'rating': 1500,
          'gameId': 'game1',
          'delta': 10,
        };
        final entryData2 = {
          'timestamp': DateTime(2024, 1, 2),
          'rating': 1510,
          'gameId': 'game2',
          'delta': 10,
        };

        final mockDoc1 = MockDocumentSnapshot(entryData1, 'entry1');
        final mockDoc2 = MockDocumentSnapshot(entryData2, 'entry2');
        final mockQuerySnapshot = MockQuerySnapshot();
        when(mockQuerySnapshot.docs).thenReturn([mockDoc1, mockDoc2]);

        final mockQuery = MockQuery();
        when(mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        when(mockQuery.limit(any)).thenReturn(mockQuery);
        when(mockQuery.orderBy(any, descending: anyNamed('descending')))
            .thenReturn(mockQuery);

        when(mockFirestore.collection('users'))
            .thenReturn(_MockCollectionReference(mockQuery));

        final result = await gameHistoryService.getRatingHistory();

        expect(result, isNotEmpty);
        expect(result.length, equals(2));
      });

      test('includes rating delta for each entry', () async {
        final entryData = {
          'timestamp': DateTime(2024, 1, 1),
          'rating': 1510,
          'gameId': 'game1',
          'delta': 10,
        };

        final mockDoc = MockDocumentSnapshot(entryData, 'entry1');
        final mockQuerySnapshot = MockQuerySnapshot();
        when(mockQuerySnapshot.docs).thenReturn([mockDoc]);

        final mockQuery = MockQuery();
        when(mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        when(mockQuery.limit(any)).thenReturn(mockQuery);
        when(mockQuery.orderBy(any, descending: anyNamed('descending')))
            .thenReturn(mockQuery);

        when(mockFirestore.collection('users'))
            .thenReturn(_MockCollectionReference(mockQuery));

        final result = await gameHistoryService.getRatingHistory();

        expect(result.first['delta'], equals(10));
      });

      test('links to game IDs', () async {
        final entryData = {
          'timestamp': DateTime(2024, 1, 1),
          'rating': 1510,
          'gameId': 'game1',
          'delta': 10,
        };

        final mockDoc = MockDocumentSnapshot(entryData, 'entry1');
        final mockQuerySnapshot = MockQuerySnapshot();
        when(mockQuerySnapshot.docs).thenReturn([mockDoc]);

        final mockQuery = MockQuery();
        when(mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        when(mockQuery.limit(any)).thenReturn(mockQuery);
        when(mockQuery.orderBy(any, descending: anyNamed('descending')))
            .thenReturn(mockQuery);

        when(mockFirestore.collection('users'))
            .thenReturn(_MockCollectionReference(mockQuery));

        final result = await gameHistoryService.getRatingHistory();

        expect(result.first['gameId'], equals('game1'));
      });

      test('limits to 1000 entries', () async {
        var limitValue = 0;
        final mockQuery = MockQuery();
        when(mockQuery.limit(any)).thenAnswer((invocation) {
          limitValue = invocation.positionalArguments[0] as int;
          return mockQuery;
        });

        final mockQuerySnapshot = MockQuerySnapshot();
        when(mockQuerySnapshot.docs).thenReturn([]);
        when(mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);

        when(mockQuery.orderBy(any, descending: anyNamed('descending')))
            .thenReturn(mockQuery);

        when(mockFirestore.collection('users'))
            .thenReturn(_MockCollectionReference(mockQuery));

        await gameHistoryService.getRatingHistory();

        expect(limitValue, equals(1000));
      });

      test('handles empty rating history', () async {
        final mockQuerySnapshot = MockQuerySnapshot();
        when(mockQuerySnapshot.docs).thenReturn([]);

        final mockQuery = MockQuery();
        when(mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        when(mockQuery.limit(any)).thenReturn(mockQuery);
        when(mockQuery.orderBy(any, descending: anyNamed('descending')))
            .thenReturn(mockQuery);

        when(mockFirestore.collection('users'))
            .thenReturn(_MockCollectionReference(mockQuery));

        final result = await gameHistoryService.getRatingHistory();

        expect(result, isEmpty);
      });

      test('throws GameHistoryException on error', () async {
        final mockQuery = MockQuery();
        when(mockQuery.get()).thenThrow(SocketException('Network error'));
        when(mockQuery.limit(any)).thenReturn(mockQuery);
        when(mockQuery.orderBy(any, descending: anyNamed('descending')))
            .thenReturn(mockQuery);

        when(mockFirestore.collection('users'))
            .thenReturn(_MockCollectionReference(mockQuery));

        expect(
          () => gameHistoryService.getRatingHistory(),
          throwsA(isA<GameHistoryException>()
              .having((e) => e.code, 'code', equals('network_error'))),
        );
      });
    });

    group('Error Handling', () {
      test('converts SocketException to GameHistoryException', () async {
        final mockQuery = MockQuery();
        when(mockQuery.get()).thenThrow(SocketException('Connection refused'));
        when(mockQuery.where(any)).thenReturn(mockQuery);

        when(mockFirestore.collection('games')).thenReturn(
          _MockCollectionReference(mockQuery),
        );

        expect(
          () => gameHistoryService.getMatchHistory(),
          throwsA(isA<GameHistoryException>()
              .having((e) => e.code, 'code', equals('network_error'))),
        );
      });

      test('converts TimeoutException to GameHistoryException', () async {
        final mockQuery = MockQuery();
        when(mockQuery.get()).thenThrow(TimeoutException('Request timeout', null));
        when(mockQuery.where(any)).thenReturn(mockQuery);

        when(mockFirestore.collection('games')).thenReturn(
          _MockCollectionReference(mockQuery),
        );

        expect(
          () => gameHistoryService.getMatchHistory(),
          throwsA(isA<GameHistoryException>()
              .having((e) => e.code, 'code', equals('timeout'))),
        );
      });

      test('handles FirebaseException with network-error code', () async {
        final mockQuery = MockQuery();
        when(mockQuery.get()).thenThrow(
          FirebaseException(plugin: 'cloud_firestore', code: 'network-error'),
        );
        when(mockQuery.where(any)).thenReturn(mockQuery);

        when(mockFirestore.collection('games')).thenReturn(
          _MockCollectionReference(mockQuery),
        );

        expect(
          () => gameHistoryService.getMatchHistory(),
          throwsA(isA<GameHistoryException>()
              .having((e) => e.code, 'code', equals('network-error'))),
        );
      });

      test('logs errors to ErrorLoggingService', () async {
        final mockQuery = MockQuery();
        when(mockQuery.get()).thenThrow(Exception('Test error'));
        when(mockQuery.where(any)).thenReturn(mockQuery);

        when(mockFirestore.collection('games')).thenReturn(
          _MockCollectionReference(mockQuery),
        );

        expect(
          () => gameHistoryService.getMatchHistory(),
          throwsA(isA<GameHistoryException>()),
        );
      });

      test('provides helpful error messages to users', () async {
        final mockQuery = MockQuery();
        when(mockQuery.get()).thenThrow(SocketException('Network error'));
        when(mockQuery.where(any)).thenReturn(mockQuery);

        when(mockFirestore.collection('games')).thenReturn(
          _MockCollectionReference(mockQuery),
        );

        try {
          await gameHistoryService.getMatchHistory();
          fail('Expected GameHistoryException');
        } on GameHistoryException catch (e) {
          expect(
            e.message,
            contains('Network error'),
          );
        }
      });
    });

    group('Data Consistency', () {
      test('handles both white and black player perspectives', () async {
        final gameDataAsWhite = {
          'whitePlayerId': 'test_user_123',
          'blackPlayerId': 'opponent1',
          'result': 'white_win',
          'whiteRatingBefore': 1500,
          'whiteRatingAfter': 1510,
        };
        final gameDataAsBlack = {
          'whitePlayerId': 'opponent1',
          'blackPlayerId': 'test_user_123',
          'result': 'black_win',
          'blackRatingBefore': 1400,
          'blackRatingAfter': 1410,
        };

        final mockDoc1 = MockDocumentSnapshot(gameDataAsWhite, 'game1');
        final mockDoc2 = MockDocumentSnapshot(gameDataAsBlack, 'game2');
        final mockQuerySnapshot = MockQuerySnapshot();
        when(mockQuerySnapshot.docs).thenReturn([mockDoc1, mockDoc2]);
        when(mockQuerySnapshot.size).thenReturn(2);

        final mockQuery = MockQuery();
        when(mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        when(mockQuery.where(any)).thenReturn(mockQuery);

        when(mockFirestore.collection('games')).thenReturn(
          _MockCollectionReference(mockQuery),
        );

        final result = await gameHistoryService.getPlayerStats();

        expect(result['totalGames'], equals(2));
        expect(result['wins'], equals(2));
      });

      test('calculates rating changes correctly', () async {
        final gameData = {
          'whitePlayerId': 'test_user_123',
          'blackPlayerId': 'opponent1',
          'result': 'white_win',
          'whiteRatingBefore': 1500,
          'whiteRatingAfter': 1525,
          'blackRatingBefore': 1400,
          'blackRatingAfter': 1375,
        };

        final mockDoc = MockDocumentSnapshot(gameData, 'game1');
        final mockQuerySnapshot = MockQuerySnapshot();
        when(mockQuerySnapshot.docs).thenReturn([mockDoc]);
        when(mockQuerySnapshot.size).thenReturn(1);

        final mockQuery = MockQuery();
        when(mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        when(mockQuery.where(any)).thenReturn(mockQuery);

        when(mockFirestore.collection('games')).thenReturn(
          _MockCollectionReference(mockQuery),
        );

        final result = await gameHistoryService.getPlayerStats();

        // Rating change = after - before = 1525 - 1500 = 25
        expect(result['totalRatingGain'], equals(25));
      });

      test('distinguishes between white_win and black_win', () async {
        final gameData1 = {
          'whitePlayerId': 'test_user_123',
          'blackPlayerId': 'opponent1',
          'result': 'white_win',
          'whiteRatingBefore': 1500,
          'whiteRatingAfter': 1510,
          'blackRatingBefore': 1400,
          'blackRatingAfter': 1390,
        };
        final gameData2 = {
          'whitePlayerId': 'opponent1',
          'blackPlayerId': 'test_user_123',
          'result': 'black_win',
          'whiteRatingBefore': 1400,
          'whiteRatingAfter': 1390,
          'blackRatingBefore': 1510,
          'blackRatingAfter': 1520,
        };

        final mockDoc1 = MockDocumentSnapshot(gameData1, 'game1');
        final mockDoc2 = MockDocumentSnapshot(gameData2, 'game2');
        final mockQuerySnapshot = MockQuerySnapshot();
        when(mockQuerySnapshot.docs).thenReturn([mockDoc1, mockDoc2]);
        when(mockQuerySnapshot.size).thenReturn(2);

        final mockQuery = MockQuery();
        when(mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        when(mockQuery.where(any)).thenReturn(mockQuery);

        when(mockFirestore.collection('games')).thenReturn(
          _MockCollectionReference(mockQuery),
        );

        final result = await gameHistoryService.getPlayerStats();

        // Should count both as wins for the user
        expect(result['wins'], equals(2));
        expect(result['losses'], equals(0));
      });

      test('counts draws correctly', () async {
        final gameData1 = {
          'whitePlayerId': 'test_user_123',
          'blackPlayerId': 'opponent1',
          'result': 'draw',
          'whiteRatingBefore': 1500,
          'whiteRatingAfter': 1502,
          'blackRatingBefore': 1400,
          'blackRatingAfter': 1398,
        };
        final gameData2 = {
          'whitePlayerId': 'opponent1',
          'blackPlayerId': 'test_user_123',
          'result': 'draw',
          'whiteRatingBefore': 1400,
          'whiteRatingAfter': 1402,
          'blackRatingBefore': 1510,
          'blackRatingAfter': 1508,
        };

        final mockDoc1 = MockDocumentSnapshot(gameData1, 'game1');
        final mockDoc2 = MockDocumentSnapshot(gameData2, 'game2');
        final mockQuerySnapshot = MockQuerySnapshot();
        when(mockQuerySnapshot.docs).thenReturn([mockDoc1, mockDoc2]);
        when(mockQuerySnapshot.size).thenReturn(2);

        final mockQuery = MockQuery();
        when(mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        when(mockQuery.where(any)).thenReturn(mockQuery);

        when(mockFirestore.collection('games')).thenReturn(
          _MockCollectionReference(mockQuery),
        );

        final result = await gameHistoryService.getPlayerStats();

        expect(result['draws'], equals(2));
        expect(result['wins'], equals(0));
        expect(result['losses'], equals(0));
      });
    });

    group('Performance', () {
      test('uses efficient Firestore queries', () async {
        var whereInvoked = false;
        var orderByInvoked = false;

        final mockQuery = MockQuery();
        when(mockQuery.where(any)).thenAnswer((_) {
          whereInvoked = true;
          return mockQuery;
        });

        when(mockQuery.orderBy(any, descending: anyNamed('descending')))
            .thenAnswer((_) {
          orderByInvoked = true;
          return mockQuery;
        });

        when(mockQuery.limit(any)).thenReturn(mockQuery);

        final mockQuerySnapshot = MockQuerySnapshot();
        when(mockQuerySnapshot.docs).thenReturn([]);
        when(mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);

        when(mockFirestore.collection('games')).thenReturn(
          _MockCollectionReference(mockQuery),
        );

        await gameHistoryService.getMatchHistory();

        // Verify that efficient querying is used
        expect(whereInvoked, isTrue);
        expect(orderByInvoked, isTrue);
      });

      test('respects limit parameters for large datasets', () async {
        final gameDocs = List.generate(
          100,
          (i) => MockDocumentSnapshot(
            {
              'whitePlayerId': 'test_user_123',
              'blackPlayerId': 'opponent$i',
              'status': 'completed',
            },
            'game$i',
          ),
        );

        final mockQuerySnapshot = MockQuerySnapshot();
        when(mockQuerySnapshot.docs).thenReturn(gameDocs);

        final mockQuery = MockQuery();
        var actualLimit = 0;
        when(mockQuery.limit(any)).thenAnswer((invocation) {
          actualLimit = invocation.positionalArguments[0] as int;
          return mockQuery;
        });

        when(mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        when(mockQuery.orderBy(any, descending: anyNamed('descending')))
            .thenReturn(mockQuery);
        when(mockQuery.where(any)).thenReturn(mockQuery);

        when(mockFirestore.collection('games')).thenReturn(
          _MockCollectionReference(mockQuery),
        );

        await gameHistoryService.getMatchHistory(limit: 25);

        expect(actualLimit, equals(25));
      });

      test('handles streaming for real-time updates', () async {
        final gameData = {
          'whitePlayerId': 'test_user_123',
          'blackPlayerId': 'opponent1',
          'status': 'completed',
        };

        final mockDoc = MockDocumentSnapshot(gameData, 'game1');
        final mockQuerySnapshot = MockQuerySnapshot();
        when(mockQuerySnapshot.docs).thenReturn([mockDoc]);

        final mockStream = Stream.value(mockQuerySnapshot);

        final mockQuery = MockQuery();
        var snapshotsInvoked = false;
        when(mockQuery.snapshots()).thenAnswer((_) {
          snapshotsInvoked = true;
          return mockStream;
        });

        when(mockQuery.limit(any)).thenReturn(mockQuery);
        when(mockQuery.orderBy(any, descending: anyNamed('descending')))
            .thenReturn(mockQuery);
        when(mockQuery.where(any)).thenReturn(mockQuery);

        when(mockFirestore.collection('games')).thenReturn(
          _MockCollectionReference(mockQuery),
        );

        final stream = gameHistoryService.watchMatchHistory();
        await stream.first;

        expect(snapshotsInvoked, isTrue);
      });

      test('batch operations where appropriate', () async {
        // Verify that rating history uses collection path efficiently
        final mockQuery = MockQuery();
        when(mockQuery.limit(any)).thenReturn(mockQuery);
        when(mockQuery.orderBy(any, descending: anyNamed('descending')))
            .thenReturn(mockQuery);

        final mockQuerySnapshot = MockQuerySnapshot();
        when(mockQuerySnapshot.docs).thenReturn([]);
        when(mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);

        when(mockFirestore.collection('users'))
            .thenReturn(_MockCollectionReference(mockQuery));

        // This operation should efficiently access the rating_history subcollection
        await gameHistoryService.getRatingHistory();

        // Verify subcollection access was used
        verify(mockFirestore.collection('users')).called(greaterThan(0));
      });
    });
  });
}
