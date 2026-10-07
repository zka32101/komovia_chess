import 'cache_manager_service.dart';

/// Caches Firestore query results with smart invalidation.
/// Reduces redundant database reads for identical queries.
class FirestoreResultCacheService {
  factory FirestoreResultCacheService() => _instance;

  FirestoreResultCacheService._internal();
  static final FirestoreResultCacheService _instance =
      FirestoreResultCacheService._internal();
  final CacheManagerService _cacheManager = CacheManagerService();
  final Map<String, Set<String>> _queryDependencies = {};

  /// Generate cache key from query parameters.
  String _generateKey(String collection, Map<String, dynamic>? filters) {
    final filterStr = filters?.entries
        .map((e) => '${e.key}:${e.value}')
        .join('|')
        .hashCode
        .toString();
    return 'firestore:$collection:${filterStr ?? "all"}';
  }

  /// Cache a Firestore document.
  void cacheDocument<T>(
    String collection,
    String docId,
    T data, {
    Duration? ttl,
  }) {
    final key = 'doc:$collection:$docId';
    _cacheManager.set<T>(key, data, ttl: ttl);
    _trackDependency(collection, key);
  }

  /// Get cached document.
  T? getCachedDocument<T>(String collection, String docId) {
    final key = 'doc:$collection:$docId';
    return _cacheManager.get<T>(key);
  }

  /// Cache query results.
  void cacheQueryResults<T>(
    String collection,
    List<T> results, {
    Map<String, dynamic>? filters,
    Duration? ttl,
  }) {
    final key = _generateKey(collection, filters);
    _cacheManager.set<List<T>>(key, results, ttl: ttl);
    _trackDependency(collection, key);
  }

  /// Get cached query results.
  List<T>? getCachedQueryResults<T>(
    String collection, {
    Map<String, dynamic>? filters,
  }) {
    final key = _generateKey(collection, filters);
    return _cacheManager.get<List<T>>(key);
  }

  /// Check if query result is cached.
  bool isQueryCached(
    String collection, {
    Map<String, dynamic>? filters,
  }) {
    final key = _generateKey(collection, filters);
    return _cacheManager.containsKey(key);
  }

  /// Invalidate all cache entries for a collection.
  void invalidateCollection(String collection) {
    final deps = _queryDependencies[collection] ?? {};
    for (final key in deps) {
      _cacheManager.remove(key);
    }
    _queryDependencies.remove(collection);
  }

  /// Invalidate specific document in cache.
  void invalidateDocument(String collection, String docId) {
    final key = 'doc:$collection:$docId';
    _cacheManager.remove(key);
    // Also invalidate related query results
    invalidateCollection(collection);
  }

  /// Clear all cache.
  void clear() {
    _cacheManager.clear();
    _queryDependencies.clear();
  }

  /// Get cache statistics.
  CacheStats getStats() => _cacheManager.getStats();

  /// Track dependency relationship for cache invalidation.
  void _trackDependency(String collection, String key) {
    _queryDependencies.putIfAbsent(collection, () => {}).add(key);
  }

  /// Batch cache multiple documents (efficient for bulk operations).
  void cacheBatchDocuments<T>(
    String collection,
    Map<String, T> docMap, {
    Duration? ttl,
  }) {
    for (final entry in docMap.entries) {
      cacheDocument<T>(collection, entry.key, entry.value, ttl: ttl);
    }
  }

  /// Pre-warm cache with frequently accessed data.
  void preWarmCache(String collection, List<Map<String, dynamic>> data) {
    for (final item in data) {
      if (item.containsKey('id')) {
        cacheDocument(collection, item['id'].toString(), item);
      }
    }
  }
}
