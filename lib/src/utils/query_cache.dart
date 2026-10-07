import 'dart:async';

class CacheEntry<T> {
  CacheEntry({
    required this.value,
    required this.ttl,
  }) : createdAt = DateTime.now();
  final T value;
  final DateTime createdAt;
  final Duration ttl;

  bool get isExpired => DateTime.now().difference(createdAt) > ttl;
}

class QueryCache<K, V> {
  QueryCache({this.defaultTtl = const Duration(minutes: 5)});
  final Map<K, CacheEntry<V>> _cache = {};
  final Duration defaultTtl;

  V? get(K key) {
    final entry = _cache[key];
    if (entry == null) return null;

    if (entry.isExpired) {
      _cache.remove(key);
      return null;
    }

    return entry.value;
  }

  void set(K key, V value, {Duration? ttl}) {
    _cache[key] = CacheEntry(value: value, ttl: ttl ?? defaultTtl);
  }

  void remove(K key) => _cache.remove(key);

  void clear() => _cache.clear();

  void removeWhere(bool Function(K key) predicate) {
    _cache.removeWhere((k, v) => predicate(k));
  }

  bool contains(K key) {
    final entry = _cache[key];
    if (entry == null) return false;
    if (entry.isExpired) {
      _cache.remove(key);
      return false;
    }
    return true;
  }

  int get size => _cache.length;
}

class SmartCache<K, V> {
  SmartCache({
    required this.fetcher,
    Duration cacheTtl = const Duration(minutes: 5),
  }) : _cache = QueryCache(defaultTtl: cacheTtl);
  final QueryCache<K, V> _cache;
  final Future<V> Function(K) fetcher;
  final Map<K, Completer<V>> _inFlight = {};

  Future<V> get(K key, {Duration? ttl}) async {
    final cached = _cache.get(key);
    if (cached != null) {
      return cached;
    }

    if (_inFlight.containsKey(key)) {
      return _inFlight[key]!.future;
    }

    final completer = Completer<V>();
    _inFlight[key] = completer;

    try {
      final value = await fetcher(key);
      _cache.set(key, value, ttl: ttl);
      completer.complete(value);
      return value;
    } catch (e) {
      completer.completeError(e);
      _inFlight.remove(key);
      rethrow;
    } finally {
      _inFlight.remove(key);
    }
  }

  void invalidate(K key) {
    _cache.remove(key);
  }

  void invalidateAll() {
    _cache.clear();
  }
}

class CompositeCache<K, V> {
  CompositeCache({
    required int tiers,
    required List<Duration> ttls,
  })  : assert(tiers == ttls.length, 'Number of tiers must match TTLs'),
        _tiers = List.generate(
          tiers,
          (i) => QueryCache<K, V>(defaultTtl: ttls[i]),
        );
  final List<QueryCache<K, V>> _tiers;

  V? get(K key) {
    for (final tier in _tiers) {
      final value = tier.get(key);
      if (value != null) {
        return value;
      }
    }
    return null;
  }

  void set(K key, V value) {
    for (final tier in _tiers) {
      tier.set(key, value);
    }
  }

  void remove(K key) {
    for (final tier in _tiers) {
      tier.remove(key);
    }
  }

  void clear() {
    for (final tier in _tiers) {
      tier.clear();
    }
  }
}

class CacheStats {
  int hits = 0;
  int misses = 0;
  int evictions = 0;

  double get hitRate => (hits + misses) == 0 ? 0 : hits / (hits + misses);

  @override
  String toString() =>
      'CacheStats(hits: $hits, misses: $misses, evictions: $evictions, hitRate: ${(hitRate * 100).toStringAsFixed(1)}%)';

  void reset() {
    hits = 0;
    misses = 0;
    evictions = 0;
  }
}

class MonitoredCache<K, V> {
  MonitoredCache({Duration cacheTtl = const Duration(minutes: 5)})
      : _cache = QueryCache(defaultTtl: cacheTtl);
  final QueryCache<K, V> _cache;
  final CacheStats _stats = CacheStats();

  V? get(K key) {
    final value = _cache.get(key);
    if (value != null) {
      _stats.hits++;
    } else {
      _stats.misses++;
    }
    return value;
  }

  void set(K key, V value, {Duration? ttl}) {
    _cache.set(key, value, ttl: ttl);
  }

  void remove(K key) {
    _cache.remove(key);
    _stats.evictions++;
  }

  void removeWhere(bool Function(K key) predicate) {
    _cache.removeWhere(predicate);
    _stats.evictions++;
  }

  void clear() {
    _cache.clear();
    _stats.evictions += _cache.size;
  }

  CacheStats get stats => _stats;
}
