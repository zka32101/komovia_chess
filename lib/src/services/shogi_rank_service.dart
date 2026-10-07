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
  static double progressToNextRank(int eloRating, ShogiRank currentRank) {
    final nextRank = calculateRank(eloRating + 100);

    if (currentRank == nextRank) {
      // 次の段位のしきい値を取得
      final threshold = _getNextThreshold(currentRank);
      final previousThreshold = _getPreviousThreshold(currentRank);

      final range = threshold - previousThreshold;
      final current = eloRating - previousThreshold;

      return (current / range).clamp(0.0, 1.0);
    }

    return 0;
  }

  static int _getNextThreshold(ShogiRank rank) => rank.when(
        dan: (level) {
          switch (level) {
            case 1:
              return dan1Threshold;
            case 2:
              return 1450;
            case 3:
              return dan3Threshold;
            case 4:
              return 1600;
            case 5:
              return 1700;
            case 6:
              return 1800;
            case 7:
              return dan7Threshold;
            case 8:
              return 2000;
            default:
              return 2000;
          }
        },
        kyu: (level) {
          switch (level) {
            case 1:
              return dan1Threshold;
            case 3:
              return kyu1Threshold;
            case 5:
              return kyu5Threshold;
            case 10:
              return 1050;
            case 15:
              return 650;
            case 20:
              return 500;
            default:
              return 1400;
          }
        },
      );

  static int _getPreviousThreshold(ShogiRank rank) => rank.when(
        dan: (level) {
          switch (level) {
            case 1:
              return 900;
            case 2:
              return 1000;
            case 3:
              return kyu1Threshold;
            case 4:
              return 1500;
            case 5:
              return dan1Threshold;
            case 6:
              return 1700;
            case 7:
              return 1800;
            case 8:
              return dan7Threshold;
            default:
              return 1900;
          }
        },
        kyu: (level) {
          switch (level) {
            case 1:
              return 750;
            case 3:
              return 900;
            case 5:
              return 1000;
            case 10:
              return 700;
            case 15:
              return 500;
            case 20:
              return 0;
            default:
              return 800;
          }
        },
      );
}

/// 将棋の段位を表すクラス
@freezed
class ShogiRank with _$ShogiRank {
  const factory ShogiRank.dan(int level) = _Dan;
  const factory ShogiRank.kyu(int level) = _Kyu;

  factory ShogiRank.fromJson(Map<String, dynamic> json) =>
      _$ShogiRankFromJson(json);
}
