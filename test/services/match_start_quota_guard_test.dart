import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_chess/src/services/match_start_quota_guard.dart';

void main() {
  group('MatchStartQuotaGuard', () {
    test('joining then cancelling before a match consumes nothing', () {
      var consumed = 0;
      final guard = MatchStartQuotaGuard(() async => consumed++);
      // Queue joined and cancelled: onMatchStarted is never reached.
      expect(guard.hasConsumedFor('g1'), isFalse);
      expect(consumed, 0);
    });

    test('consumes exactly one slot once a match actually starts', () async {
      var consumed = 0;
      final guard = MatchStartQuotaGuard(() async => consumed++);
      await guard.onMatchStarted('g1');
      await guard.onMatchStarted('g1'); // rebuild of the queue stream
      expect(consumed, 1);
      await guard.onMatchStarted('g2');
      expect(consumed, 2);
    });

    test('tracking failure does not throw', () async {
      final guard = MatchStartQuotaGuard(() async => throw Exception('x'));
      await guard.onMatchStarted('g1');
      expect(guard.hasConsumedFor('g1'), isTrue);
    });
  });
}
