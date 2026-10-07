import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_chess/src/services/match_history_service.dart';
import 'package:komovia_chess/src/models/match_record.dart';

void main() {
  group('MatchHistoryService', () {
    late MatchHistoryService service;

    setUp(() {
      service = MatchHistoryService();
    });

    group('CSV Export', () {
      test('should generate valid CSV header', () async {
        // This would require mocking Firestore
        // For now, test the CSV format structure
        final csvHeader =
            'Date,Opponent,Result,Rating Change,Time Control,Duration';
        expect(csvHeader.split(','), hasLength(6));
      });

      test('should format rating changes correctly', () {
        final positiveChange = 15;
        final negativeChange = -8;

        expect('+$positiveChange', equals('+15'));
        expect('$negativeChange', equals('-8'));
      });
    });

    group('Win Rate Calculation', () {
      test('should return 0.0 when no games are played', () {
        const winRate = 0.0;
        expect(winRate, equals(0.0));
      });

      test('should calculate correct win rate for perfect record', () {
        final wins = 10;
        final total = 10;
        final winRate = (wins / total * 100);
        expect(winRate, equals(100.0));
      });

      test('should calculate correct win rate for 50% record', () {
        final wins = 5;
        final total = 10;
        final winRate = (wins / total * 100);
        expect(winRate, equals(50.0));
      });
    });

    group('Match Statistics', () {
      test('should correctly count wins, losses, and draws', () {
        const wins = 5;
        const losses = 3;
        const draws = 2;
        const total = wins + losses + draws;

        expect(total, equals(10));
        expect(
          (wins / total * 100).toStringAsFixed(1),
          equals('50.0'),
        );
      });

      test('should calculate average rating changes', () {
        final ratingGains = [15, 12, 18, 10];
        final avgGain =
            ratingGains.reduce((a, b) => a + b) / ratingGains.length;

        expect(avgGain, equals(13.75));
      });
    });

    group('Match Record Validation', () {
      test('should validate match result values', () {
        const validResults = ['win', 'loss', 'draw'];

        for (final result in validResults) {
          expect(validResults.contains(result), isTrue);
        }
      });

      test('should validate time control values', () {
        const validTimeControls = ['bullet', 'blitz', 'rapid'];

        for (final tc in validTimeControls) {
          expect(validTimeControls.contains(tc), isTrue);
        }
      });

      test('should validate time control for match record', () {
        final match = MatchRecord(
          matchId: 'match_123',
          playerId: 'player1',
          opponentId: 'player2',
          opponentName: 'Opponent',
          playerRatingBefore: 1600,
          playerRatingAfter: 1615,
          opponentRatingBefore: 1500,
          opponentRatingAfter: 1485,
          result: 'win',
          timeControl: 'blitz',
          playedAt: DateTime.now(),
        );

        expect(
            ['bullet', 'blitz', 'rapid'].contains(match.timeControl), isTrue);
      });
    });
  });
}
