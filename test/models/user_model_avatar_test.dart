import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_chess/src/models/user.dart';

void main() {
  const baseUser = UserModel(uid: 'u1', email: 'a@example.com');

  group('UserModel.avatarId', () {
    test('defaults to null for a freshly-constructed user', () {
      expect(baseUser.avatarId, isNull);
    });

    test('round-trips through toJson/fromJson when set', () {
      final withAvatar = baseUser.copyWith(avatarId: 'owl');
      final json = withAvatar.toJson();
      expect(json['avatarId'], 'owl');

      final decoded = UserModel.fromJson(json);
      expect(decoded.avatarId, 'owl');
    });

    test('fromJson tolerates a pre-existing document with no avatarId key '
        'at all (every user who existed before this feature shipped)', () {
      final legacyJson = baseUser.toJson()..remove('avatarId');
      final decoded = UserModel.fromJson(legacyJson);
      expect(decoded.avatarId, isNull);
    });

    test('copyWith can clear avatarId back to null', () {
      final withAvatar = baseUser.copyWith(avatarId: 'owl');
      final cleared = withAvatar.copyWith(avatarId: null);
      // copyWith with an explicit null for a nullable field keeps the new
      // value per freezed's generated semantics for this codebase's
      // pattern (no sentinel-default override here, unlike komovia_go's
      // subscriptionEndDate) - avatarId is always set to a concrete,
      // non-null preset id by the picker in practice, so this is mostly
      // documenting the behavior rather than guarding a real call site.
      expect(cleared.avatarId, isNull);
    });
  });

  group('avatarIconById integration (komovia_core)', () {
    test('a user with no avatarId resolves to the shared default icon', () {
      final icon = avatarIconById(baseUser.avatarId);
      expect(icon.id, defaultAvatarIconId);
    });

    test('a user with an unrecognized/stale avatarId still resolves safely '
        'rather than throwing', () {
      final stale = baseUser.copyWith(avatarId: 'no-such-preset');
      final icon = avatarIconById(stale.avatarId);
      expect(icon, isNotNull);
    });

    test('a user with a real avatarId resolves to the matching preset', () {
      final withAvatar = baseUser.copyWith(avatarId: 'owl');
      final icon = avatarIconById(withAvatar.avatarId);
      expect(icon.id, 'owl');
      expect(icon.emoji, '🦉');
    });
  });
}
