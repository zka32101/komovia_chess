import 'package:komovia_core/komovia_core.dart';

import 'user.dart';

/// How a frame's unlock is evaluated.
///
/// * [live] - recomputed from the user's *current* stats every time
///   (counters that only ever go up: wins, gamesPlayed, puzzlesSolved).
/// * [peak] - a point-in-time achievement ("reached rating X at some
///   point", "had a 7-day puzzle streak"). The current value can drop
///   later, so once earned the id is persisted in
///   `UserModel.unlockedFrameIds` and stays unlocked forever.
///
/// * [lifetimePurchase] - never earned from stats: granted (persisted in
///   `unlockedFrameIds`) only when the user buys the premium lifetime
///   plan. Backed by komovia_core [AvatarFrame.lifetimeExclusive].
enum FrameUnlockKind { live, peak, lifetimePurchase }

/// Which tracked stat a frame's threshold is measured against.
enum FrameStat { wins, gamesPlayed, puzzlesSolved, rating, puzzleStreak }

/// App-specific unlock condition for one komovia_core [AvatarFrame].
class AvatarFrameRequirement {
  const AvatarFrameRequirement({
    required this.frame,
    required this.stat,
    required this.threshold,
    required this.kind,
  });

  /// A frame granted only by the premium lifetime purchase.
  const AvatarFrameRequirement.lifetimeExclusive(this.frame)
    : stat = null,
      threshold = 0,
      kind = FrameUnlockKind.lifetimePurchase;

  final AvatarFrame frame;
  final FrameStat? stat;
  final int threshold;
  final FrameUnlockKind kind;

  int _valueOf(UserModel user) => switch (stat) {
    null => 0,
    FrameStat.wins => user.wins,
    FrameStat.gamesPlayed => user.gamesPlayed,
    FrameStat.puzzlesSolved => user.puzzlesSolved,
    FrameStat.rating => user.rating,
    FrameStat.puzzleStreak => user.dailyStreak,
  };

  /// Whether the user's *current* stats meet the threshold.
  /// Lifetime-purchase frames are never met by stats.
  bool isMetBy(UserModel user) =>
      kind != FrameUnlockKind.lifetimePurchase && _valueOf(user) >= threshold;
}

/// Free, earn-only avatar frames. Never purchasable - no IAP surface.
/// Ids are stable once shipped (persisted in Firestore).
const List<AvatarFrameRequirement> kAvatarFrames = [
  // Bronze
  AvatarFrameRequirement(
    frame: AvatarFrame(id: 'first_win', name: 'First Win'),
    stat: FrameStat.wins,
    threshold: 1,
    kind: FrameUnlockKind.live,
  ),
  AvatarFrameRequirement(
    frame: AvatarFrame(id: 'games_10', name: '10 Games'),
    stat: FrameStat.gamesPlayed,
    threshold: 10,
    kind: FrameUnlockKind.live,
  ),
  AvatarFrameRequirement(
    frame: AvatarFrame(id: 'first_puzzle', name: 'First Puzzle'),
    stat: FrameStat.puzzlesSolved,
    threshold: 1,
    kind: FrameUnlockKind.live,
  ),
  // Silver
  AvatarFrameRequirement(
    frame: AvatarFrame(
      id: 'rating_1400',
      name: 'Rating 1400',
      tier: FrameTier.silver,
    ),
    stat: FrameStat.rating,
    threshold: 1400,
    kind: FrameUnlockKind.peak,
  ),
  AvatarFrameRequirement(
    frame: AvatarFrame(
      id: 'puzzles_50',
      name: '50 Puzzles',
      tier: FrameTier.silver,
    ),
    stat: FrameStat.puzzlesSolved,
    threshold: 50,
    kind: FrameUnlockKind.live,
  ),
  AvatarFrameRequirement(
    frame: AvatarFrame(
      id: 'games_100',
      name: '100 Games',
      tier: FrameTier.silver,
    ),
    stat: FrameStat.gamesPlayed,
    threshold: 100,
    kind: FrameUnlockKind.live,
  ),
  // Gold
  AvatarFrameRequirement(
    frame: AvatarFrame(
      id: 'rating_1800',
      name: 'Rating 1800',
      tier: FrameTier.gold,
    ),
    stat: FrameStat.rating,
    threshold: 1800,
    kind: FrameUnlockKind.peak,
  ),
  AvatarFrameRequirement(
    frame: AvatarFrame(
      id: 'puzzle_streak_7',
      name: '7-Day Puzzle Streak',
      tier: FrameTier.gold,
    ),
    stat: FrameStat.puzzleStreak,
    threshold: 7,
    kind: FrameUnlockKind.peak,
  ),
  AvatarFrameRequirement(
    frame: AvatarFrame(id: 'wins_50', name: '50 Wins', tier: FrameTier.gold),
    stat: FrameStat.wins,
    threshold: 50,
    kind: FrameUnlockKind.live,
  ),
  // Platinum
  AvatarFrameRequirement(
    frame: AvatarFrame(
      id: 'rating_2000',
      name: 'Rating 2000',
      tier: FrameTier.platinum,
    ),
    stat: FrameStat.rating,
    threshold: 2000,
    kind: FrameUnlockKind.peak,
  ),
  AvatarFrameRequirement(
    frame: AvatarFrame(
      id: 'puzzles_500',
      name: '500 Puzzles',
      tier: FrameTier.platinum,
    ),
    stat: FrameStat.puzzlesSolved,
    threshold: 500,
    kind: FrameUnlockKind.live,
  ),
  // Lifetime-purchase exclusive (granted by PaywallService on a premium
  // lifetime purchase; never earnable, never sold on its own).
  AvatarFrameRequirement.lifetimeExclusive(
    AvatarFrame(
      id: 'eternal_laurel',
      name: 'Eternal Laurel',
      tier: FrameTier.platinum,
      lifetimeExclusive: true,
    ),
  ),
];

/// Ids of frames granted automatically by the premium lifetime purchase.
List<String> get lifetimeExclusiveFrameIds => [
  for (final r in kAvatarFrames)
    if (r.frame.lifetimeExclusive) r.frame.id,
];

AvatarFrameRequirement? avatarFrameById(String? id) {
  if (id == null) return null;
  for (final r in kAvatarFrames) {
    if (r.frame.id == id) return r;
  }
  return null;
}

/// Every frame id currently unlocked: live frames from current stats,
/// plus persisted point-in-time unlocks, plus peak frames whose condition
/// is met right now (even if not yet persisted).
Set<String> unlockedFrameIdsFor(UserModel user) => {
  ...user.unlockedFrameIds.where((id) => avatarFrameById(id) != null),
  for (final r in kAvatarFrames)
    if (r.isMetBy(user)) r.frame.id,
};

/// Peak (point-in-time) frame ids met by [user]'s current stats that are
/// not yet persisted - the caller should arrayUnion these.
List<String> newlyEarnedPeakFrameIds(UserModel user) => [
  for (final r in kAvatarFrames)
    if (r.kind == FrameUnlockKind.peak &&
        r.isMetBy(user) &&
        !user.unlockedFrameIds.contains(r.frame.id))
      r.frame.id,
];

/// Peak frame ids earned by reaching [rating] / [puzzleStreak] - used at
/// the self-write sites (CPU game result, puzzle solve) so a peak is
/// persisted the moment it happens, even if it later drops.
List<String> peakFrameIdsForStats({int? rating, int? puzzleStreak}) => [
  for (final r in kAvatarFrames)
    if (r.kind == FrameUnlockKind.peak &&
        ((r.stat == FrameStat.rating &&
                rating != null &&
                rating >= r.threshold) ||
            (r.stat == FrameStat.puzzleStreak &&
                puzzleStreak != null &&
                puzzleStreak >= r.threshold)))
      r.frame.id,
];

/// The frame to actually render: the user's selection if it's a known
/// frame and currently unlocked, else null (no frame).
AvatarFrame? resolveDisplayedFrame(UserModel? user) {
  if (user == null) return null;
  final req = avatarFrameById(user.frameId);
  if (req == null) return null;
  if (!AvatarFrame.isUnlocked(req.frame.id, unlockedFrameIdsFor(user))) {
    return null;
  }
  return req.frame;
}
