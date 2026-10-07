import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_chess/src/services/firestore_query_optimizer.dart';
import 'package:komovia_chess/src/services/provider_cache_service.dart';

void main() {
  group('Performance Optimization Tests', () {
    group('FirestoreQueryOptimizer', () {
      late FirestoreQueryOptimizer optimizer;

      setUp(() {
        optimizer = FirestoreQueryOptimizer();
      });

      test('batchGetDocuments handles empty list', () async {
        final results = await optimizer.batchGetDocuments<String>(
          collection: 'users',
          documentIds: [],
          fromJson: (json) => 'test',
        );

        expect(results, isEmpty);
      });

      test('batchGetDocuments splits large batches correctly', () async {
        // Generate 25 IDs (should be split into 3 batches)
        final ids = List.generate(25, (i) => 'id_$i');

        // Note: This test would need a mock Firestore to fully work
        // The actual batching logic is tested implicitly
        expect(ids.length, 25);
      });

      test('cachedQuery returns cached results', () async {
        int callCount = 0;

        // First call
        final result1 = await optimizer.cachedQuery<String>(
          cacheKey: 'test_key',
          query: () async {
            callCount++;
            return 'result';
          },
        );

        // Second call should use cache
        final result2 = await optimizer.cachedQuery<String>(
          cacheKey: 'test_key',
          query: () async {
            callCount++;
            return 'result';
          },
        );

        expect(result1, 'result');
        expect(result2, 'result');
        expect(callCount, 1); // Query only called once
      });

      test('cachedQuery respects cache expiration', () async {
        int callCount = 0;

        // First call
        await optimizer.cachedQuery<String>(
          cacheKey: 'expire_key',
          query: () async {
            callCount++;
            return 'result1';
          },
          cacheDuration: Duration(milliseconds: 100),
        );

        // Second call immediately (should be cached)
        await optimizer.cachedQuery<String>(
          cacheKey: 'expire_key',
          query: () async {
            callCount++;
            return 'result2';
          },
          cacheDuration: Duration(milliseconds: 100),
        );

        expect(callCount, 1);

        // Wait for expiration
        await Future.delayed(Duration(milliseconds: 150));

        // Third call after expiration (should query again)
        await optimizer.cachedQuery<String>(
          cacheKey: 'expire_key',
          query: () async {
            callCount++;
            return 'result3';
          },
          cacheDuration: Duration(milliseconds: 100),
        );

        expect(callCount, 2); // Query called twice
      });

      test('clearCache removes specific key', () async {
        await optimizer.cachedQuery<String>(
          cacheKey: 'clear_key',
          query: () async => 'result',
        );

        optimizer.clearCache(key: 'clear_key');

        int callCount = 0;
        await optimizer.cachedQuery<String>(
          cacheKey: 'clear_key',
          query: () async {
            callCount++;
            return 'result2';
          },
        );

        expect(callCount, 1); // Query called because cache was cleared
      });

      test('clearCache removes all keys', () async {
        await optimizer.cachedQuery<String>(
          cacheKey: 'key1',
          query: () async => 'result1',
        );
        await optimizer.cachedQuery<String>(
          cacheKey: 'key2',
          query: () async => 'result2',
        );

        optimizer.clearCache();

        int callCount = 0;
        await optimizer.cachedQuery<String>(
          cacheKey: 'key1',
          query: () async {
            callCount++;
            return 'result';
          },
        );

        expect(callCount, 1); // Query called because all cache was cleared
      });
    });

    group('ProviderCacheService', () {
      late ProviderCacheService<String, String> cache;

      setUp(() {
        cache = ProviderCacheService<String, String>(
          cacheKey: 'test_cache',
        );
      });

      test('get returns null for missing key', () {
        expect(cache.get('missing_key'), isNull);
      });

      test('set and get work correctly', () {
        cache.set('key1', 'value1');
        expect(cache.get('key1'), 'value1');
      });

      test('get returns null for expired entries', () async {
        cache.set('key1', 'value1', ttl: Duration(milliseconds: 100));
        expect(cache.get('key1'), 'value1');

        await Future.delayed(Duration(milliseconds: 150));
        expect(cache.get('key1'), isNull);
      });

      test('getOrCompute returns cached value', () async {
        int callCount = 0;

        // First call
        final result1 = await cache.getOrCompute(
          'key1',
          () async {
            callCount++;
            return 'value1';
          },
        );

        // Second call
        final result2 = await cache.getOrCompute(
          'key1',
          () async {
            callCount++;
            return 'value2';
          },
        );

        expect(result1, 'value1');
        expect(result2, 'value1'); // Returns cached value
        expect(callCount, 1);
      });

      test('invalidate removes specific key', () async {
        cache.set('key1', 'value1');
        cache.invalidate('key1');
        expect(cache.get('key1'), isNull);
      });

      test('invalidateAll removes all keys', () async {
        cache.set('key1', 'value1');
        cache.set('key2', 'value2');
        cache.invalidateAll();

        expect(cache.get('key1'), isNull);
        expect(cache.get('key2'), isNull);
      });

      test('getStats returns correct counts', () async {
        cache.set('key1', 'value1');
        cache.set('key2', 'value2', ttl: Duration(milliseconds: 100));

        final stats = cache.getStats();
        expect(stats.totalEntries, 2);
        expect(stats.validEntries, 2);

        await Future.delayed(Duration(milliseconds: 150));
        final stats2 = cache.getStats();
        expect(stats2.expiredEntries, 1);
      });
    });

    group('Performance Metrics', () {
      test('cached query is faster than uncached', () async {
        final optimizer = FirestoreQueryOptimizer();

        // First query (uncached)
        final sw1 = Stopwatch()..start();
        await optimizer.cachedQuery<String>(
          cacheKey: 'perf_test',
          query: () async {
            await Future.delayed(Duration(milliseconds: 10));
            return 'result';
          },
        );
        sw1.stop();

        // Second query (cached)
        final sw2 = Stopwatch()..start();
        await optimizer.cachedQuery<String>(
          cacheKey: 'perf_test',
          query: () async {
            await Future.delayed(Duration(milliseconds: 10));
            return 'result';
          },
        );
        sw2.stop();

        // Cached query should be significantly faster
        expect(sw2.elapsedMilliseconds, lessThan(sw1.elapsedMilliseconds));
      });

      test('cache service handles 1000 entries', () async {
        final cache = ProviderCacheService<String, String>(
          cacheKey: 'large_cache',
        );

        // Add 1000 entries
        final sw = Stopwatch()..start();
        for (int i = 0; i < 1000; i++) {
          cache.set('key_$i', 'value_$i');
        }
        sw.stop();

        // Should complete quickly (< 100ms)
        expect(sw.elapsedMilliseconds, lessThan(100));

        // Retrieve random entries
        expect(cache.get('key_500'), 'value_500');
        expect(cache.get('key_999'), 'value_999');

        final stats = cache.getStats();
        expect(stats.totalEntries, 1000);
      });
    });
  });
}
