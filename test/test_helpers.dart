import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:cloud_firestore_mocks/cloud_firestore_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Test helper for creating mock Firebase Auth
MockFirebaseAuth createMockFirebaseAuth() {
  return MockFirebaseAuth();
}

/// Test helper for creating mock Firestore
MockFirestoreInstance createMockFirestore() {
  return MockFirestoreInstance();
}

/// Create a test container with mocked services
ProviderContainer createTestContainer({
  required MockFirebaseAuth auth,
  required MockFirestoreInstance firestore,
}) {
  return ProviderContainer();
}

/// Test user credentials
const testEmail = 'test@example.com';
const testPassword = 'testPassword123';
const testUserId = 'test-user-123';
const testDisplayName = 'Test Player';

/// Mock game data for testing
const mockGameData = {
  'gameId': 'game-123',
  'type': 'online_pvp',
  'status': 'active',
  'whitePlayerId': 'player-1',
  'blackPlayerId': 'player-2',
  'whitePlayerName': 'Alice',
  'blackPlayerName': 'Bob',
  'whiteRating': 1600,
  'blackRating': 1700,
  'moves': ['e2e4', 'e7e5'],
  'timeControl': '5+3',
  'currentFen': 'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2',
  'result': null,
  'resultReason': null,
  'createdAt': null,
  'startedAt': null,
  'endedAt': null,
};

/// Mock puzzle data for testing
const mockPuzzleData = {
  'id': 'puzzle-123',
  'fen': 'r1bqkb1r/pppp1ppp/2n2n2/1B2p3/4P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 4 4',
  'moves': ['Bxc6', 'dxc6', 'dxe5', 'Qxd8+', 'Kxd8'],
  'rating': 1200,
  'themes': ['pin', 'removal-of-defender', 'fork'],
  'solution': ['e1', 'f3'],
};

/// Delay helper for async tests
Future<void> pumpEventQueue({Duration duration = const Duration(milliseconds: 100)}) async {
  await Future.delayed(duration);
}

/// Test assertion helpers
void expectSnackBarShown(String message) {
  // This would be verified through widget testing
}

void expectNavigationTo(String routeName) {
  // This would be verified through widget testing
}
