import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/phase_k_models.dart';
import '../utils/query_cache.dart';
import '../utils/pagination_helper.dart';

class TournamentServiceOptimized {
  factory TournamentServiceOptimized() => _instance;
  TournamentServiceOptimized._internal() {
    _tournamentCache = SmartCache(
      fetcher: _getTournamentFromDb,
      cacheTtl: const Duration(minutes: 15),
    );
    _standingsCache = SmartCache(
      fetcher: _getStandingsFromDb,
      cacheTtl: const Duration(minutes: 5),
    );
    _matchCache = SmartCache(
      fetcher: _getMatchesFromDb,
      cacheTtl: const Duration(minutes: 2),
    );
    _participantCountCache = MonitoredCache(
      cacheTtl: const Duration(minutes: 5),
    );
  }
  static final TournamentServiceOptimized _instance =
      TournamentServiceOptimized._internal();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late final SmartCache<String, Tournament> _tournamentCache;
  late final SmartCache<String, TournamentStandings> _standingsCache;
  late final SmartCache<String, List<TournamentMatch>> _matchCache;
  late final MonitoredCache<String, int> _participantCountCache;

  static TournamentServiceOptimized get instance => _instance;

  /// Get tournament with smart caching
  Future<Tournament> getTournamentOptimized(String tournamentId) async =>
      _tournamentCache.get(tournamentId);

  /// Get active tournaments with pagination
  Future<PaginatedResult<Tournament>> getActiveTournamentsPaginated({
    int pageSize = 10,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      final params = PaginationParams(
        pageSize: pageSize,
        startAfter: startAfter,
      );

      var query = _firestore.collection('tournaments').where('status',
          whereIn: ['registration', 'in-progress']).orderBy('startDate');

      query = QueryOptimizer.applyPagination(
        query,
        params,
      );

      return await QueryOptimizer.executePaginatedQuery(
        query,
        params,
        Tournament.fromJson,
      );
    } catch (e) {
      debugPrint('Error fetching active tournaments: $e');
      return PaginatedResult.empty();
    }
  }

  /// Get tournament standings with pagination
  Future<TournamentStandings> getTournamentStandingsOptimized(
    String tournamentId,
  ) async =>
      _standingsCache.get(tournamentId);

  /// Get tournament matches with round filtering and pagination
  Future<PaginatedResult<TournamentMatch>> getTournamentMatchesPaginated(
    String tournamentId, {
    int? round,
    int pageSize = 20,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      final params = PaginationParams(
        pageSize: pageSize,
        startAfter: startAfter,
      );

      var query = _firestore
          .collection('tournaments')
          .doc(tournamentId)
          .collection('matches')
          .orderBy('round')
          .orderBy('scheduledAt');

      if (round != null) {
        query = query.where('round', isEqualTo: round);
      }

      query = QueryOptimizer.applyPagination(
        query,
        params,
      );

      return await QueryOptimizer.executePaginatedQuery(
        query,
        params,
        TournamentMatch.fromJson,
      );
    } catch (e) {
      debugPrint('Error fetching tournament matches: $e');
      return PaginatedResult.empty();
    }
  }

  /// Get batch of tournament details
  Future<Map<String, Tournament>> getTournamentsBatch(
    List<String> tournamentIds,
  ) async {
    try {
      final queryChunks = BatchQueryHelper.chunk(tournamentIds, 10);
      final results = <String, Tournament>{};

      for (final chunk in queryChunks) {
        final snapshot = await _firestore
            .collection('tournaments')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        for (final doc in snapshot.docs) {
          results[doc.id] = Tournament.fromJson(doc.data());
        }
      }

      return results;
    } catch (e) {
      debugPrint('Error fetching tournament batch: $e');
      return {};
    }
  }

  /// Get tournament participants count (cached)
  Future<int> getTournamentParticipantCount(String tournamentId) async {
    final cached = _participantCountCache.get(tournamentId);
    if (cached != null) {
      return cached;
    }

    try {
      final countSnapshot = await _firestore
          .collection('tournaments')
          .doc(tournamentId)
          .collection('participants')
          .count()
          .get();

      final count = countSnapshot.count ?? 0;
      _participantCountCache.set(tournamentId, count);
      return count;
    } catch (e) {
      debugPrint('Error fetching participant count: $e');
      return 0;
    }
  }

  /// Get upcoming matches for user with pagination
  Future<PaginatedResult<TournamentMatch>> getUserUpcomingMatches(
    String userId, {
    int pageSize = 10,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      final params = PaginationParams(
        pageSize: pageSize,
        startAfter: startAfter,
      );

      var query = _firestore
          .collectionGroup('matches')
          .where('status', isEqualTo: 'scheduled')
          .where(Filter.or(
            Filter('player1Id', isEqualTo: userId),
            Filter('player2Id', isEqualTo: userId),
          ))
          .orderBy('scheduledAt');

      query = QueryOptimizer.applyPagination(
        query,
        params,
      );

      return await QueryOptimizer.executePaginatedQuery(
        query,
        params,
        TournamentMatch.fromJson,
      );
    } catch (e) {
      debugPrint('Error fetching user upcoming matches: $e');
      return PaginatedResult.empty();
    }
  }

  /// Database fetchers
  Future<Tournament> _getTournamentFromDb(String tournamentId) async {
    try {
      final doc =
          await _firestore.collection('tournaments').doc(tournamentId).get();

      if (!doc.exists) {
        throw Exception('Tournament not found');
      }

      return Tournament.fromJson(doc.data()!);
    } catch (e) {
      debugPrint('Error fetching tournament from db: $e');
      rethrow;
    }
  }

  Future<TournamentStandings> _getStandingsFromDb(String tournamentId) async {
    try {
      final snapshot = await _firestore
          .collection('tournaments')
          .doc(tournamentId)
          .collection('participants')
          .orderBy('points', descending: true)
          .orderBy('wins', descending: true)
          .get();

      final rankings = snapshot.docs.asMap().entries.map((entry) {
        final doc = entry.value.data();
        return TournamentRanking(
          position: entry.key + 1,
          userId: doc['userId'] ?? '',
          username: doc['username'] ?? '',
          points: doc['points'] ?? 0,
          wins: doc['wins'] ?? 0,
          losses: doc['losses'] ?? 0,
          draws: doc['draws'] ?? 0,
          buchholz: 0,
          performance: 0,
        );
      }).toList();

      return TournamentStandings(
        tournamentId: tournamentId,
        rankings: rankings,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      debugPrint('Error fetching standings from db: $e');
      rethrow;
    }
  }

  Future<List<TournamentMatch>> _getMatchesFromDb(String tournamentId) async {
    try {
      final snapshot = await _firestore
          .collection('tournaments')
          .doc(tournamentId)
          .collection('matches')
          .orderBy('round')
          .orderBy('scheduledAt')
          .get();

      return snapshot.docs
          .map((doc) => TournamentMatch.fromJson(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error fetching matches from db: $e');
      return [];
    }
  }

  /// Invalidate caches
  void invalidateTournamentCache(String tournamentId) {
    _tournamentCache.invalidate(tournamentId);
    _standingsCache.invalidate(tournamentId);
    _matchCache.invalidate(tournamentId);
    _participantCountCache.remove(tournamentId);
  }

  /// Clear all caches
  void clearCache() {
    _tournamentCache.invalidateAll();
    _standingsCache.invalidateAll();
    _matchCache.invalidateAll();
    _participantCountCache.clear();
  }
}
