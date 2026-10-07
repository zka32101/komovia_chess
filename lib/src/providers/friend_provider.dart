import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/phase_k_models.dart';
import '../models/user.dart';
import '../services/friend_service.dart';
import 'auth_provider.dart';

final friendServiceProvider =
    Provider<FriendService>((ref) => FriendService.instance);

/// The signed-in user's accepted friends.
final userFriendsProvider = FutureProvider<List<Friend>>((ref) async {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) return [];
  return ref.watch(friendServiceProvider).getUserFriends(user.uid);
});

/// Friend requests the signed-in user has received and hasn't responded to.
final pendingFriendRequestsProvider =
    FutureProvider<List<FriendRequest>>((ref) async {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) return [];
  return ref.watch(friendServiceProvider).getPendingRequests(user.uid);
});

/// Users whose display name starts with [query], for the "add friend"
/// search flow.
final userSearchProvider =
    FutureProvider.family<List<UserModel>, String>((ref, query) async {
  return ref.watch(friendServiceProvider).searchUsersByDisplayName(query);
});

/// Recent activity (game results) from the signed-in user's friends.
final activityFeedProvider = FutureProvider<List<FriendActivity>>((ref) async {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) return [];
  return ref.watch(friendServiceProvider).getActivityFeed(user.uid);
});

/// Mutating friend actions (send/accept/reject/remove), refreshing the
/// list/request providers afterward so the UI reflects the change.
class FriendActionsNotifier extends StateNotifier<AsyncValue<void>> {
  FriendActionsNotifier(this._ref) : super(const AsyncValue.data(null));
  final Ref _ref;

  Future<void> sendRequest(UserModel toUser) async {
    final me = _ref.read(currentUserProvider).value;
    if (me == null) return;

    state = const AsyncValue.loading();
    try {
      await _ref.read(friendServiceProvider).sendFriendRequest(
            me.uid,
            toUser.uid,
            me.displayName ?? 'Anonymous',
            me.photoUrl ?? '',
          );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> acceptRequest(FriendRequest request) async {
    final me = _ref.read(currentUserProvider).value;
    if (me == null) return;

    state = const AsyncValue.loading();
    try {
      // FriendRequest doesn't carry the sender's current rating, so look
      // it up fresh rather than passing a stale/guessed value.
      final requesterDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(request.fromUserId)
          .get();
      final requesterRating =
          (requesterDoc.data()?['rating'] as num?)?.toInt() ?? 1200;

      await _ref.read(friendServiceProvider).acceptFriendRequest(
            me.uid,
            request.requestId,
            request.fromUserId,
            request.fromUsername,
            request.fromAvatar,
            requesterRating,
          );
      _ref.invalidate(userFriendsProvider);
      _ref.invalidate(pendingFriendRequestsProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> rejectRequest(FriendRequest request) async {
    final me = _ref.read(currentUserProvider).value;
    if (me == null) return;

    state = const AsyncValue.loading();
    try {
      await _ref.read(friendServiceProvider).rejectFriendRequest(
            me.uid,
            request.requestId,
            request.fromUserId,
          );
      _ref.invalidate(pendingFriendRequestsProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> removeFriend(Friend friend) async {
    final me = _ref.read(currentUserProvider).value;
    if (me == null) return;

    state = const AsyncValue.loading();
    try {
      await _ref
          .read(friendServiceProvider)
          .removeFriend(me.uid, friend.friendId);
      _ref.invalidate(userFriendsProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final friendActionsProvider =
    StateNotifierProvider<FriendActionsNotifier, AsyncValue<void>>(
  (ref) => FriendActionsNotifier(ref),
);
