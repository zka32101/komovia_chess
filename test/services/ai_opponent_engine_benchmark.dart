import 'package:flutter_test/flutter_test.dart';
import 'package:chess/chess.dart' as chess_lib;
import 'package:komovia_chess/src/services/chess_engine_service.dart';
import 'package:komovia_chess/src/services/ai_opponent_engine_enhanced.dart';

/// Performance benchmark suite for AIOpponentEngineEnhanced
///
/// Measures:
/// - Node evaluation rate (nodes/sec)
/// - Zobrist cache efficiency (hit rate %)
/// - Search depth per time budget
/// - Move ordering effectiveness
/// - Difficulty-level performance
void main() {
  group('AIOpponentEngineEnhanced Performance Benchmarks', () {
    late ChessEngineService chess;
    late AIOpponentEngineEnhanced engine;
    late BenchmarkResults results;

    setUp(() {
      chess = ChessEngineService();
      engine = AIOpponentEngineEnhanced(chess, AIDifficulty.medium);
      results = BenchmarkResults();
    });

    group('Starting Position Benchmarks', () {
      test('easy difficulty - opening position', () {
        final easyEngine = AIOpponentEngineEnhanced(chess, AIDifficulty.easy);
        final stopwatch = Stopwatch()..start();

        final move = easyEngine.getBestMove();

        stopwatch.stop();
        expect(move, isNotNull);

        final stats = easyEngine.getSearchStats();
        final nodes = stats['nodesEvaluated'] as int;
        final time = stopwatch.elapsedMilliseconds;

        results.recordBenchmark(
          'Starting Position - Easy',
          nodes,
          time,
          stats['zobristHits'] as int? ?? 0,
          stats['zobristMisses'] as int? ?? 0,
        );

        print(
            'Easy - Nodes: $nodes, Time: ${time}ms, Rate: ${(nodes / (time / 1000)).toStringAsFixed(0)} nodes/sec');
        expect(time, lessThan(AIDifficulty.easy.thinkingTimeMs * 1.5));
      });

      test('medium difficulty - opening position', () {
        final mediumEngine =
            AIOpponentEngineEnhanced(chess, AIDifficulty.medium);
        final stopwatch = Stopwatch()..start();

        final move = mediumEngine.getBestMove();

        stopwatch.stop();
        expect(move, isNotNull);

        final stats = mediumEngine.getSearchStats();
        final nodes = stats['nodesEvaluated'] as int;
        final time = stopwatch.elapsedMilliseconds;

        results.recordBenchmark(
          'Starting Position - Medium',
          nodes,
          time,
          stats['zobristHits'] as int? ?? 0,
          stats['zobristMisses'] as int? ?? 0,
        );

        print(
            'Medium - Nodes: $nodes, Time: ${time}ms, Rate: ${(nodes / (time / 1000)).toStringAsFixed(0)} nodes/sec');
        expect(time, lessThan(AIDifficulty.medium.thinkingTimeMs * 1.5));
      });

      test('hard difficulty - opening position', () {
        final hardEngine = AIOpponentEngineEnhanced(chess, AIDifficulty.hard);
        final stopwatch = Stopwatch()..start();

        final move = hardEngine.getBestMove();

        stopwatch.stop();
        expect(move, isNotNull);

        final stats = hardEngine.getSearchStats();
        final nodes = stats['nodesEvaluated'] as int;
        final time = stopwatch.elapsedMilliseconds;

        results.recordBenchmark(
          'Starting Position - Hard',
          nodes,
          time,
          stats['zobristHits'] as int? ?? 0,
          stats['zobristMisses'] as int? ?? 0,
        );

        print(
            'Hard - Nodes: $nodes, Time: ${time}ms, Rate: ${(nodes / (time / 1000)).toStringAsFixed(0)} nodes/sec');
        expect(time, lessThan(AIDifficulty.hard.thinkingTimeMs * 1.5));
      });
    });

    group('Sicilian Defense Benchmarks', () {
      setUp(() {
        // Set up Sicilian position: 1.e4 c5 2.Nf3 d6 3.d4 cxd4 4.Nxd4
        final moves = [
          ('e2', 'e4'),
          ('c7', 'c5'),
          ('g1', 'f3'),
          ('d7', 'd6'),
          ('d2', 'd4'),
          ('c5', 'd4'),
          ('f3', 'd4'),
        ];
        for (final (from, to) in moves) {
          chess.makeMove(from, to);
        }
      });

      test('medium difficulty - Sicilian position', () {
        final stopwatch = Stopwatch()..start();

        final move = engine.getBestMove();

        stopwatch.stop();
        expect(move, isNotNull);

        final stats = engine.getSearchStats();
        final nodes = stats['nodesEvaluated'] as int;
        final time = stopwatch.elapsedMilliseconds;

        results.recordBenchmark(
          'Sicilian Defense - Medium',
          nodes,
          time,
          stats['zobristHits'] as int? ?? 0,
          stats['zobristMisses'] as int? ?? 0,
        );

        print(
            'Sicilian - Nodes: $nodes, Time: ${time}ms, Rate: ${(nodes / (time / 1000)).toStringAsFixed(0)} nodes/sec');
      });
    });

    group('Zobrist Cache Efficiency', () {
      test('cache hit rate - repeated positions', () {
        // First search
        engine.getBestMove();
        var stats = engine.getSearchStats();
        final firstHits = stats['zobristHits'] as int;
        final firstMisses = stats['zobristMisses'] as int;
        final firstTotal = firstHits + firstMisses;

        // Second search (same position)
        engine.getBestMove();
        stats = engine.getSearchStats();
        final secondHits = stats['zobristHits'] as int;
        final secondMisses = stats['zobristMisses'] as int;
        final secondTotal = secondHits + secondMisses;

        // Additional hits should come from cache
        final additionalHits = secondHits - firstHits;

        results.recordCachePerformance(
          'Zobrist Hit Rate',
          firstHits,
          firstMisses,
          firstTotal > 0
              ? (firstHits / firstTotal * 100).toStringAsFixed(1)
              : '0.0',
        );

        print('Zobrist Performance:');
        print(
            '  First search - Hits: $firstHits, Misses: $firstMisses, Rate: ${(firstHits / (firstHits + firstMisses) * 100).toStringAsFixed(1)}%');
        print('  Second search - Additional hits: $additionalHits');

        expect(firstTotal, greaterThan(0));
      });

      test('transposition table growth', () {
        engine.getBestMove();
        var tableStats = engine.getTableStats();
        final entries1 = tableStats['entries'] as int;

        engine.getBestMove();
        tableStats = engine.getTableStats();
        final entries2 = tableStats['entries'] as int;

        results.recordTableGrowth(
          'TT Growth',
          entries1,
          entries2,
        );

        print('Transposition Table:');
        print('  First search - Entries: $entries1');
        print('  Second search - Entries: $entries2');
        print('  Growth: ${entries2 - entries1}');

        expect(entries2, greaterThanOrEqualTo(entries1));
      });
    });

    group('Move Ordering Effectiveness', () {
      test('killer move contribution to pruning', () {
        // Play several moves to build killer move data
        for (int i = 0; i < 6; i++) {
          final move = engine.getBestMove();
          if (move != null) {
            chess.makeMove(move.substring(0, 2), move.substring(2, 4));
          }
          if (chess.isGameOver()) break;
        }

        final stats = engine.getSearchStats();
        final killerStats = stats['killerStats'] as Map?;

        results.recordHeuristicUsage(
          'Killer Moves',
          killerStats?['totalCutoffs'] as int? ?? 0,
        );

        print('Killer Move Statistics:');
        print('  Total cutoffs: ${killerStats?['totalCutoffs'] ?? 0}');
        print('  Total killers: ${killerStats?['totalKillers'] ?? 0}');
      });

      test('countermove contribution to pruning', () {
        // Play several moves to build countermove data
        for (int i = 0; i < 6; i++) {
          final move = engine.getBestMove();
          if (move != null) {
            chess.makeMove(move.substring(0, 2), move.substring(2, 4));
          }
          if (chess.isGameOver()) break;
        }

        final stats = engine.getSearchStats();
        final countermoveStats = stats['countermoveStats'] as Map?;

        results.recordHeuristicUsage(
          'Countermoves',
          countermoveStats?['totalCutoffs'] as int? ?? 0,
        );

        print('Countermove Statistics:');
        print('  Total cutoffs: ${countermoveStats?['totalCutoffs'] ?? 0}');
        print(
            '  Total countermoves: ${countermoveStats?['totalCountermoves'] ?? 0}');
      });
    });

    group('Midgame Position Benchmarks', () {
      setUp(() {
        // Play to midgame
        final moves = [
          ('e2', 'e4'),
          ('c7', 'c5'),
          ('g1', 'f3'),
          ('d7', 'd6'),
          ('d2', 'd4'),
          ('c5', 'd4'),
          ('f3', 'd4'),
          ('g8', 'f6'),
          ('b1', 'c3'),
          ('a7', 'a6'),
          ('c1', 'e3'),
          ('e7', 'e5'),
          ('d4', 'f3'),
          ('b8', 'c6'),
        ];

        for (final (from, to) in moves) {
          chess.makeMove(from, to);
        }
      });

      test('medium difficulty - midgame position', () {
        final stopwatch = Stopwatch()..start();

        final move = engine.getBestMove();

        stopwatch.stop();
        expect(move, isNotNull);

        final stats = engine.getSearchStats();
        final nodes = stats['nodesEvaluated'] as int;
        final time = stopwatch.elapsedMilliseconds;

        results.recordBenchmark(
          'Midgame Position - Medium',
          nodes,
          time,
          stats['zobristHits'] as int? ?? 0,
          stats['zobristMisses'] as int? ?? 0,
        );

        print(
            'Midgame - Nodes: $nodes, Time: ${time}ms, Rate: ${(nodes / (time / 1000)).toStringAsFixed(0)} nodes/sec');
      });
    });

    group('Endgame Position Benchmarks', () {
      setUp(() {
        // Simplified endgame: White Queen + Rook, Black Queen + Rook
        // (manually simulated by playing to a tactical position)
        final moves = [
          ('e2', 'e4'),
          ('c7', 'c5'),
          ('g1', 'f3'),
          ('d7', 'd6'),
          ('d2', 'd4'),
          ('c5', 'd4'),
          ('f3', 'd4'),
          ('g8', 'f6'),
          ('b1', 'c3'),
          ('a7', 'a6'),
          ('c1', 'e3'),
          ('e7', 'e5'),
          ('d4', 'f3'),
          ('b8', 'c6'),
          ('f1', 'e2'),
          ('f8', 'e7'),
          ('e1', 'g1'),
          ('e8', 'g8'),
          ('a1', 'd1'),
          ('c6', 'e5'),
          ('d1', 'd8'),
          ('f8', 'd8'),
        ];

        for (final (from, to) in moves) {
          if (!chess.makeMove(from, to)) break;
        }
      });

      test('medium difficulty - endgame position', () {
        final stopwatch = Stopwatch()..start();

        final move = engine.getBestMove();

        stopwatch.stop();
        expect(move, isNotNull);

        final stats = engine.getSearchStats();
        final nodes = stats['nodesEvaluated'] as int;
        final time = stopwatch.elapsedMilliseconds;

        results.recordBenchmark(
          'Endgame Position - Medium',
          nodes,
          time,
          stats['zobristHits'] as int? ?? 0,
          stats['zobristMisses'] as int? ?? 0,
        );

        print(
            'Endgame - Nodes: $nodes, Time: ${time}ms, Rate: ${(nodes / (time / 1000)).toStringAsFixed(0)} nodes/sec');
      });
    });

    group('Opening Book Performance', () {
      test('book move vs search move time comparison', () {
        // Position in extended book (should be very fast)
        final moves = [
          ('e2', 'e4'),
          ('c7', 'c5'),
        ];

        for (final (from, to) in moves) {
          chess.makeMove(from, to);
        }

        final stopwatch = Stopwatch()..start();
        final bookMove = engine.getBestMove();
        stopwatch.stop();

        final bookTime = stopwatch.elapsedMilliseconds;
        expect(bookMove, isNotNull);

        results.recordBookPerformance(
          'Sicilian After 1.e4 c5',
          bookTime,
          true, // is in book
        );

        print('Book Performance:');
        print('  Move: $bookMove, Time: ${bookTime}ms (in book)');

        // Book moves should be very fast
        expect(bookTime, lessThan(100));
      });

      test('non-book position requires search', () {
        // Play out of book
        final moves = [
          ('e2', 'e4'),
          ('c7', 'c5'),
          ('g1', 'f3'),
          ('d7', 'd6'),
          ('d2', 'd4'),
          ('c5', 'd4'),
          ('f3', 'd4'),
          ('g8', 'f6'),
          ('b1', 'c3'),
          ('a7', 'a6'),
          ('c1', 'e3'),
          ('e7', 'e5'),
          ('d4', 'f3'),
          ('b8', 'c6'),
          ('f1', 'e2'),
          ('f8', 'e7'),
          ('e1', 'g1'),
          ('e8', 'g8'),
          ('a1', 'd1'),
          ('c6', 'e5'),
          ('f3', 'e5'),
          ('d6', 'e5'),
          ('d1', 'd5'),
        ];

        for (final (from, to) in moves) {
          if (!chess.makeMove(from, to)) break;
        }

        final stopwatch = Stopwatch()..start();
        final searchMove = engine.getBestMove();
        stopwatch.stop();

        final searchTime = stopwatch.elapsedMilliseconds;
        expect(searchMove, isNotNull);

        results.recordBookPerformance(
          'Position Out of Book',
          searchTime,
          false, // not in book
        );

        print('Search Performance:');
        print('  Move: $searchMove, Time: ${searchTime}ms (not in book)');
      });
    });

    group('Summary Report', () {
      test('print benchmark summary', () {
        print('\n${results.getSummary()}');
      });
    });
  });
}

/// Collects and aggregates benchmark results
class BenchmarkResults {
  final List<BenchmarkEntry> _benchmarks = [];
  final List<CacheEntry> _cacheEntries = [];
  final List<TableGrowthEntry> _tableGrowth = [];
  final List<HeuristicEntry> _heuristics = [];
  final List<BookEntry> _bookEntries = [];

  void recordBenchmark(
    String name,
    int nodes,
    int timeMs,
    int zobristHits,
    int zobristMisses,
  ) {
    _benchmarks.add(BenchmarkEntry(
      name: name,
      nodes: nodes,
      timeMs: timeMs,
      zobristHits: zobristHits,
      zobristMisses: zobristMisses,
    ));
  }

  void recordCachePerformance(
    String name,
    int hits,
    int misses,
    String hitRate,
  ) {
    _cacheEntries.add(CacheEntry(
      name: name,
      hits: hits,
      misses: misses,
      hitRate: hitRate,
    ));
  }

  void recordTableGrowth(
    String name,
    int entriesAfterFirst,
    int entriesAfterSecond,
  ) {
    _tableGrowth.add(TableGrowthEntry(
      name: name,
      firstSearch: entriesAfterFirst,
      secondSearch: entriesAfterSecond,
    ));
  }

  void recordHeuristicUsage(String name, int cutoffs) {
    _heuristics.add(HeuristicEntry(
      name: name,
      cutoffs: cutoffs,
    ));
  }

  void recordBookPerformance(String name, int timeMs, bool isInBook) {
    _bookEntries.add(BookEntry(
      name: name,
      timeMs: timeMs,
      isInBook: isInBook,
    ));
  }

  String getSummary() {
    final buffer = StringBuffer();

    buffer.writeln(
        '\n═══════════════════════════════════════════════════════════════');
    buffer
        .writeln('AI OPPONENT ENGINE ENHANCED - PERFORMANCE BENCHMARK REPORT');
    buffer.writeln(
        '═══════════════════════════════════════════════════════════════\n');

    // Benchmark Summary
    if (_benchmarks.isNotEmpty) {
      buffer.writeln('PERFORMANCE BENCHMARKS');
      buffer.writeln(
          '─────────────────────────────────────────────────────────────');
      for (final bench in _benchmarks) {
        final rate = (bench.nodes / (bench.timeMs / 1000)).toStringAsFixed(0);
        final hitRate = bench.zobristHits + bench.zobristMisses > 0
            ? (bench.zobristHits /
                    (bench.zobristHits + bench.zobristMisses) *
                    100)
                .toStringAsFixed(1)
            : '0.0';

        buffer.writeln('${bench.name}');
        buffer.writeln(
            '  Nodes: ${bench.nodes} | Time: ${bench.timeMs}ms | Rate: $rate nodes/sec');
        buffer.writeln(
            '  Zobrist Hit Rate: $hitRate% (${bench.zobristHits} hits, ${bench.zobristMisses} misses)');
      }
      buffer.writeln('');
    }

    // Cache Performance
    if (_cacheEntries.isNotEmpty) {
      buffer.writeln('CACHE EFFICIENCY');
      buffer.writeln(
          '─────────────────────────────────────────────────────────────');
      for (final cache in _cacheEntries) {
        buffer.writeln('${cache.name}');
        buffer.writeln(
            '  Hits: ${cache.hits} | Misses: ${cache.misses} | Hit Rate: ${cache.hitRate}%');
      }
      buffer.writeln('');
    }

    // Table Growth
    if (_tableGrowth.isNotEmpty) {
      buffer.writeln('TRANSPOSITION TABLE GROWTH');
      buffer.writeln(
          '─────────────────────────────────────────────────────────────');
      for (final growth in _tableGrowth) {
        buffer.writeln('${growth.name}');
        buffer.writeln('  First search: ${growth.firstSearch} entries');
        buffer.writeln('  Second search: ${growth.secondSearch} entries');
        buffer.writeln(
            '  Growth: ${growth.secondSearch - growth.firstSearch} entries');
      }
      buffer.writeln('');
    }

    // Heuristic Usage
    if (_heuristics.isNotEmpty) {
      buffer.writeln('HEURISTIC EFFECTIVENESS');
      buffer.writeln(
          '─────────────────────────────────────────────────────────────');
      for (final heur in _heuristics) {
        buffer.writeln('${heur.name}');
        buffer.writeln('  Total cutoffs: ${heur.cutoffs}');
      }
      buffer.writeln('');
    }

    // Book Performance
    if (_bookEntries.isNotEmpty) {
      buffer.writeln('OPENING BOOK PERFORMANCE');
      buffer.writeln(
          '─────────────────────────────────────────────────────────────');
      for (final book in _bookEntries) {
        buffer.writeln('${book.name}');
        buffer.writeln(
            '  Time: ${book.timeMs}ms | In Book: ${book.isInBook ? 'Yes' : 'No'}');
      }
      buffer.writeln('');
    }

    // Performance Summary
    if (_benchmarks.isNotEmpty) {
      buffer.writeln('PERFORMANCE SUMMARY');
      buffer.writeln(
          '─────────────────────────────────────────────────────────────');

      double avgRate = 0;
      for (final bench in _benchmarks) {
        avgRate += bench.nodes / (bench.timeMs / 1000);
      }
      avgRate /= _benchmarks.length;

      buffer.writeln(
          'Average Node Evaluation Rate: ${avgRate.toStringAsFixed(0)} nodes/sec');

      double avgCacheHitRate = 0;
      int validCacheEntries = 0;
      for (final bench in _benchmarks) {
        final total = bench.zobristHits + bench.zobristMisses;
        if (total > 0) {
          avgCacheHitRate += bench.zobristHits / total;
          validCacheEntries++;
        }
      }
      if (validCacheEntries > 0) {
        buffer.writeln(
            'Average Zobrist Hit Rate: ${(avgCacheHitRate / validCacheEntries * 100).toStringAsFixed(1)}%');
      }
    }

    buffer.writeln(
        '═══════════════════════════════════════════════════════════════\n');

    return buffer.toString();
  }
}

class BenchmarkEntry {
  final String name;
  final int nodes;
  final int timeMs;
  final int zobristHits;
  final int zobristMisses;

  BenchmarkEntry({
    required this.name,
    required this.nodes,
    required this.timeMs,
    required this.zobristHits,
    required this.zobristMisses,
  });
}

class CacheEntry {
  final String name;
  final int hits;
  final int misses;
  final String hitRate;

  CacheEntry({
    required this.name,
    required this.hits,
    required this.misses,
    required this.hitRate,
  });
}

class TableGrowthEntry {
  final String name;
  final int firstSearch;
  final int secondSearch;

  TableGrowthEntry({
    required this.name,
    required this.firstSearch,
    required this.secondSearch,
  });
}

class HeuristicEntry {
  final String name;
  final int cutoffs;

  HeuristicEntry({
    required this.name,
    required this.cutoffs,
  });
}

class BookEntry {
  final String name;
  final int timeMs;
  final bool isInBook;

  BookEntry({
    required this.name,
    required this.timeMs,
    required this.isInBook,
  });
}
