import 'package:mockito/mockito.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:komovia_chess/src/models/online_game.dart';
import 'package:komovia_chess/src/models/user.dart';

/// Mock Firestore instance
class MockFirebaseFirestore extends Mock implements FirebaseFirestore {
  final Map<String, Map<String, dynamic>> _collections = {};

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    return MockCollectionReference(collectionPath, _collections);
  }

  /// Set mock data for a collection
  void setMockData(String collection, Map<String, Map<String, dynamic>> data) {
    _collections[collection] = data;
  }

  /// Get mock data from a collection
  Map<String, dynamic>? getMockData(String collection, String docId) {
    return _collections[collection]?[docId];
  }

  /// Clear all mock data
  void clearMockData() {
    _collections.clear();
  }
}

/// Mock CollectionReference
class MockCollectionReference extends Mock
    implements CollectionReference<Map<String, dynamic>> {
  final String collectionPath;
  final Map<String, Map<String, dynamic>> _data;

  MockCollectionReference(this.collectionPath, this._data);

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    return MockDocumentReference(
      path ?? 'default_doc',
      _data[collectionPath] ?? {},
    );
  }

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get() async {
    final docs = _data[collectionPath] ?? {};
    return MockQuerySnapshot(
      docs.entries
          .map((e) => MockQueryDocumentSnapshot(e.key, e.value))
          .toList(),
    );
  }

  @override
  Query<Map<String, dynamic>> where(
    Object field, {
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? arrayContains,
    List<Object?>? arrayContainsAny,
    List<Object?>? whereIn,
    bool? isNull,
  }) {
    // Return mock query (simplified filtering)
    return MockQuery(
      _data[collectionPath] ?? {},
      field as String,
      isEqualTo,
    );
  }

  @override
  Query<Map<String, dynamic>> orderBy(
    Object field, {
    bool descending = false,
  }) {
    // Return mock query (simplified sorting)
    return MockQuery(_data[collectionPath] ?? {}, field as String, null);
  }

  @override
  Query<Map<String, dynamic>> limit(int limit) {
    return MockQuery(_data[collectionPath] ?? {}, 'limit', limit);
  }
}

/// Mock DocumentReference
class MockDocumentReference extends Mock
    implements DocumentReference<Map<String, dynamic>> {
  final String docId;
  final Map<String, dynamic> _data;

  MockDocumentReference(this.docId, this._data);

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get() async {
    return MockDocumentSnapshot(docId, _data[docId] ?? {});
  }

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    _data[docId] = data;
  }

  @override
  Future<void> update(Map<String, Object?> data) async {
    _data[docId] = {...?_data[docId], ...data};
  }

  @override
  Future<void> delete() async {
    _data.remove(docId);
  }

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    return MockCollectionReference(collectionPath, _data);
  }
}

/// Mock DocumentSnapshot
class MockDocumentSnapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {
  final String _docId;
  final Map<String, dynamic> _data;

  MockDocumentSnapshot(this._docId, this._data);

  @override
  String get id => _docId;

  @override
  Map<String, dynamic>? data() => _data;

  @override
  bool get exists => _data.isNotEmpty;

  @override
  dynamic operator [](Object field) => _data[field];

  @override
  T? get<T>(Object field) => _data[field] as T?;
}

/// Mock QuerySnapshot
class MockQuerySnapshot extends Mock
    implements QuerySnapshot<Map<String, dynamic>> {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs;

  MockQuerySnapshot(this._docs);

  @override
  List<QueryDocumentSnapshot<Map<String, dynamic>>> get docs => _docs;

  @override
  int get size => _docs.length;

  @override
  bool get empty => _docs.isEmpty;
}

/// Mock QueryDocumentSnapshot
class MockQueryDocumentSnapshot extends Mock
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  final String _docId;
  final Map<String, dynamic> _data;

  MockQueryDocumentSnapshot(this._docId, this._data);

  @override
  String get id => _docId;

  @override
  Map<String, dynamic> data() => _data;

  @override
  dynamic operator [](Object field) => _data[field];

  @override
  T? get<T>(Object field) => _data[field] as T?;
}

/// Mock Query
class MockQuery extends Mock implements Query<Map<String, dynamic>> {
  final Map<String, dynamic> _data;
  final String _field;
  final Object? _value;

  MockQuery(this._data, this._field, this._value);

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get() async {
    return MockQuerySnapshot([
      MockQueryDocumentSnapshot('mock_doc', _data),
    ]);
  }
}

/// Mock Online Game Service
class MockOnlineGameService extends Mock {
  final List<OnlineGame> _games = [];
  bool _shouldFail = false;

  /// Set whether service should throw errors
  void setShouldFail(bool value) => _shouldFail = value;

  /// Add game to mock service
  void addGame(OnlineGame game) => _games.add(game);

  /// Clear all games
  void clearGames() => _games.clear();

  /// Get player's active games
  Future<List<OnlineGame>> getPlayerActiveGames(String playerId) async {
    if (_shouldFail) throw Exception('Network error');
    return _games.where((g) => g.status == 'active').toList();
  }

  /// Get player's recent games
  Future<List<OnlineGame>> getPlayerRecentGames(String playerId,
      {int limit = 20}) async {
    if (_shouldFail) throw Exception('Network error');
    return _games.take(limit).toList();
  }

  /// Get specific game
  Future<OnlineGame?> getGame(String gameId) async {
    if (_shouldFail) throw Exception('Network error');
    try {
      return _games.firstWhere((g) => g.id == gameId);
    } catch (e) {
      return null;
    }
  }

  /// Watch game updates
  Stream<OnlineGame> watchGame(String gameId) {
    if (_shouldFail) {
      return Stream.error(Exception('Network error'));
    }
    final game = _games.firstWhere((g) => g.id == gameId,
        orElse: () => throw Exception('Not found'));
    return Stream.value(game);
  }

  /// Make a move
  Future<void> makeMove(String gameId, String move) async {
    if (_shouldFail) throw Exception('Network error');
    // Simulate move
  }

  /// Resign game
  Future<void> resignGame(String gameId) async {
    if (_shouldFail) throw Exception('Network error');
    final index = _games.indexWhere((g) => g.id == gameId);
    if (index >= 0) {
      _games[index] = _games[index].copyWith(status: 'completed');
    }
  }
}

/// Mock User Service
class MockUserService extends Mock {
  Map<String, dynamic>? _currentUser;
  bool _shouldFail = false;

  void setShouldFail(bool value) => _shouldFail = value;

  void setCurrentUser(Map<String, dynamic> user) => _currentUser = user;

  void clearCurrentUser() => _currentUser = null;

  Future<Map<String, dynamic>?> getCurrentUser() async {
    if (_shouldFail) throw Exception('Network error');
    return _currentUser;
  }

  Future<void> updateUserProfile(Map<String, dynamic> updates) async {
    if (_shouldFail) throw Exception('Network error');
    if (_currentUser != null) {
      _currentUser = {..._currentUser!, ...updates};
    }
  }

  Future<int> getUserRating(String userId) async {
    if (_shouldFail) throw Exception('Network error');
    return 1600;
  }
}

/// Mock Auth Service
class MockAuthService extends Mock {
  String? _currentUserId;
  bool _shouldFail = false;

  void setShouldFail(bool value) => _shouldFail = value;

  void setCurrentUserId(String? userId) => _currentUserId = userId;

  String? getCurrentUserId() {
    if (_shouldFail) throw Exception('Auth error');
    return _currentUserId;
  }

  Future<bool> isUserLoggedIn() async {
    if (_shouldFail) throw Exception('Auth error');
    return _currentUserId != null;
  }

  Future<void> logout() async {
    _currentUserId = null;
  }

  Future<String?> signUp(String email, String password) async {
    if (_shouldFail) throw Exception('Sign up failed');
    return 'new_user_id';
  }

  Future<String?> signIn(String email, String password) async {
    if (_shouldFail) throw Exception('Sign in failed');
    return 'user_id';
  }
}
