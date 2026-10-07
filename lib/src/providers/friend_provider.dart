import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_core/komovia_core.dart';
import '../models/phase_k_models.dart' show FriendActivity;
import '../models/user.dart';
import '../services/friend_service.dart';
import 'auth_provider.dart';

final friendServiceProvider =
    Provider<FriendService>((ref) => FriendService.instance);

/// The signed-in user's accepted friends.
final userFriendsProvider = FutureProvider<List<Friendship>>((ref) async {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) return [];
  return ref.watch(friendServiceProvider).getFriends(user.uid);
});

/// Friend requests the signed-in user has either received or sent and
/// hasn't been resolved yet — see `Friendship.wasRequestedBy` to tell an
/// incoming request (show accept/decline) from one the viewer sent
/// themselves (show cancel).
final pendingFriendRequestsProvider =
    FutureProvider<List<Friendship>>((ref) async {
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

/// Mutating friend actions (send/accept/reject/remove/block/unblock),
/// refreshing the list/request providers afterward so the UI reflects the
/// change.
class FriendActionsNotifier extends StateNotifier<AsyncValue<void>> {
  FriendActionsNotifier(this._ref) : super(const AsyncValue.data(null));
  final Ref _ref;

  Future<void> sendRequest(UserModel toUser) async {
    final me = _ref.read(currentUserProvider).value;
    if (me == null) return;

    state = const AsyncValue.loading();
    try {
      await _ref
          .read(friendServiceProvider)
          .sendFriendRequest(me.uid, toUser.uid);
      _ref.invalidate(pendingFriendRequestsProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> acceptRequest(Friendship request) async {
    final me = _ref.read(currentUserProvider).value;
    if (me == null) return;

    state = const AsyncValue.loading();
    try {
      await _ref.read(friendServiceProvider).acceptFriendRequest(
            currentUid: me.uid,
            friendUid: request.friendUid,
          );
      _ref.invalidate(userFriendsProvider);
      _ref.invalidate(pendingFriendRequestsProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Declines an incoming request, or cancels one the viewer sent — both
  /// are the same data operation (see `FriendService.rejectFriendRequest`).
  Future<void> rejectRequest(Friendship request) async {
    final me = _ref.read(currentUserProvider).value;
    if (me == null) return;

    state = const AsyncValue.loading();
    try {
      await _ref.read(friendServiceProvider).rejectFriendRequest(
            currentUid: me.uid,
            friendUid: request.friendUid,
          );
      _ref.invalidate(pendingFriendRequestsProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> removeFriend(Friendship friend) async {
    final me = _ref.read(currentUserProvider).value;
    if (me == null) return;

    state = const AsyncValue.loading();
    try {
      await _ref
          .read(friendServiceProvider)
          .removeFriend(me.uid, friend.friendUid);
      _ref.invalidate(userFriendsProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> blockFriend(Friendship friend) async {
    final me = _ref.read(currentUserProvider).value;
    if (me == null) return;

    state = const AsyncValue.loading();
    try {
      await _ref.read(friendServiceProvider).blockFriend(
            currentUid: me.uid,
            friendUid: friend.friendUid,
          );
      _ref.invalidate(userFriendsProvider);
      _ref.invalidate(pendingFriendRequestsProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> unblockFriend(Friendship friend) async {
    final me = _ref.read(currentUserProvider).value;
    if (me == null) return;

    state = const AsyncValue.loading();
    try {
      await _ref.read(friendServiceProvider).unblockFriend(
            currentUid: me.uid,
            friendUid: friend.friendUid,
          );
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
