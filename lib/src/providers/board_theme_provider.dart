import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/board_theme.dart';
import 'auth_provider.dart';
import 'cosmetic_provider.dart';
import 'user_preferences_provider.dart';

/// The user's currently applied board skin.
///
/// Source of truth is `UserModel.boardSkinId` (written by the cosmetic
/// shop, same save path as `avatarId`). Users who picked a theme before
/// the shop existed only have the legacy `UserPreferences.boardStyle`, so
/// that's the fallback. Locked (not owned) skins resolve to Classic.
final selectedBoardThemeProvider = Provider<BoardTheme>((ref) {
  final user = ref.watch(currentUserProvider).value;
  final legacy = ref.watch(userPreferencesProvider).value?.boardStyle;
  return resolveBoardSkin(
    user?.boardSkinId ?? legacy,
    hasActiveSubscription: ref.watch(hasActiveSubscriptionProvider),
    purchasedProductIds: ref.watch(purchasedCosmeticProductIdsProvider),
    isLifetimePurchaser: ref.watch(isLifetimePurchaserProvider),
  );
});
