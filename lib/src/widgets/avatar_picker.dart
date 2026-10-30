import 'package:flutter/material.dart';
import 'package:komovia_core/komovia_core.dart';
import '../../l10n/app_localizations.dart';

/// Renders a user's resolved avatar emoji (via `avatarIconById`) inside a
/// circle, matching the existing `CircleAvatar` sizing convention used for
/// `photoUrl`/initial-letter avatars across this app (profile screen, home
/// screen). Always renders something - `avatarIconById` already falls back
/// to the default icon for a null/empty/unknown id, so this never needs a
/// null-check at the call site, including for every pre-existing user who
/// never picked an avatar.
class AvatarEmoji extends StatelessWidget {
  const AvatarEmoji({
    required this.avatarId,
    this.radius = 20,
    this.backgroundColor,
    super.key,
  });

  final String? avatarId;
  final double radius;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final icon = avatarIconById(avatarId);
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? Colors.grey.shade100,
      child: Text(
        icon.emoji,
        style: TextStyle(fontSize: radius),
      ),
    );
  }
}

/// Shows a bottom sheet grid of every preset in `kAvatarIcons` and resolves
/// with the tapped icon's id, or `null` if the sheet was dismissed without
/// a selection. Callers are responsible for actually persisting the
/// result (same division of labor as `EditProfileScreen`'s text fields -
/// this only collects the choice).
Future<String?> showAvatarPickerSheet(
  BuildContext context, {
  String? currentAvatarId,
}) {
  final selectedId = currentAvatarId ?? defaultAvatarIconId;
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _AvatarPickerSheet(initialSelectedId: selectedId),
  );
}

class _AvatarPickerSheet extends StatefulWidget {
  const _AvatarPickerSheet({required this.initialSelectedId});
  final String initialSelectedId;

  @override
  State<_AvatarPickerSheet> createState() => _AvatarPickerSheetState();
}

class _AvatarPickerSheetState extends State<_AvatarPickerSheet> {
  late String _selectedId;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.initialSelectedId;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.avatarPickerTitle,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final icon in kAvatarIcons)
                  _AvatarChoice(
                    icon: icon,
                    isSelected: icon.id == _selectedId,
                    onTap: () => setState(() => _selectedId = icon.id),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(_selectedId),
              child: Text(l10n.avatarPickerSaveButton),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarChoice extends StatelessWidget {
  const _AvatarChoice({
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final AvatarIcon icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: icon.label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(32),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey.shade100,
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : Colors.transparent,
                width: 3,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              icon.emoji,
              style: const TextStyle(fontSize: 28),
            ),
          ),
        ),
      );
}
