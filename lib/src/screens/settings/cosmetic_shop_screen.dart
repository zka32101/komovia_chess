import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_core/komovia_core.dart';
import '../../../l10n/app_localizations.dart';
import '../../models/board_theme.dart';
import '../../models/piece_skin.dart';
import '../../providers/auth_provider.dart';
import '../../providers/board_theme_provider.dart';
import '../../providers/cosmetic_provider.dart';
import '../../widgets/piece_glyph.dart';
import '../premium/premium_screen.dart';

/// Board-skin and piece-skin shop. Every item shows a full preview and
/// exactly how it's unlocked (free / included with subscription / a
/// fixed-price one-time purchase) - no gacha, no virtual currency.
class CosmeticShopScreen extends ConsumerWidget {
  const CosmeticShopScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.cosmeticShopTitle),
          centerTitle: true,
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.cosmeticShopBoardTab),
              Tab(text: l10n.cosmeticShopPieceTab),
            ],
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            children: [
              _SkinGrid(
                note: l10n.cosmeticShopNote,
                itemCount: BoardThemeCatalog.all.length,
                itemBuilder: (context, i) {
                  final theme = BoardThemeCatalog.all[i];
                  return _SkinCard(
                    key: ValueKey('board-skin-${theme.id}'),
                    item: theme.cosmetic,
                    isEquipped:
                        ref.watch(selectedBoardThemeProvider).id == theme.id,
                    preview: _BoardSkinPreview(theme: theme),
                    onEquip: (equip) => equip(boardSkinId: theme.id),
                  );
                },
              ),
              _SkinGrid(
                note: l10n.cosmeticShopNote,
                itemCount: PieceSkinCatalog.all.length,
                itemBuilder: (context, i) {
                  final skin = PieceSkinCatalog.all[i];
                  return _SkinCard(
                    key: ValueKey('piece-skin-${skin.id}'),
                    item: skin.cosmetic,
                    isEquipped:
                        ref.watch(selectedPieceSkinProvider).id == skin.id,
                    preview: _BoardSkinPreview(
                      theme: ref.watch(selectedBoardThemeProvider),
                      pieceSkin: skin,
                    ),
                    onEquip: (equip) => equip(pieceSkinId: skin.id),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkinGrid extends StatelessWidget {
  const _SkinGrid({
    required this.note,
    required this.itemCount,
    required this.itemBuilder,
  });
  final String note;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) => CustomScrollView(
    slivers: [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        sliver: SliverToBoxAdapter(
          child: Text(note, style: Theme.of(context).textTheme.bodySmall),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.all(16),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.62,
          ),
          delegate: SliverChildBuilderDelegate(
            itemBuilder,
            childCount: itemCount,
          ),
        ),
      ),
    ],
  );
}

typedef _Equip =
    Future<void> Function({String? boardSkinId, String? pieceSkinId});

class _SkinCard extends ConsumerStatefulWidget {
  const _SkinCard({
    required this.item,
    required this.isEquipped,
    required this.preview,
    required this.onEquip,
    Key? key,
  }) : super(key: key);
  final CosmeticItem item;
  final bool isEquipped;
  final Widget preview;
  final Future<void> Function(_Equip equip) onEquip;

  @override
  ConsumerState<_SkinCard> createState() => _SkinCardState();
}

class _SkinCardState extends ConsumerState<_SkinCard> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _requireSignIn(AppLocalizations l10n) {
    if (ref.read(currentUserProvider).value != null) return true;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.cosmeticShopSignInRequired)));
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final item = widget.item;
    final owned = ref.watch(cosmeticOwnedProvider(item));
    final prices = ref.watch(cosmeticPricesProvider).value ?? const {};
    final price = item.iapProductId == null ? null : prices[item.iapProductId];
    final colorScheme = Theme.of(context).colorScheme;

    final String status;
    if (item.isFreeForAll) {
      status = l10n.cosmeticShopFree;
    } else if (owned) {
      status = l10n.cosmeticShopOwned;
    } else if (item.includedWithSubscription) {
      status = l10n.cosmeticShopIncludedWithSubscription;
    } else if (item.includedWithLifetime) {
      status = l10n.cosmeticShopIncludedWithLifetime;
    } else {
      status = price ?? '';
    }

    Widget action;
    if (widget.isEquipped) {
      action = OutlinedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.check, size: 16),
        label: Text(l10n.cosmeticShopEquipped),
      );
    } else if (owned) {
      action = FilledButton(
        onPressed: _busy
            ? null
            : () {
                if (!_requireSignIn(l10n)) return;
                _run(() => widget.onEquip(ref.read(equipCosmeticProvider)));
              },
        child: Text(l10n.cosmeticShopEquip),
      );
    } else if (item.iapProductId != null) {
      action = FilledButton.icon(
        onPressed: _busy ? null : () => _buy(l10n, item.iapProductId!),
        icon: const Icon(Icons.shopping_bag_outlined, size: 16),
        label: Text(
          price == null
              ? l10n.cosmeticShopBuy
              : '${l10n.cosmeticShopBuy} $price',
        ),
      );
    } else {
      action = OutlinedButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PremiumScreen()),
        ),
        child: Text(l10n.cosmeticShopSubscribe),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.isEquipped ? colorScheme.primary : Colors.grey.shade300,
          width: widget.isEquipped ? 2.5 : 1,
        ),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: widget.preview,
                  ),
                ),
                if (!owned)
                  const Positioned(
                    top: 4,
                    right: 4,
                    child: Icon(Icons.lock, size: 18, color: Colors.black54),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(
            status,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const Spacer(),
          FittedBox(fit: BoxFit.scaleDown, child: action),
        ],
      ),
    );
  }

  Future<void> _buy(AppLocalizations l10n, String productId) async {
    if (!_requireSignIn(l10n)) return;
    final messenger = ScaffoldMessenger.of(context);
    await _run(() async {
      try {
        await ref.read(purchaseCosmeticProvider)(productId);
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.cosmeticShopPurchaseSuccess)),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.cosmeticShopPurchaseFailed('$e'))),
        );
      }
    });
  }
}

/// 4x4 preview of a board skin, with a white and a black king/queen so
/// the piece differentiation is visible before buying.
class _BoardSkinPreview extends StatelessWidget {
  const _BoardSkinPreview({
    required this.theme,
    this.pieceSkin = PieceSkinCatalog.standard,
  });
  final BoardTheme theme;
  final PieceSkin pieceSkin;

  static const _pieces = {
    (1, 1): ('q', false),
    (1, 2): ('k', false),
    (2, 1): ('k', true),
    (2, 2): ('q', true),
  };

  Widget _grid(double sq, {required bool pieces}) => Column(
    children: List.generate(
      4,
      (r) => Row(
        children: List.generate(4, (c) {
          final piece = _pieces[(r, c)];
          return SizedBox(
            width: sq,
            height: sq,
            child: pieces
                ? (piece == null
                      ? null
                      : Center(
                          child: PieceGlyph(
                            type: piece.$1,
                            isWhite: piece.$2,
                            fontSize: sq * 0.7,
                            whiteColor: theme.whitePieceColor,
                            blackColor: theme.blackPieceColor,
                            skin: pieceSkin,
                          ),
                        ))
                : ColoredBox(
                    color: (r + c).isEven
                        ? theme.lightSquareColor
                        : theme.darkSquareColor,
                  ),
          );
        }),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final sq = constraints.maxWidth / 4;
      return Stack(
        children: [
          _grid(sq, pieces: false),
          if (theme.textureAsset case final texture?)
            Positioned.fill(
              child: IgnorePointer(
                child: Opacity(
                  opacity: 0.28,
                  child: Image.asset(
                    texture,
                    repeat: ImageRepeat.repeat,
                    scale: 2,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          _grid(sq, pieces: true),
        ],
      );
    },
  );
}
