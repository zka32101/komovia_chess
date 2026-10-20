import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/club.dart';
import '../services/club_service.dart';

final clubServiceProvider = Provider((ref) => ClubService());

final allClubsProvider = FutureProvider.autoDispose<List<Club>>((ref) {
  return ref.watch(clubServiceProvider).getAllClubs();
});

final myClubsProvider = FutureProvider.autoDispose<List<Club>>((ref) {
  return ref.watch(clubServiceProvider).getMyClubs();
});

final clubByIdProvider =
    FutureProvider.autoDispose.family<Club?, String>((ref, clubId) {
  return ref.watch(clubServiceProvider).getClub(clubId);
});

// Keyed on clubId (a plain String, with real value equality) rather than
// the member-uid list itself - a List has no value equality in Dart, so
// keying a family provider on one directly would mint a fresh,
// never-evicted cache entry on every rebuild (the same class of bug
// already fixed elsewhere in this codebase for a List<Friend>-keyed
// family). Reads the club's own memberUids via clubByIdProvider instead.
final clubMembersProvider =
    FutureProvider.autoDispose.family<List<ClubMember>, String>((ref, clubId) async {
  final club = await ref.watch(clubByIdProvider(clubId).future);
  if (club == null) return [];
  return ref.watch(clubServiceProvider).getClubMembers(club.memberUids);
});
