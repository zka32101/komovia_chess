import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/club.dart';
import '../../providers/club_provider.dart';
import 'club_detail_screen.dart';

/// Browse all clubs, see the ones you've joined, and create a new one
/// (③ from the "次の機能案" feature survey).
class ClubsScreen extends ConsumerStatefulWidget {
  const ClubsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ClubsScreen> createState() => _ClubsScreenState();
}

class _ClubsScreenState extends ConsumerState<ClubsScreen> {
  int _tab = 0; // 0: All Clubs, 1: My Clubs

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Clubs'),
          centerTitle: true,
          elevation: 0,
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showCreateClubDialog(context),
          child: const Icon(Icons.add),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('All Clubs'),
                        selected: _tab == 0,
                        onSelected: (_) => setState(() => _tab = 0),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('My Clubs'),
                        selected: _tab == 1,
                        onSelected: (_) => setState(() => _tab = 1),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: _tab == 0 ? _buildAllClubs() : _buildMyClubs()),
            ],
          ),
        ),
      );

  Widget _buildAllClubs() {
    final clubsAsync = ref.watch(allClubsProvider);
    return clubsAsync.when(
      data: (clubs) => _buildClubList(clubs, emptyMessage: 'No clubs yet - be the first to create one!'),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Failed to load clubs: $e')),
    );
  }

  Widget _buildMyClubs() {
    final clubsAsync = ref.watch(myClubsProvider);
    return clubsAsync.when(
      data: (clubs) => _buildClubList(clubs, emptyMessage: "You haven't joined any clubs yet."),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Failed to load clubs: $e')),
    );
  }

  Widget _buildClubList(List<Club> clubs, {required String emptyMessage}) {
    if (clubs.isEmpty) {
      return Center(child: Text(emptyMessage, textAlign: TextAlign.center));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: clubs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final club = clubs[index];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.groups_outlined),
            title: Text(club.name),
            subtitle: Text(
              club.description.isNotEmpty
                  ? club.description
                  : '${club.memberCount} member${club.memberCount == 1 ? '' : 's'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text('${club.memberCount}'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ClubDetailScreen(clubId: club.id),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _showCreateClubDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create a Club'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Club name'),
              autofocus: true,
            ),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: 'Description (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              if (FirebaseAuth.instance.currentUser == null) {
                Navigator.of(context).pop();
                return;
              }
              try {
                await ref.read(clubServiceProvider).createClub(
                      name: name,
                      description: descriptionController.text.trim(),
                    );
                ref.invalidate(allClubsProvider);
                ref.invalidate(myClubsProvider);
                if (context.mounted) Navigator.of(context).pop();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to create club: $e')),
                  );
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
      // showDialog resolves once the dialog is dismissed by any path
      // (Cancel, Create's own pop, or tapping outside) - without this,
      // a fresh pair of TextEditingControllers (and their underlying
      // ChangeNotifier listener lists) was created and never disposed
      // every time this dialog was opened.
    ).then((_) {
      nameController.dispose();
      descriptionController.dispose();
    });
  }
}
