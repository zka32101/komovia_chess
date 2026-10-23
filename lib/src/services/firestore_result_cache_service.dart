import 'cache_manager_service.dart';

/// Caches individual Firestore documents with per-document invalidation.
///
/// Previously also offered a query-result cache
/// (cacheQueryResults/getCachedQueryResults/isQueryCached) plus
/// cacheBatchDocuments/preWarmCache and a collection-wide
/// invalidateCollection built on top of it - confirmed via grep that
/// none of these had ever had a real caller anywhere in lib/ (only a
/// code comment in analytics_dashboard_service_impl.dart referencing
/// the already-fixed always-miss bug that calling isQueryCached without
/// ever calling cacheQueryResults used to cause). Removed rather than
/// kept as untested, never-exercised surface area: its
/// _queryDependencies tracking was keyed by collection name only, not by
/// filter hash, so a future caller mixing cacheDocument and
/// cacheQueryResults under the same collection would have reproduced
/// the exact cross-document over-invalidation bug invalidateDocument
/// was fixed to avoid (see its own doc comment below).
class FirestoreResultCacheService {
  factory FirestoreResultCacheService() => _instance;

  FirestoreResultCacheService._internal();
  static final FirestoreResultCacheService _instance =
      FirestoreResultCacheService._internal();
  final CacheManagerService _cacheManager = CacheManagerService();

  /// Cache a Firestore document.
  void cacheDocument<T>(
    String collection,
    String docId,
    T data, {
    Duration? ttl,
  }) {
    final key = 'doc:$collection:$docId';
    _cacheManager.set<T>(key, data, ttl: ttl);
  }

  /// Get cached document.
  T? getCachedDocument<T>(String collection, String docId) {
    final key = 'doc:$collection:$docId';
    return _cacheManager.get<T>(key);
  }

  /// Invalidate specific document in cache.
  ///
  /// Only removes this one document's cache entry. Previously this also
  /// called invalidateCollection(collection), which wipes every key
  /// _trackDependency has ever recorded under that collection name -
  /// but _queryDependencies is keyed by collection name only, not by
  /// document id, so cacheDocument() for EVERY document in a collection
  /// (e.g. every signed-in player's cached PlayerAnalyticsDashboard
  /// under 'analytics') lands in the same bucket. One player finishing
  /// a CPU game and calling AnalyticsDashboardService.invalidatePlayerAnalytics
  /// would silently evict every other player's cached dashboard too,
  /// defeating the cache's whole point. No caller of invalidateDocument
  /// actually needs that collection-wide sweep today (confirmed via
  /// grep - this method's only caller, 'analytics', never uses
  /// cacheQueryResults/getCachedQueryResults), so this now only removes
  /// the one document's own key.
  void invalidateDocument(String collection, String docId) {
    final key = 'doc:$collection:$docId';
    _cacheManager.remove(key);
  }

  /// Clear all cache.
  void clear() {
    _cacheManager.clear();
  }

  /// Get cache statistics.
  CacheStats getStats() => _cacheManager.getStats();
}
