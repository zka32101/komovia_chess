import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Cumulative reward totals credited to `user_rewards/{uid}` by
/// [SeasonChallengeService.claimChallengeRewards] and
/// [TournamentService.distributePrizes]. Both services write to this
/// collection, but prior to this provider nothing in the app ever read it
/// back - tapping "Claim Reward" on the Seasonal Hub, or placing in a
/// tournament's prize payout, silently incremented these fields in
/// Firestore with no UI anywhere showing the player what they now have.
class UserRewards {
  const UserRewards({
    required this.totalChallengeCurrency,
    required this.totalChallengeExperience,
    required this.totalPrizeWinnings,
  });

  factory UserRewards.fromFirestore(Map<String, dynamic>? data) {
    final d = data ?? const <String, dynamic>{};
    return UserRewards(
      totalChallengeCurrency: (d['totalChallengeCurrency'] as num?)?.toInt() ?? 0,
      totalChallengeExperience:
          (d['totalChallengeExperience'] as num?)?.toInt() ?? 0,
      totalPrizeWinnings: (d['totalPrizeWinnings'] as num?)?.toInt() ?? 0,
    );
  }

  static const empty = UserRewards(
    totalChallengeCurrency: 0,
    totalChallengeExperience: 0,
    totalPrizeWinnings: 0,
  );

  final int totalChallengeCurrency;
  final int totalChallengeExperience;
  final int totalPrizeWinnings;
}

/// A user's cumulative season-challenge and tournament-prize rewards.
/// Not found (never claimed/won anything yet) resolves to [UserRewards.empty]
/// rather than erroring.
final userRewardsProvider =
    FutureProvider.family<UserRewards, String>((ref, uid) async {
  final doc =
      await FirebaseFirestore.instance.collection('user_rewards').doc(uid).get();
  if (!doc.exists) return UserRewards.empty;
  return UserRewards.fromFirestore(doc.data());
});
