import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/streaming_service.dart';
import '../services/cache_manager_service.dart';
import '../services/firestore_result_cache_service.dart';
import '../services/firestore_batch_query_service.dart';

// Streaming providers (existing)
final streamingServiceProvider = Provider((ref) => StreamingService());

final liveStreamsProvider = FutureProvider(
    (ref) => ref.watch(streamingServiceProvider).getLiveStreams());

final videoTutorialsProvider = FutureProvider.family<List<VideoContent>, int>(
    (ref, limit) =>
        ref.watch(streamingServiceProvider).getVideoTutorials(limit));

final streamAnalyticsProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, streamId) =>
        ref.watch(streamingServiceProvider).getStreamAnalytics(streamId));

// Phase L: Performance Optimization Providers

/// Singleton providers for Phase L performance optimization services.

/// Global cache manager instance
final cacheManagerProvider =
    Provider<CacheManagerService>((ref) => CacheManagerService());

/// Firestore result cache service
final firestoreResultCacheProvider = Provider<FirestoreResultCacheService>(
    (ref) => FirestoreResultCacheService());

/// Firestore batch query service
final firestoreBatchQueryProvider =
    Provider<FirestoreBatchQueryService>((ref) => FirestoreBatchQueryService());

/// Cache statistics provider - monitors cache health
final cacheStatsProvider = StateProvider<CacheStats?>((ref) {
  final cache = ref.watch(cacheManagerProvider);
  return cache.getStats();
});

/// Periodic cache cleanup provider - clears expired entries every 5 minutes
final periodicCacheCleanupProvider = FutureProvider<void>((ref) async {
  final cache = ref.watch(cacheManagerProvider);

  // Run cleanup on first access
  cache.clearExpired();

  // Return completed future
  return Future.value();
});

/// Manual cache invalidation provider for collection-level operations
final cacheInvalidationProvider =
    StateNotifierProvider<CacheInvalidationNotifier, List<String>>((ref) {
  final cache = ref.watch(firestoreResultCacheProvider);
  return CacheInvalidationNotifier(cache);
});

/// Notifier for manual cache invalidation
class CacheInvalidationNotifier extends StateNotifier<List<String>> {
  CacheInvalidationNotifier(this._cache) : super([]);
  final FirestoreResultCacheService _cache;

  /// Invalidate specific collection
  void invalidateCollection(String collection) {
    _cache.invalidateCollection(collection);
    state = [...state, collection];
  }

  /// Invalidate specific document
  void invalidateDocument(String collection, String docId) {
    _cache.invalidateDocument(collection, docId);
    state = [...state, '$collection:$docId'];
  }

  /// Clear all cache
  void clearAllCache() {
    _cache.clear();
    state = [];
  }

  /// Get invalidation history
  List<String> getInvalidationHistory() => state;
}

/// Performance metrics provider
final performanceMetricsProvider = StateProvider<PerformanceMetrics>((ref) {
  final cache = ref.watch(cacheManagerProvider);
  final stats = cache.getStats();

  return PerformanceMetrics(
    cacheUtilization: double.parse(stats.utilizationPercent),
    totalCacheEntries: stats.totalEntries,
    maxCacheSize: stats.maxSize,
  );
});

/// Data class for performance metrics
class PerformanceMetrics {
  PerformanceMetrics({
    required this.cacheUtilization,
    required this.totalCacheEntries,
    required this.maxCacheSize,
  });
  final double cacheUtilization;
  final int totalCacheEntries;
  final int maxCacheSize;

  double get cacheHitRatePotential => (totalCacheEntries / maxCacheSize) * 100;
  bool get cacheNearCapacity => cacheUtilization > 80;
  bool get cacheUnderutilized => cacheUtilization < 20;

  @override
  String toString() =>
      'PerformanceMetrics(utilization: ${cacheUtilization.toStringAsFixed(1)}%, entries: $totalCacheEntries/$maxCacheSize)';
}
