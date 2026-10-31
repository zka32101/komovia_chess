import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_core/komovia_core.dart';
import '../models/board_theme.dart';
import '../models/cosmetic_catalog.dart';
import '../models/piece_skin.dart';
import 'auth_provider.dart';
import 'premium_provider.dart';

/// One-time cosmetic IAP product ids the signed-in user owns.
final purchasedCosmeticProductIdsProvider = Provider<Set<String>>((ref) {
  final user = ref.watch(currentUserProvider).value;
  return user?.purchasedCosmeticProductIds.toSet() ?? const <String>{};
});

/// Whether the user has an active Pro/Premium subscription (false while
/// loading or on error, so premium skins never flash unlocked).
final hasActiveSubscriptionProvider = Provider<bool>((ref) {
  final sub = ref.watch(userSubscriptionProvider).value;
  return sub != null && (sub.isPro || sub.isPremium);
});

/// Whether [item] is owned by the signed-in user.
final cosmeticOwnedProvider = Provider.family<bool, CosmeticItem>(
  (ref, item) => item.isOwnedBy(
    hasActiveSubscription: ref.watch(hasActiveSubscriptionProvider),
    purchasedProductIds: ref.watch(purchasedCosmeticProductIdsProvider),
  ),
);

/// Resolves a stored skin id against a catalog, falling back to [fallback]
/// for null/unknown ids AND for skins the user no longer owns (e.g. a
/// lapsed subscription) - so nobody keeps a locked skin applied.
T resolveOwnedSkin<T>({
  required String? storedId,
  required List<T> catalog,
  required String Function(T) idOf,
  required CosmeticItem Function(T) cosmeticOf,
  required T fallback,
  required bool hasActiveSubscription,
  required Set<String> purchasedProductIds,
}) {
  for (final skin in catalog) {
    if (idOf(skin) != storedId) continue;
    final owned = cosmeticOf(skin).isOwnedBy(
      hasActiveSubscription: hasActiveSubscription,
      purchasedProductIds: purchasedProductIds,
    );
    return owned ? skin : fallback;
  }
  return fallback;
}

/// The user's applied piece-set skin.
final selectedPieceSkinProvider = Provider<PieceSkin>((ref) {
  final user = ref.watch(currentUserProvider).value;
  return resolveOwnedSkin<PieceSkin>(
    storedId: user?.pieceSkinId,
    catalog: PieceSkinCatalog.all,
    idOf: (s) => s.id,
    cosmeticOf: (s) => s.cosmetic,
    fallback: PieceSkinCatalog.standard,
    hasActiveSubscription: ref.watch(hasActiveSubscriptionProvider),
    purchasedProductIds: ref.watch(purchasedCosmeticProductIdsProvider),
  );
});

/// Resolves a stored board skin id (null = none recorded) to the skin to
/// render, applying the ownership fallback.
BoardTheme resolveBoardSkin(
  String? storedId, {
  required bool hasActiveSubscription,
  required Set<String> purchasedProductIds,
}) => resolveOwnedSkin<BoardTheme>(
  storedId: storedId,
  catalog: BoardThemeCatalog.all,
  idOf: (t) => t.id,
  cosmeticOf: (t) => t.cosmetic,
  fallback: BoardThemeCatalog.classic,
  hasActiveSubscription: hasActiveSubscription,
  purchasedProductIds: purchasedProductIds,
);

/// Localized store prices for every purchasable cosmetic, keyed by
/// product id. Empty when the store is unavailable or products aren't
/// configured in Play Console yet (the shop then shows a plain "Buy").
final cosmeticPricesProvider = FutureProvider<Map<String, String>>((ref) async {
  final paywall = ref.watch(paywallServiceProvider);
  await paywall.initialize();
  final products = await paywall.getProducts(
    ChessCosmeticCatalog.purchasableProductIds.toList(),
  );
  return {for (final p in products) p.id: p.price};
});

/// Buys one cosmetic product through the shared IAP flow, then refreshes
/// the user so ownership updates immediately.
final purchaseCosmeticProvider =
    Provider<Future<void> Function(String productId)>(
      (ref) => (productId) async {
        await ref.read(paywallServiceProvider).purchaseCosmetic(productId);
        ref.invalidate(currentUserProvider);
      },
    );

/// Persists a board/piece skin selection on the user's own doc (same save
/// path as avatarId), then refreshes the user so the board re-renders.
final equipCosmeticProvider =
    Provider<Future<void> Function({String? boardSkinId, String? pieceSkinId})>(
      (ref) => ({boardSkinId, pieceSkinId}) async {
        await ref
            .read(authStateNotifierProvider.notifier)
            .updateUserProfile(
              boardSkinId: boardSkinId,
              pieceSkinId: pieceSkinId,
            );
        ref.invalidate(currentUserProvider);
      },
    );
