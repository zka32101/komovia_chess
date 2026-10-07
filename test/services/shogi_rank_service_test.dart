import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_chess/src/services/shogi_rank_service.dart';

void main() {
  group('ShogiRankService', () {
    group('calculateRank', () {
      test('should return 20級 for very low ELO (< 500)', () {
        final rank = ShogiRankService.calculateRank(400);
        expect(rank, isA<_Kyu>());
        expect(
            rank.maybeMap(
              kyu: (k) => k.level,
              orElse: () => -1,
            ),
            equals(20));
      });

      test('should return 15級 for low ELO (500-600)', () {
        final rank = ShogiRankService.calculateRank(550);
        expect(rank, isA<_Kyu>());
        expect(
            rank.maybeMap(
              kyu: (k) => k.level,
              orElse: () => -1,
            ),
            equals(15));
      });

      test('should return 10級 for beginner ELO (600-700)', () {
        final rank = ShogiRankService.calculateRank(650);
        expect(rank, isA<_Kyu>());
        expect(
            rank.maybeMap(
              kyu: (k) => k.level,
              orElse: () => -1,
            ),
            equals(10));
      });

      test('should return 5級 for intermediate ELO (700-800)', () {
        final rank = ShogiRankService.calculateRank(750);
        expect(rank, isA<_Kyu>());
        expect(
            rank.maybeMap(
              kyu: (k) => k.level,
              orElse: () => -1,
            ),
            equals(5));
      });

      test('should return 3級 for intermediate-high ELO (800-900)', () {
        final rank = ShogiRankService.calculateRank(850);
        expect(rank, isA<_Kyu>());
        expect(
            rank.maybeMap(
              kyu: (k) => k.level,
              orElse: () => -1,
            ),
            equals(3));
      });

      test('should return 1級 for advanced ELO (800+)', () {
        final rank = ShogiRankService.calculateRank(800);
        expect(rank, isA<_Kyu>());
        expect(
            rank.maybeMap(
              kyu: (k) => k.level,
              orElse: () => -1,
            ),
            equals(1));
      });

      test('should return 1段 for dan level ELO (900+)', () {
        final rank = ShogiRankService.calculateRank(900);
        expect(rank, isA<_Dan>());
        expect(
            rank.maybeMap(
              dan: (d) => d.level,
              orElse: () => -1,
            ),
            equals(1));
      });

      test('should return 2段 for ELO 1000+', () {
        final rank = ShogiRankService.calculateRank(1000);
        expect(rank, isA<_Dan>());
        expect(
            rank.maybeMap(
              dan: (d) => d.level,
              orElse: () => -1,
            ),
            equals(2));
      });

      test('should return 3段 for ELO 1100+', () {
        final rank = ShogiRankService.calculateRank(1100);
        expect(rank, isA<_Dan>());
        expect(
            rank.maybeMap(
              dan: (d) => d.level,
              orElse: () => -1,
            ),
            equals(3));
      });

      test('should return 4段 for ELO 1200+', () {
        final rank = ShogiRankService.calculateRank(1200);
        expect(rank, isA<_Dan>());
        expect(
            rank.maybeMap(
              dan: (d) => d.level,
              orElse: () => -1,
            ),
            equals(4));
      });

      test('should return 5段 for ELO 1400+', () {
        final rank = ShogiRankService.calculateRank(1400);
        expect(rank, isA<_Dan>());
        expect(
            rank.maybeMap(
              dan: (d) => d.level,
              orElse: () => -1,
            ),
            equals(5));
      });

      test('should return 6段 for ELO 1550+', () {
        final rank = ShogiRankService.calculateRank(1550);
        expect(rank, isA<_Dan>());
        expect(
            rank.maybeMap(
              dan: (d) => d.level,
              orElse: () => -1,
            ),
            equals(6));
      });

      test('should return 7段 for ELO 1750+', () {
        final rank = ShogiRankService.calculateRank(1750);
        expect(rank, isA<_Dan>());
        expect(
            rank.maybeMap(
              dan: (d) => d.level,
              orElse: () => -1,
            ),
            equals(7));
      });

      test('should return 8段 for ELO 1900+', () {
        final rank = ShogiRankService.calculateRank(1900);
        expect(rank, isA<_Dan>());
        expect(
            rank.maybeMap(
              dan: (d) => d.level,
              orElse: () => -1,
            ),
            equals(8));
      });

      test('should return 8段 for very high ELO (2000+)', () {
        final rank = ShogiRankService.calculateRank(2000);
        expect(rank, isA<_Dan>());
        expect(
            rank.maybeMap(
              dan: (d) => d.level,
              orElse: () => -1,
            ),
            equals(8));
      });
    });

    group('displayName', () {
      test('should format dan ranks correctly', () {
        expect(
          ShogiRankService.displayName(ShogiRank.dan(5)),
          equals('5段'),
        );
      });

      test('should format kyu ranks correctly', () {
        expect(
          ShogiRankService.displayName(ShogiRank.kyu(3)),
          equals('3級'),
        );
      });

      test('should format 1段 correctly', () {
        expect(
          ShogiRankService.displayName(ShogiRank.dan(1)),
          equals('1段'),
        );
      });

      test('should format 1級 correctly', () {
        expect(
          ShogiRankService.displayName(ShogiRank.kyu(1)),
          equals('1級'),
        );
      });
    });

    group('getDescription', () {
      test('should provide description for 1段', () {
        final desc = ShogiRankService.getDescription(ShogiRank.dan(1));
        expect(desc, contains('初段'));
        expect(desc, isNotEmpty);
      });

      test('should provide description for 8段', () {
        final desc = ShogiRankService.getDescription(ShogiRank.dan(8));
        expect(desc, contains('プロ'));
        expect(desc, isNotEmpty);
      });

      test('should provide description for 5段', () {
        final desc = ShogiRankService.getDescription(ShogiRank.dan(5));
        expect(desc, contains('中段'));
        expect(desc, isNotEmpty);
      });

      test('should provide description for 1級', () {
        final desc = ShogiRankService.getDescription(ShogiRank.kyu(1));
        expect(desc, isNotEmpty);
      });

      test('should provide description for 20級', () {
        final desc = ShogiRankService.getDescription(ShogiRank.kyu(20));
        expect(desc, contains('ビギナー'));
        expect(desc, isNotEmpty);
      });
    });

    group('progressToNextRank', () {
      test('should return progress value between 0 and 1', () {
        final progress =
            ShogiRankService.progressToNextRank(1000, ShogiRank.dan(2));
        expect(progress, greaterThanOrEqualTo(0.0));
        expect(progress, lessThanOrEqualTo(1.0));
      });

      test('should return 0 when transitioning between ranks', () {
        final rank = ShogiRankService.calculateRank(1000);
        final progress = ShogiRankService.progressToNextRank(1000, rank);
        // Should be close to 0 when just reached a new rank
        expect(progress, greaterThanOrEqualTo(0.0));
        expect(progress, lessThanOrEqualTo(1.0));
      });

      test('should show progress within a rank', () {
        // At 1050 ELO (between 1000 and 1100)
        const eloRating = 1050;
        final rank = ShogiRankService.calculateRank(eloRating);
        final progress = ShogiRankService.progressToNextRank(eloRating, rank);

        // Should show some progress
        expect(progress, greaterThan(0.0));
        expect(progress, lessThan(1.0));
      });
    });

    group('ShogiRank serialization', () {
      test('should serialize dan rank to JSON', () {
        final rank = ShogiRank.dan(5);
        final json = rank.toJson();
        expect(json, isA<Map<String, dynamic>>());
        expect(json['runtimeType'], equals('_Dan'));
      });

      test('should serialize kyu rank to JSON', () {
        final rank = ShogiRank.kyu(3);
        final json = rank.toJson();
        expect(json, isA<Map<String, dynamic>>());
        expect(json['runtimeType'], equals('_Kyu'));
      });

      test('should deserialize dan rank from JSON', () {
        final original = ShogiRank.dan(5);
        final json = original.toJson();
        final restored = ShogiRank.fromJson(json);

        expect(restored, isA<_Dan>());
        expect(
            restored.maybeMap(
              dan: (d) => d.level,
              orElse: () => -1,
            ),
            equals(5));
      });

      test('should deserialize kyu rank from JSON', () {
        final original = ShogiRank.kyu(3);
        final json = original.toJson();
        final restored = ShogiRank.fromJson(json);

        expect(restored, isA<_Kyu>());
        expect(
            restored.maybeMap(
              kyu: (k) => k.level,
              orElse: () => -1,
            ),
            equals(3));
      });
    });

    group('ELO to Shogi Rank progression', () {
      test('should show progression through kyu ranks', () {
        // Test progression from 20級 to 1級
        final rank400 = ShogiRankService.calculateRank(400);
        final rank800 = ShogiRankService.calculateRank(800);

        expect(rank400.maybeMap(kyu: (k) => k.level, orElse: () => -1),
            equals(20));
        expect(
            rank800.maybeMap(kyu: (k) => k.level, orElse: () => -1), equals(1));
      });

      test('should show progression through dan ranks', () {
        // Test progression from 1段 to 8段
        final rank900 = ShogiRankService.calculateRank(900);
        final rank2000 = ShogiRankService.calculateRank(2000);

        expect(
            rank900.maybeMap(dan: (d) => d.level, orElse: () => -1), equals(1));
        expect(rank2000.maybeMap(dan: (d) => d.level, orElse: () => -1),
            equals(8));
      });

      test('should transition from 1級 to 1段 at correct ELO', () {
        final rank799 = ShogiRankService.calculateRank(799);
        final rank900 = ShogiRankService.calculateRank(900);

        // Below 900 should be 1級
        expect(
            rank799.maybeMap(kyu: (k) => k.level, orElse: () => -1), equals(1));

        // At 900+ should be 1段
        expect(
            rank900.maybeMap(dan: (d) => d.level, orElse: () => -1), equals(1));
      });
    });

    group('Rank equality and comparison', () {
      test('should compare identical dan ranks', () {
        final rank1 = ShogiRank.dan(5);
        final rank2 = ShogiRank.dan(5);
        expect(rank1, equals(rank2));
      });

      test('should compare identical kyu ranks', () {
        final rank1 = ShogiRank.kyu(3);
        final rank2 = ShogiRank.kyu(3);
        expect(rank1, equals(rank2));
      });

      test('should distinguish different dan ranks', () {
        final rank1 = ShogiRank.dan(5);
        final rank2 = ShogiRank.dan(6);
        expect(rank1, isNot(equals(rank2)));
      });

      test('should distinguish different kyu ranks', () {
        final rank1 = ShogiRank.kyu(3);
        final rank2 = ShogiRank.kyu(5);
        expect(rank1, isNot(equals(rank2)));
      });

      test('should distinguish dan from kyu', () {
        final dan = ShogiRank.dan(1);
        final kyu = ShogiRank.kyu(1);
        expect(dan, isNot(equals(kyu)));
      });
    });
  });
}
