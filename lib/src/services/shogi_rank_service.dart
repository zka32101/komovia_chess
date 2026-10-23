import 'package:freezed_annotation/freezed_annotation.dart';

part 'shogi_rank_service.freezed.dart';
part 'shogi_rank_service.g.dart';

/// 将棋式ランキング（段位・級位）の管理サービス
///
/// ELOレーティングを将棋の段位（段/級）に変換します
/// - 級（きゅう）: 30級～1級（初心者レベル、1級が最高級）
/// - 段（だん）: 1段～8段（上級者レベル、8段が最高段）
class ShogiRankService {
  // 段位のしきい値（ELO）
  static const int kyuThreshold = 1000; // 級から段への境界
  static const int kyu1Threshold = 1200; // 1級
  static const int kyu5Threshold = 1100; // 5級
  static const int dan1Threshold = 1400; // 1段
  static const int dan3Threshold = 1550; // 3段
  static const int dan5Threshold = 1750; // 5段
  static const int dan7Threshold = 1900; // 7段

  /// ELOレーティングから将棋の段位を計算する
  static ShogiRank calculateRank(int eloRating) {
    if (eloRating >= dan7Threshold) {
      return const ShogiRank.dan(8);
    } else if (eloRating >= dan5Threshold) {
      return const ShogiRank.dan(7);
    } else if (eloRating >= dan3Threshold) {
      return const ShogiRank.dan(6);
    } else if (eloRating >= dan1Threshold) {
      return const ShogiRank.dan(5);
    } else if (eloRating >= kyu1Threshold) {
      return const ShogiRank.dan(4);
    } else if (eloRating >= kyu5Threshold) {
      return const ShogiRank.dan(3);
    } else if (eloRating >= kyuThreshold) {
      return const ShogiRank.dan(2);
    } else if (eloRating >= 900) {
      return const ShogiRank.dan(1);
    } else if (eloRating >= 800) {
      return const ShogiRank.kyu(1);
    } else if (eloRating >= 700) {
      return const ShogiRank.kyu(3);
    } else if (eloRating >= 600) {
      return const ShogiRank.kyu(5);
    } else if (eloRating >= 500) {
      return const ShogiRank.kyu(10);
    } else if (eloRating >= 400) {
      return const ShogiRank.kyu(15);
    } else {
      return const ShogiRank.kyu(20);
    }
  }

  /// Every rank [calculateRank] can actually produce, ascending by rating.
  /// Used to drive rank-tier leaderboard filtering (see
  /// [ratingRangeForRank]) and the rank-picker UI - [calculateRank] only
  /// ever returns one of these 14 values (kyu 20/15/10/5/3/1, dan 1-8), so
  /// anything outside this list (e.g. "17級", "9級") can never match a
  /// real player and must not be offered as a filter choice.
  static const List<ShogiRank> allRanks = [
    ShogiRank.kyu(20),
    ShogiRank.kyu(15),
    ShogiRank.kyu(10),
    ShogiRank.kyu(5),
    ShogiRank.kyu(3),
    ShogiRank.kyu(1),
    ShogiRank.dan(1),
    ShogiRank.dan(2),
    ShogiRank.dan(3),
    ShogiRank.dan(4),
    ShogiRank.dan(5),
    ShogiRank.dan(6),
    ShogiRank.dan(7),
    ShogiRank.dan(8),
  ];

  /// The ELO rating range (inclusive `min`, exclusive `max`) that
  /// produces [rank] via [calculateRank] - `min` is null for the
  /// bottom-most rank (no lower bound) and `max` is null for the
  /// top-most rank (no upper bound).
  /// Derived directly from the same ladder [calculateRank] uses, so
  /// there's one source of truth for rank boundaries (also used by
  /// [progressToNextRank] below).
  static (int? min, int? max) ratingRangeForRank(ShogiRank rank) {
    const bounds = <int?>[
      null, 400, 500, 600, 700, 800, 900, kyuThreshold, //
      kyu5Threshold, kyu1Threshold, dan1Threshold, dan3Threshold, //
      dan5Threshold, dan7Threshold, null,
    ];
    final index = allRanks.indexWhere((r) => r == rank);
    if (index < 0) return (null, null);
    return (bounds[index], bounds[index + 1]);
  }

  /// 段位から表示用文字列を取得する
  /// 例: "3段", "5級"
  static String displayName(ShogiRank rank) => rank.when(
        dan: (level) => '$level段',
        kyu: (level) => '$level級',
      );

  /// 段位から説明テキストを取得する
  static String getDescription(ShogiRank rank) => rank.when(
        dan: (level) {
          switch (level) {
            case 8:
              return 'プロ棋士レベル - 最高段階';
            case 7:
              return '高段者 - エキスパート';
            case 6:
              return '高段者 - 上級者';
            case 5:
              return '中段者 - 上級者';
            case 4:
              return '初段 - 中級者';
            case 3:
              return '初段 - 中級者';
            case 2:
              return '初段 - 中級者';
            case 1:
              return '初段 - 初級上級者';
            default:
              return '段位';
          }
        },
        kyu: (level) {
          switch (level) {
            case 1:
              return '1級 - 初心者上級';
            case 3:
              return '3級 - 初心者中級';
            case 5:
              return '5級 - 初心者';
            case 10:
              return '10級 - 初心者';
            case 15:
              return '15級 - ビギナー';
            case 20:
              return '20級 - ビギナー';
            default:
              return '級位';
          }
        },
      );

  /// 進行度を計算する（0.0～1.0）
  /// 次の段位までの進捗を表します
  ///
  /// Previously relied on a separate, stale `_getNextThreshold`/
  /// `_getPreviousThreshold` table that didn't match [calculateRank]'s
  /// real boundaries, and only computed a nonzero result when
  /// `calculateRank(eloRating + 100) == currentRank` - for any rank
  /// exactly 100 ELO wide (8 of the 14 ranks: kyu15/10/5/3/1, dan1/2/3),
  /// adding 100 always crosses into the next rank, so that condition was
  /// never true and the progress bar stayed stuck at 0% for the
  /// majority of the rank ladder. Now derives the current rank's own
  /// real min/max boundaries from [ratingRangeForRank] - the same
  /// table [calculateRank] itself is built on - so there's one source of
  /// truth for rank boundaries instead of two that can drift apart.
  static double progressToNextRank(int eloRating, ShogiRank currentRank) {
    final (min, max) = ratingRangeForRank(currentRank);
    // No upper bound (the top rank, dan8) - already maxed out.
    if (max == null) return 1.0;
    // No lower bound (the bottom rank, kyu20) - use 0 as the floor so
    // progress still reads as a sensible fraction of the way to kyu15.
    final lower = min ?? 0;
    final range = max - lower;
    if (range <= 0) return 0;
    final current = eloRating - lower;
    return (current / range).clamp(0.0, 1.0);
  }
}

/// 将棋の段位を表すクラス
@freezed
abstract class ShogiRank with _$ShogiRank {
  const factory ShogiRank.dan(int level) = _Dan;
  const factory ShogiRank.kyu(int level) = _Kyu;

  factory ShogiRank.fromJson(Map<String, dynamic> json) =>
      _$ShogiRankFromJson(json);
}
