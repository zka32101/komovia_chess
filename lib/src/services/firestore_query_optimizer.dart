import 'package:cloud_firestore/cloud_firestore.dart';

/// Utility class for Firestore query optimization
/// Eliminates N+1 queries through batching and caching
class FirestoreQueryOptimizer {
  FirestoreQueryOptimizer({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _firestore;
  final Map<String, dynamic> _queryCache = {};

  /// Fetch multiple documents by IDs in a single batch read
  /// Replaces N separate .doc(id).get() calls with one whereIn query
  Future<Map<String, T>> batchGetDocuments<T>({
    required String collection,
    required List<String> documentIds,
    required T Function(Map<String, dynamic>) fromJson,
    int maxBatchSize = 10, // Firestore limit: 10 for whereIn
  }) async {
    if (documentIds.isEmpty) return {};

    final results = <String, T>{};

    // Process in batches (Firestore whereIn limit is 10)
    for (int i = 0; i < documentIds.length; i += maxBatchSize) {
      final batch = documentIds.sublist(
        i,
        (i + maxBatchSize).clamp(0, documentIds.length),
      );

      final snapshot = await _firestore
          .collection(collection)
          .where(FieldPath.documentId, whereIn: batch)
          .get();

      for (final doc in snapshot.docs) {
        results[doc.id] = fromJson(doc.data());
      }
    }

    return results;
  }

  /// Fetch documents from subcollection in batches
  /// Example: Get all games for multiple users efficiently
  Future<Map<String, List<T>>> batchGetSubcollection<T>({
    required String parentCollection,
    required List<String> parentDocIds,
    required String subcollection,
    required T Function(Map<String, dynamic>) fromJson,
  }) async {
    if (parentDocIds.isEmpty) return {};

    final results = <String, List<T>>{};

    // Parallel fetch for each parent document
    final futures = <Future<void>>[];
    for (final parentId in parentDocIds) {
      futures.add(
        _firestore
            .collection(parentCollection)
            .doc(parentId)
            .collection(subcollection)
            .get()
            .then((snapshot) {
          results[parentId] = [
            for (final doc in snapshot.docs) fromJson(doc.data())
          ];
        }),
      );
    }

    await Future.wait(futures);
    return results;
  }

  /// Query with pagination support
  /// Returns cursor and results for efficient pagination
  Future<PaginatedResults<T>> paginatedQuery<T>({
    required Query Function(FirebaseFirestore) buildQuery,
    required T Function(Map<String, dynamic>) fromJson,
    required int pageSize,
    DocumentSnapshot? startAfter,
  }) async {
    var query = buildQuery(_firestore);

    if (startAfter != null) {
      query = query.startAfter([startAfter]);
    }

    final snapshot = await query.limit(pageSize + 1).get();

    final results = <T>[];
    DocumentSnapshot? nextCursor;

    for (int i = 0; i < snapshot.docs.length && i < pageSize; i++) {
      results.add(fromJson(snapshot.docs[i].data()! as Map<String, dynamic>));
    }

    // Check if there are more results
    if (snapshot.docs.length > pageSize) {
      nextCursor = snapshot.docs[pageSize];
    }

    return PaginatedResults(
      data: results,
      nextCursor: nextCursor,
      hasMore: nextCursor != null,
    );
  }

  /// Aggregate query results from multiple queries efficiently
  /// Caches results to avoid duplicate queries
  Future<T> cachedQuery<T>({
    required String cacheKey,
    required Future<T> Function() query,
    Duration cacheDuration = const Duration(minutes: 5),
  }) async {
    final cached = _queryCache[cacheKey];
    if (cached != null) {
      if (cached is _CachedValue<T>) {
        if (DateTime.now().difference(cached.timestamp) < cacheDuration) {
          return cached.value;
        }
      }
    }

    final result = await query();
    _queryCache[cacheKey] = _CachedValue(result, DateTime.now());
    return result;
  }

  /// Clear cache for a specific key or all
  void clearCache({String? key}) {
    if (key != null) {
      _queryCache.remove(key);
    } else {
      _queryCache.clear();
    }
  }

  /// Batch write operations (create/update/delete)
  /// Groups operations to reduce write count
  Future<void> batchWrite({
    required void Function(WriteBatch) batchOperations,
  }) async {
    final batch = _firestore.batch();
    batchOperations(batch);
    await batch.commit();
  }
}

/// Model for paginated results
class PaginatedResults<T> {
  PaginatedResults({
    required this.data,
    required this.hasMore,
    this.nextCursor,
  });
  final List<T> data;
  final DocumentSnapshot? nextCursor;
  final bool hasMore;
}

/// Internal cached value wrapper
class _CachedValue<T> {
  _CachedValue(this.value, this.timestamp);
  final T value;
  final DateTime timestamp;
}

/// Singleton instance of query optimizer
class FirestoreQueryOptimizerService {
  factory FirestoreQueryOptimizerService() => _instance;

  FirestoreQueryOptimizerService._() {
    _optimizer = FirestoreQueryOptimizer();
  }
  static final FirestoreQueryOptimizerService _instance =
      FirestoreQueryOptimizerService._();
  late final FirestoreQueryOptimizer _optimizer;

  FirestoreQueryOptimizer get optimizer => _optimizer;
}

final firestoreQueryOptimizerService =
    FirestoreQueryOptimizerService().optimizer;
