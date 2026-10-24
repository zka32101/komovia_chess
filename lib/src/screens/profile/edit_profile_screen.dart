import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';

/// Lets the signed-in user change their display name and avatar URL.
/// `AuthService.updateUserProfile`/`authStateNotifierProvider` already
/// existed and did the real Firestore write - this screen was the only
/// missing piece (the profile screen's edit button had no destination).
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({required this.user, Key? key}) : super(key: key);
  final UserModel user;

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _displayNameController;
  late final TextEditingController _photoUrlController;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _displayNameController =
        TextEditingController(text: widget.user.displayName ?? '');
    _photoUrlController =
        TextEditingController(text: widget.user.photoUrl ?? '');
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _photoUrlController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final displayName = _displayNameController.text.trim();
    if (displayName.isEmpty) {
      setState(() => _error = 'Display name cannot be empty');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final photoUrl = _photoUrlController.text.trim();
      await ref.read(authStateNotifierProvider.notifier).updateUserProfile(
            displayName: displayName,
            photoUrl: photoUrl.isEmpty ? null : photoUrl,
            // Emptying the field and saving previously did nothing - both
            // the Auth and Firestore writes only ever acted on a non-null
            // photoUrl, so there was no way to actually clear a
            // previously-set avatar.
            clearPhotoUrl: photoUrl.isEmpty,
          );
      // currentUserProvider only re-fetches on an auth-state emission,
      // which a profile edit doesn't trigger - force it to pick up the
      // write that just happened.
      ref.invalidate(currentUserProvider);

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
        _error = 'Failed to save: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Edit Profile'),
          actions: [
            TextButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _displayNameController,
                enabled: !_isSaving,
                decoration: const InputDecoration(
                  labelText: 'Display name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _photoUrlController,
                enabled: !_isSaving,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'Avatar URL (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
      );
}
