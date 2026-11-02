import 'package:flutter/material.dart';
import 'package:komovia_core/komovia_core.dart';
import '../../l10n/app_localizations.dart';
import '../models/avatar_frames.dart';
import '../models/user.dart';

/// Border color for a frame tier (simple, no per-frame art).
Color avatarFrameColor(FrameTier tier) => switch (tier) {
  FrameTier.bronze => const Color(0xFFCD7F32),
  FrameTier.silver => const Color(0xFFB0B7C0),
  FrameTier.gold => const Color(0xFFFFC107),
  FrameTier.platinum => const Color(0xFF7FDBFF),
};

/// Localized unlock requirement for a frame.
String avatarFrameRequirementLabel(
  AppLocalizations l10n,
  AvatarFrameRequirement r,
) => switch (r.stat) {
  null => l10n.avatarFrameReqLifetime,
  FrameStat.wins => l10n.avatarFrameReqWins(r.threshold),
  FrameStat.gamesPlayed => l10n.avatarFrameReqGames(r.threshold),
  FrameStat.puzzlesSolved => l10n.avatarFrameReqPuzzles(r.threshold),
  FrameStat.rating => l10n.avatarFrameReqRating(r.threshold),
  FrameStat.puzzleStreak => l10n.avatarFrameReqStreak(r.threshold),
};

/// Result of the avatar picker: the chosen icon and frame (null = none).
class AvatarPickerResult {
  const AvatarPickerResult({required this.avatarId, this.frameId});
  final String avatarId;
  final String? frameId;
}

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
    this.frame,
    super.key,
  });

  final String? avatarId;
  final double radius;
  final Color? backgroundColor;

  /// Already-resolved frame (see `resolveDisplayedFrame`); null = none.
  final AvatarFrame? frame;

  @override
  Widget build(BuildContext context) {
    final icon = avatarIconById(avatarId);
    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? Colors.grey.shade100,
      child: Text(icon.emoji, style: TextStyle(fontSize: radius)),
    );
    final f = frame;
    if (f == null) return avatar;
    return Container(
      key: ValueKey('avatar-frame-${f.id}'),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: avatarFrameColor(f.tier),
          width: (radius / 8).clamp(2.0, 6.0),
        ),
      ),
      child: avatar,
    );
  }
}

/// Shows a bottom sheet grid of every preset in `kAvatarIcons` and resolves
/// with the tapped icon's id, or `null` if the sheet was dismissed without
/// a selection. Callers are responsible for actually persisting the
/// result (same division of labor as `EditProfileScreen`'s text fields -
/// this only collects the choice).
///
/// When [user] is given, a frame section lists every frame in
/// `kAvatarFrames`; locked ones are shown (disabled) with their unlock
/// requirement rather than hidden.
Future<AvatarPickerResult?> showAvatarPickerSheet(
  BuildContext context, {
  String? currentAvatarId,
  UserModel? user,
}) {
  final selectedId = currentAvatarId ?? defaultAvatarIconId;
  return showModalBottomSheet<AvatarPickerResult>(
    context: context,
    isScrollControlled: true,
    builder: (context) =>
        _AvatarPickerSheet(initialSelectedId: selectedId, user: user),
  );
}

class _AvatarPickerSheet extends StatefulWidget {
  const _AvatarPickerSheet({required this.initialSelectedId, this.user});
  final String initialSelectedId;
  final UserModel? user;

  @override
  State<_AvatarPickerSheet> createState() => _AvatarPickerSheetState();
}

class _AvatarPickerSheetState extends State<_AvatarPickerSheet> {
  late String _selectedId;
  String? _selectedFrameId;
  Set<String> _unlocked = const {};

  @override
  void initState() {
    super.initState();
    _selectedId = widget.initialSelectedId;
    final user = widget.user;
    if (user != null) {
      _unlocked = unlockedFrameIdsFor(user);
      _selectedFrameId = resolveDisplayedFrame(user)?.id;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: SingleChildScrollView(
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
              if (widget.user != null) ...[
                const SizedBox(height: 20),
                Text(
                  l10n.avatarFrameSectionTitle,
                  style: Theme.of(context).textTheme.titleSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      key: const ValueKey('frame-choice-none'),
                      label: Text(l10n.avatarFrameNone),
                      selected: _selectedFrameId == null,
                      onSelected: (_) =>
                          setState(() => _selectedFrameId = null),
                    ),
                    for (final r in kAvatarFrames)
                      _buildFrameChip(
                        context,
                        l10n,
                        r,
                        unlockedIds: _unlocked,
                        selectedFrameId: _selectedFrameId,
                        onSelect: (id) => setState(() => _selectedFrameId = id),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(
                  AvatarPickerResult(
                    avatarId: _selectedId,
                    frameId: _selectedFrameId,
                  ),
                ),
                child: Text(l10n.avatarPickerSaveButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _buildFrameChip(
  BuildContext context,
  AppLocalizations l10n,
  AvatarFrameRequirement r, {
  required Set<String> unlockedIds,
  required String? selectedFrameId,
  required ValueChanged<String> onSelect,
}) {
  final unlocked = AvatarFrame.isUnlocked(r.frame.id, unlockedIds);
  final label = avatarFrameRequirementLabel(l10n, r);
  return ChoiceChip(
    key: ValueKey('frame-choice-${r.frame.id}'),
    avatar: unlocked
        ? Icon(Icons.circle_outlined, color: avatarFrameColor(r.frame.tier))
        : const Icon(Icons.lock_outline, size: 18),
    label: Text(unlocked ? label : l10n.avatarFrameLocked(label)),
    selected: selectedFrameId == r.frame.id,
    onSelected: unlocked ? (_) => onSelect(r.frame.id) : null,
  );
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
        child: Text(icon.emoji, style: const TextStyle(fontSize: 28)),
      ),
    ),
  );
}
