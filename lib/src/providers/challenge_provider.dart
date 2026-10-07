import 'dart:math' show Random;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/phase_k_models.dart';
import '../services/challenge_service.dart';
import 'auth_provider.dart';
import 'online_game_provider.dart';

final challengeServiceProvider =
    Provider<FriendChallengeService>((ref) => FriendChallengeService.instance);

/// Challenges the signed-in user has received and hasn't responded to.
final pendingChallengesProvider = FutureProvider<List<Challenge>>((ref) async {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) return [];
  return ref.watch(challengeServiceProvider).getPendingChallenges(user.uid);
});

/// Challenges the signed-in user has sent or accepted that are in progress.
final activeChallengesProvider = FutureProvider<List<Challenge>>((ref) async {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) return [];
  return ref.watch(challengeServiceProvider).getActiveChallenges(user.uid);
});

/// The signed-in user's win/loss streak across friend challenges.
final userChallengeStreakProvider =
    FutureProvider<ChallengeStreak?>((ref) async {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) return null;
  return ref.watch(challengeServiceProvider).getUserStreak(user.uid);
});

/// Mutating challenge actions (send/accept/reject/cancel), refreshing the
/// relevant providers afterward so the UI reflects the change.
class ChallengeActionsNotifier extends StateNotifier<AsyncValue<void>> {
  ChallengeActionsNotifier(this._ref) : super(const AsyncValue.data(null));
  final Ref _ref;

  Future<void> sendChallenge({
    required String toUserId,
    required String toUsername,
    String timeControl = '10min',
    int wagerPoints = 0,
  }) async {
    final me = _ref.read(currentUserProvider).value;
    if (me == null) return;

    state = const AsyncValue.loading();
    try {
      await _ref.read(challengeServiceProvider).sendChallenge(
            challengerUserId: me.uid,
            challengerUsername: me.displayName ?? 'Anonymous',
            challengeeUserId: toUserId,
            challengeeUsername: toUsername,
            timeControl: timeControl,
            wagerPoints: wagerPoints,
          );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Accepts [challenge], creates a real online game between the two
  /// players and links it to the challenge. Returns the new game's id.
  Future<String?> acceptChallenge(Challenge challenge) async {
    final me = _ref.read(currentUserProvider).value;
    if (me == null) return null;

    state = const AsyncValue.loading();
    try {
      final isChallengee = me.uid == challenge.challengeeUserId;
      final otherUserId = isChallengee
          ? challenge.challengerUserId
          : challenge.challengeeUserId;
      final otherName = isChallengee
          ? challenge.challengerUsername
          : challenge.challengeeUsername;

      final otherDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(otherUserId)
          .get();
      final otherRating = (otherDoc.data()?['rating'] as num?)?.toInt() ?? 1200;

      final myName = me.displayName ?? 'Anonymous';
      final meIsWhite = Random().nextBool();

      final game =
          await _ref.read(onlineGameNotifierProvider.notifier).createGame(
                whitePlayerId: meIsWhite ? me.uid : otherUserId,
                whitePlayerName: meIsWhite ? myName : otherName,
                whiteRating: meIsWhite ? me.rating : otherRating,
                blackPlayerId: meIsWhite ? otherUserId : me.uid,
                blackPlayerName: meIsWhite ? otherName : myName,
                blackRating: meIsWhite ? otherRating : me.rating,
                gameType: 'online_pvp',
                timeControl: challenge.timeControl,
              );
      await _ref
          .read(onlineGameNotifierProvider.notifier)
          .startGame(game.gameId);
      await _ref
          .read(challengeServiceProvider)
          .acceptChallenge(challenge.challengeId, game.gameId);

      _ref.invalidate(pendingChallengesProvider);
      _ref.invalidate(activeChallengesProvider);
      state = const AsyncValue.data(null);
      return game.gameId;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<void> rejectChallenge(Challenge challenge) async {
    state = const AsyncValue.loading();
    try {
      await _ref
          .read(challengeServiceProvider)
          .rejectChallenge(challenge.challengeId);
      _ref.invalidate(pendingChallengesProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> cancelChallenge(Challenge challenge) async {
    state = const AsyncValue.loading();
    try {
      await _ref
          .read(challengeServiceProvider)
          .cancelChallenge(challenge.challengeId);
      _ref.invalidate(activeChallengesProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final challengeActionsProvider =
    StateNotifierProvider<ChallengeActionsNotifier, AsyncValue<void>>(
  (ref) => ChallengeActionsNotifier(ref),
);
