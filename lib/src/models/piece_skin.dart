import 'package:flutter/material.dart';
import 'package:komovia_core/komovia_core.dart';

/// A selectable piece-set skin. Rendering stays glyph-based (see
/// `PieceGlyph`): a skin only varies fill colors, outline colors/width and
/// glyph weight.
///
/// Readability invariant (never regress the white/black differentiation
/// fix): every skin's white side is a LIGHT fill with a DARK outline, and
/// its black side is a DARK fill with a LIGHT outline. `piece_skin_test`
/// enforces this for the whole catalog.
class PieceSkin {
  const PieceSkin({
    required this.id,
    required this.displayName,
    this.whiteFill,
    this.blackFill,
    this.whiteOutline = const Color(0xFF1A1A1A),
    this.blackOutline = const Color(0x99FFFFFF),
    this.whiteStrokeScale = 0.09,
    this.blackStrokeScale = 0.04,
    this.fontWeight = FontWeight.bold,
    this.includedWithSubscription = false,
    this.includedWithLifetime = false,
    this.iapProductId,
  });

  final String id;
  final String displayName;

  /// null = use the selected board theme's piece colors.
  final Color? whiteFill;
  final Color? blackFill;
  final Color whiteOutline;
  final Color blackOutline;

  /// Outline stroke width as a fraction of the glyph font size.
  final double whiteStrokeScale;
  final double blackStrokeScale;
  final FontWeight fontWeight;
  final bool includedWithSubscription;

  /// Granted only to premium lifetime purchasers (NOT to monthly/annual
  /// subscribers) - komovia_core [CosmeticItem.includedWithLifetime].
  final bool includedWithLifetime;
  final String? iapProductId;

  CosmeticItem get cosmetic => CosmeticItem(
    id: id,
    category: PieceSkinCatalog.cosmeticCategory,
    name: displayName,
    includedWithSubscription: includedWithSubscription,
    includedWithLifetime: includedWithLifetime,
    iapProductId: iapProductId,
  );
}

class PieceSkinCatalog {
  PieceSkinCatalog._();

  static const String cosmeticCategory = 'pieceSkin';

  // --- Free ---

  /// The existing solid-glyph-plus-outline style, colored by the board
  /// theme.
  static const PieceSkin standard = PieceSkin(
    id: 'default',
    displayName: 'Standard',
  );

  /// Extra-thick outlines for maximum legibility on small screens.
  static const PieceSkin boldOutline = PieceSkin(
    id: 'bold_outline',
    displayName: 'Bold Outline',
    whiteFill: Color(0xFFFFFFFF),
    blackFill: Color(0xFF000000),
    whiteOutline: Color(0xFF000000),
    blackOutline: Color(0xE6FFFFFF),
    whiteStrokeScale: 0.13,
    blackStrokeScale: 0.07,
    fontWeight: FontWeight.w900,
  );

  /// Lighter-weight glyphs with a softer cream/charcoal palette.
  static const PieceSkin classicIvory = PieceSkin(
    id: 'classic_ivory',
    displayName: 'Ivory',
    whiteFill: Color(0xFFFFF6E0),
    blackFill: Color(0xFF3A3A3A),
    whiteOutline: Color(0xFF3B2F20),
    blackOutline: Color(0xB3FFF6E0),
    fontWeight: FontWeight.w600,
  );

  // --- Premium ---

  static const PieceSkin ebony = PieceSkin(
    id: 'ebony',
    displayName: 'Ivory & Ebony',
    whiteFill: Color(0xFFFFFBF0),
    blackFill: Color(0xFF1B120C),
    whiteOutline: Color(0xFF2B1D12),
    blackOutline: Color(0xCCE8D5B5),
    whiteStrokeScale: 0.1,
    blackStrokeScale: 0.05,
    includedWithSubscription: true,
  );

  static const PieceSkin goldOnyx = PieceSkin(
    id: 'gold_onyx',
    displayName: 'Gold & Onyx',
    whiteFill: Color(0xFFF7D774),
    blackFill: Color(0xFF15151B),
    whiteOutline: Color(0xFF4A3300),
    blackOutline: Color(0xCCF7D774),
    whiteStrokeScale: 0.1,
    blackStrokeScale: 0.05,
    iapProductId: 'chess_skin_pieces_gold_onyx',
  );

  static const PieceSkin sapphire = PieceSkin(
    id: 'sapphire',
    displayName: 'Frost & Sapphire',
    whiteFill: Color(0xFFE6F4FF),
    blackFill: Color(0xFF0D2A5C),
    whiteOutline: Color(0xFF0B1F3A),
    blackOutline: Color(0xCCBFE3FF),
    whiteStrokeScale: 0.1,
    blackStrokeScale: 0.05,
    includedWithSubscription: true,
    iapProductId: 'chess_skin_pieces_sapphire',
  );

  // --- Lifetime-purchase exclusive ---

  /// Granted only by the premium lifetime (one-time) purchase.
  static const PieceSkin eternalCrown = PieceSkin(
    id: 'eternal_crown',
    displayName: 'Eternal Crown',
    whiteFill: Color(0xFFFFF4D6),
    blackFill: Color(0xFF2A0F3D),
    whiteOutline: Color(0xFF5C3D00),
    blackOutline: Color(0xCCFFD86B),
    whiteStrokeScale: 0.1,
    blackStrokeScale: 0.05,
    includedWithLifetime: true,
  );

  static const List<PieceSkin> all = [
    standard,
    boldOutline,
    classicIvory,
    ebony,
    goldOnyx,
    sapphire,
    eternalCrown,
  ];

  static PieceSkin byId(String? id) =>
      all.firstWhere((s) => s.id == id, orElse: () => standard);
}
