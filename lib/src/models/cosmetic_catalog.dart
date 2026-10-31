import 'package:komovia_core/komovia_core.dart';
import 'board_theme.dart';
import 'piece_skin.dart';

/// This app's full cosmetic catalog (board skins + piece-set skins) as
/// komovia_core [CosmeticItem]s. No gacha / no virtual currency: every
/// item is either free, included with an active subscription, and/or a
/// fixed-price one-time IAP.
class ChessCosmeticCatalog {
  ChessCosmeticCatalog._();

  static List<CosmeticItem> get boardSkins =>
      BoardThemeCatalog.all.map((t) => t.cosmetic).toList();

  static List<CosmeticItem> get pieceSkins =>
      PieceSkinCatalog.all.map((s) => s.cosmetic).toList();

  static List<CosmeticItem> get all => [...boardSkins, ...pieceSkins];

  /// Every IAP product id sold in the cosmetic shop.
  static Set<String> get purchasableProductIds => {
    for (final item in all)
      if (item.iapProductId != null) item.iapProductId!,
  };
}
