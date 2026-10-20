import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/club_provider.dart';

/// A single club's description, member count, join/leave button, and its
/// internal leaderboard (members sorted by their own chess rating).
class ClubDetailScreen extends ConsumerWidget {
  const ClubDetailScreen({required this.clubId, Key? key}) : super(key: key);
  final String clubId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clubAsync = ref.watch(clubByIdProvider(clubId));

    return Scaffold(
      appBar: AppBar(title: const Text('Club'), centerTitle: true, elevation: 0),
      body: SafeArea(
        child: clubAsync.when(
          data: (club) {
            if (club == null) {
              return const Center(child: Text('Club not found.'));
            }
            final uid = FirebaseAuth.instance.currentUser?.uid;
            final isMember = uid != null && club.memberUids.contains(uid);
            final membersAsync = ref.watch(clubMembersProvider(clubId));

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        club.name,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      if (club.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(club.description, style: TextStyle(color: Colors.grey.shade600)),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        '${club.memberCount} member${club.memberCount == 1 ? '' : 's'}',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      if (uid != null)
                        SizedBox(
                          width: double.infinity,
                          child: isMember
                              ? OutlinedButton(
                                  onPressed: () => _leave(context, ref),
                                  child: const Text('Leave Club'),
                                )
                              : FilledButton(
                                  onPressed: () => _join(context, ref),
                                  child: const Text('Join Club'),
                                ),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Leaderboard',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Expanded(
                  child: membersAsync.when(
                    data: (members) => members.isEmpty
                        ? const Center(child: Text('No members yet.'))
                        : ListView.builder(
                            itemCount: members.length,
                            itemBuilder: (context, index) {
                              final member = members[index];
                              return ListTile(
                                leading: CircleAvatar(child: Text('${index + 1}')),
                                title: Text(member.displayName),
                                trailing: Text('${member.rating}'),
                              );
                            },
                          ),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Failed to load members: $e')),
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Failed to load club: $e')),
        ),
      ),
    );
  }

  Future<void> _join(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(clubServiceProvider).joinClub(clubId);
      ref.invalidate(clubByIdProvider(clubId));
      ref.invalidate(myClubsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to join: $e')));
      }
    }
  }

  Future<void> _leave(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(clubServiceProvider).leaveClub(clubId);
      ref.invalidate(clubByIdProvider(clubId));
      ref.invalidate(myClubsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to leave: $e')));
      }
    }
  }
}
