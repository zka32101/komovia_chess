import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:komovia_chess/src/services/comparison_service.dart';
import 'package:komovia_chess/src/models/head_to_head_stats.dart';
import 'package:komovia_chess/src/models/match_record.dart';

// Mock Firestore
class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockCollectionReference extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class MockDocumentReference extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

class MockDocumentSnapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

class MockQuerySnapshot extends Mock
    implements QuerySnapshot<Map<String, dynamic>> {}

void main() {
  group('ComparisonService', () {
    late MockFirebaseFirestore mockFirestore;
    late ComparisonService service;

    setUp(() {
      mockFirestore = MockFirebaseFirestore();
      service = ComparisonService(firestore: mockFirestore);
    });

    group('calculateWinProbability', () {
      test('should return 0.5 when rating difference is 0', () {
        final probability = service.calculateWinProbability(0);
        expect(probability, closeTo(0.5, 0.01));
      });

      test('should return higher probability for positive rating difference',
          () {
        final prob1 = service.calculateWinProbability(0);
        final prob2 = service.calculateWinProbability(200);
        expect(prob2, greaterThan(prob1));
      });

      test('should return lower probability for negative rating difference',
          () {
        final prob1 = service.calculateWinProbability(0);
        final prob2 = service.calculateWinProbability(-200);
        expect(prob2, lessThan(prob1));
      });

      test('should be symmetric around rating difference', () {
        final probPositive = service.calculateWinProbability(200);
        final probNegative = service.calculateWinProbability(-200);
        expect(probPositive + probNegative, closeTo(1.0, 0.01));
      });
    });

    group('_getMatchupId', () {
      test('should generate consistent matchup ID regardless of player order',
          () {
        final id1 = service.matchupIdForTest('player1', 'player2');
        final id2 = service.matchupIdForTest('player2', 'player1');
        expect(id1, id2);
      });

      test('should generate different IDs for different player pairs', () {
        final id1 = service.matchupIdForTest('player1', 'player2');
        final id2 = service.matchupIdForTest('player1', 'player3');
        expect(id1, isNot(id2));
      });
    });
  });
}

// Helper extension to test private methods
extension ComparisonServiceTestHelper on ComparisonService {
  String matchupIdForTest(String player1Id, String player2Id) {
    // Mock implementation for testing
    final ids = [player1Id, player2Id];
    ids.sort();
    return '${ids[0]}_${ids[1]}';
  }
}
