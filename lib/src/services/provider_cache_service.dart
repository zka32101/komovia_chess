import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';

/// Three-tier caching strategy for providers:
/// Tier 1: Memory cache (hot data, fastest access)
/// Tier 2: SQLite local cache (warm data, persistent)
/// Tier 3: Firestore (cold data, authoritative)

class ProviderCacheService<K, V> {
  // Tier 2: Could integrate SQLite here
  // final Database? _localDb;

  ProviderCacheService({
    required this.cacheKey,
    this.fromJson,
    this.toJson,
  });
  final String cacheKey;
  final V Function(dynamic json)? fromJson;
  final Map<String, dynamic> Function(V)? toJson;

  // Tier 1: Memory cache
  final Map<K, _CacheEntry<V>> _memoryCache = {};

  /// Get value from cache (memory tier only for speed)
  V? get(K key) {
    final entry = _memoryCache[key];
    if (entry != null && !entry.isExpired()) {
      return entry.value;
    }
    // Remove expired entry
    _memoryCache.remove(key);
    return null;
  }

  /// Set value in cache
  void set(K key, V value, {Duration ttl = const Duration(minutes: 5)}) {
    _memoryCache[key] = _CacheEntry(value, DateTime.now().add(ttl));
  }

  /// Get or compute value
  Future<V> getOrCompute(
    K key,
    Future<V> Function() compute, {
    Duration ttl = const Duration(minutes: 5),
  }) async {
    final cached = get(key);
    if (cached != null) {
      return cached;
    }

    final value = await compute();
    set(key, value, ttl: ttl);
    return value;
  }

  /// Invalidate specific key
  void invalidate(K key) {
    _memoryCache.remove(key);
  }

  /// Invalidate all cache
  void invalidateAll() {
    _memoryCache.clear();
  }

  /// Get cache statistics
  CacheStats getStats() {
    int valid = 0;
    int expired = 0;

    for (final entry in _memoryCache.values) {
      if (entry.isExpired()) {
        expired++;
      } else {
        valid++;
      }
    }

    return CacheStats(
      totalEntries: _memoryCache.length,
      validEntries: valid,
      expiredEntries: expired,
    );
  }
}

/// Cache entry with expiration
class _CacheEntry<V> {
  _CacheEntry(this.value, this.expiresAt);
  final V value;
  final DateTime expiresAt;

  bool isExpired() => DateTime.now().isAfter(expiresAt);
}

/// Cache statistics
class CacheStats {
  CacheStats({
    required this.totalEntries,
    required this.validEntries,
    required this.expiredEntries,
  });
  final int totalEntries;
  final int validEntries;
  final int expiredEntries;

  @override
  String toString() =>
      'CacheStats(total: $totalEntries, valid: $validEntries, expired: $expiredEntries)';
}

/// Provider selection helper for efficient watching
/// Reduces unnecessary rebuilds by selecting specific fields
class ProviderSelector<T> {
  /// Watch only a specific field/transformation of the provider
  /// Example: ref.watch(gameProvider.select((state) => state.status))
  static R select<T, R>(
    AsyncValue<T> state,
    R Function(T) selector, {
    R Function()? onLoading,
    R Function(Object, StackTrace)? onError,
  }) =>
      state.when(
        data: selector,
        loading: onLoading ?? (() => throw StateError('Loading')),
        error: onError ?? ((e, st) => throw e),
      );

  /// Safe select with default value for loading/error
  static R selectSafe<T, R>(
    AsyncValue<T> state,
    R Function(T) selector,
    R defaultValue,
  ) =>
      state.whenData(selector).value ?? defaultValue;
}

/// Cached provider state notifier
/// Automatically manages cache invalidation
abstract class CachedAsyncNotifier<T> extends StateNotifier<AsyncValue<T>> {
  CachedAsyncNotifier({
    required this.cacheKey,
  })  : cacheService = ProviderCacheService(cacheKey: cacheKey),
        super(const AsyncValue.loading());
  final ProviderCacheService<String, T> cacheService;
  final String cacheKey;

  /// Load data with automatic caching
  Future<void> load() async {
    final cached = cacheService.get(cacheKey);
    if (cached != null) {
      state = AsyncValue.data(cached);
      return;
    }

    state = const AsyncValue.loading();
    try {
      final data = await fetch();
      cacheService.set(cacheKey, data);
      state = AsyncValue.data(data);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Override this to provide data loading logic
  Future<T> fetch();

  /// Invalidate cache and reload
  Future<void> invalidateAndReload() async {
    cacheService.invalidate(cacheKey);
    await load();
  }
}

/// Optimized watch patterns for providers
extension ProviderWatchExt<T> on ProviderListenable<AsyncValue<T>> {
  /// Watch only the data, ignore loading/error states for unchanged data
  ProviderListenable<T?> selectData() =>
      select((state) => state.whenData((data) => data).value);

  /// Watch only if data exists (null-safe)
  ProviderListenable<T?> selectDataOrNull() =>
      select((state) => state.whenData((data) => data).value);

  /// Watch only error states
  ProviderListenable<Object?> selectError() =>
      select((state) => state.whenData((_) => null).error);

  /// Watch only if loading
  ProviderListenable<bool> selectIsLoading() =>
      select((state) => state.isLoading);
}

/// Service for managing provider cache lifecycle
class ProviderCacheLifecycle {
  factory ProviderCacheLifecycle() => _instance;

  ProviderCacheLifecycle._();
  static final ProviderCacheLifecycle _instance = ProviderCacheLifecycle._();

  final Map<String, ProviderCacheService> _caches = {};

  /// Register a cache service
  void register<K, V>(String name, ProviderCacheService<K, V> cache) {
    _caches[name] = cache;
  }

  /// Get registered cache
  ProviderCacheService? getCache(String name) => _caches[name];

  /// Invalidate all caches
  void invalidateAll() {
    for (final cache in _caches.values) {
      cache.invalidateAll();
    }
  }

  /// Get all cache statistics
  Map<String, CacheStats> getAllStats() {
    final stats = <String, CacheStats>{};
    for (final entry in _caches.entries) {
      stats[entry.key] = entry.value.getStats();
    }
    return stats;
  }

  /// Print cache statistics (debug)
  void printStats() {
    if (kDebugMode) {
      final stats = getAllStats();
      print('=== Provider Cache Statistics ===');
      stats.forEach((name, stat) {
        print('$name: $stat');
      });
      print('================================');
    }
  }
}
