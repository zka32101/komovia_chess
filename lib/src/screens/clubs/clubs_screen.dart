import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/club.dart';
import '../../providers/club_provider.dart';
import 'club_detail_screen.dart';
import '../../../l10n/app_localizations.dart';

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
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.clubsTitle),
        centerTitle: true,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateClubDialog(context, l10n),
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
                      label: Text(l10n.clubsAllClubsTab),
                      selected: _tab == 0,
                      onSelected: (_) => setState(() => _tab = 0),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ChoiceChip(
                      label: Text(l10n.clubsMyClubsTab),
                      selected: _tab == 1,
                      onSelected: (_) => setState(() => _tab = 1),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
                child:
                    _tab == 0 ? _buildAllClubs(l10n) : _buildMyClubs(l10n)),
          ],
        ),
      ),
    );
  }

  Widget _buildAllClubs(AppLocalizations l10n) {
    final clubsAsync = ref.watch(allClubsProvider);
    return clubsAsync.when(
      data: (clubs) => _buildClubList(clubs,
          emptyMessage: l10n.clubsNoClubsYetMessage, l10n: l10n),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) =>
          Center(child: Text(l10n.clubsLoadFailedMessage(e.toString()))),
    );
  }

  Widget _buildMyClubs(AppLocalizations l10n) {
    final clubsAsync = ref.watch(myClubsProvider);
    return clubsAsync.when(
      data: (clubs) => _buildClubList(clubs,
          emptyMessage: l10n.clubsNotJoinedAnyMessage, l10n: l10n),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) =>
          Center(child: Text(l10n.clubsLoadFailedMessage(e.toString()))),
    );
  }

  Widget _buildClubList(
    List<Club> clubs, {
    required String emptyMessage,
    required AppLocalizations l10n,
  }) {
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
                  : (club.memberCount == 1
                      ? l10n.clubsMemberCountLabel(club.memberCount)
                      : l10n.clubsMembersCountLabel(club.memberCount)),
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

  void _showCreateClubDialog(BuildContext context, AppLocalizations l10n) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.clubsCreateClubTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: l10n.clubsClubNameLabel),
              autofocus: true,
            ),
            TextField(
              controller: descriptionController,
              decoration: InputDecoration(
                  labelText: l10n.clubsDescriptionOptionalLabel),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.clubsCancelButton),
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
                    SnackBar(
                        content: Text(l10n.clubsCreateFailedMessage(
                            e.toString()))),
                  );
                }
              }
            },
            child: Text(l10n.clubsCreateButton),
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
