import 'package:flutter/material.dart';
import 'package:komovia_core/komovia_core.dart';

/// A selectable visual theme for the chess board and pieces: square colors,
/// piece glyph colors, and the highlight colors used for selection/legal
/// move indicators.
///
/// Plain (non-freezed) immutable class: instances only ever come from the
/// static [BoardThemeCatalog], never from JSON/Firestore, so there's no
/// need for generated `fromJson`/`copyWith` boilerplate.
class BoardTheme {
  const BoardTheme({
    required this.id,
    required this.displayName,
    required this.lightSquareColor,
    required this.darkSquareColor,
    required this.whitePieceColor,
    required this.blackPieceColor,
    required this.selectedSquareColor,
    required this.legalMoveIndicatorColor,
    this.includedWithSubscription = false,
    this.iapProductId,
    this.textureAsset,
  });
  final String id;
  final String displayName;
  final Color lightSquareColor;
  final Color darkSquareColor;
  final Color whitePieceColor;
  final Color blackPieceColor;
  final Color selectedSquareColor;
  final Color legalMoveIndicatorColor;

  /// Unlocked for every active subscriber (Pro/Premium).
  final bool includedWithSubscription;

  /// One-time non-consumable IAP product id that permanently unlocks this
  /// skin on its own (no RNG, fixed price). null = not sold individually.
  final String? iapProductId;

  /// Optional tileable texture (bundled asset) drawn at low opacity over
  /// the square colors, so the light/dark contrast always comes from
  /// [lightSquareColor]/[darkSquareColor] and stays readable.
  final String? textureAsset;

  /// Whether this skin is locked for some users (not free for everyone).
  bool get isPremium => !cosmetic.isFreeForAll;

  /// This skin as komovia_core's shared ownership model.
  CosmeticItem get cosmetic => CosmeticItem(
    id: id,
    category: BoardThemeCatalog.cosmeticCategory,
    name: displayName,
    includedWithSubscription: includedWithSubscription,
    iapProductId: iapProductId,
  );
}

/// Built-in catalog of board skins. Free ones are open to everyone; the
/// rest are unlocked by an active subscription and/or a one-time IAP
/// (see [BoardTheme.cosmetic] and `cosmetic_provider.dart`).
class BoardThemeCatalog {
  BoardThemeCatalog._();

  static const BoardTheme classic = BoardTheme(
    id: 'default',
    displayName: 'Classic',
    lightSquareColor: Color(0xFFF0D9B5),
    darkSquareColor: Color(0xFFB58863),
    whitePieceColor: Color(0xFFF8F8F8),
    blackPieceColor: Color(0xFF2C2C2C),
    selectedSquareColor: Color(0xFFBACB44),
    legalMoveIndicatorColor: Color(0xFF4CAF50),
  );

  static const BoardTheme wooden = BoardTheme(
    id: 'wooden',
    displayName: 'Wooden',
    lightSquareColor: Color(0xFFE8C99B),
    darkSquareColor: Color(0xFF8B5A2B),
    whitePieceColor: Color(0xFFFFF3E0),
    blackPieceColor: Color(0xFF3E2723),
    selectedSquareColor: Color(0xFFD4A843),
    legalMoveIndicatorColor: Color(0xFF6D9C3F),
  );

  static const BoardTheme marble = BoardTheme(
    id: 'marble',
    displayName: 'Marble',
    lightSquareColor: Color(0xFFECEFF1),
    darkSquareColor: Color(0xFF90A4AE),
    whitePieceColor: Color(0xFFFFFFFF),
    blackPieceColor: Color(0xFF37474F),
    selectedSquareColor: Color(0xFFB0BEC5),
    legalMoveIndicatorColor: Color(0xFF546E7A),
  );

  static const BoardTheme forest = BoardTheme(
    id: 'forest',
    displayName: 'Forest',
    lightSquareColor: Color(0xFFDCEDC8),
    darkSquareColor: Color(0xFF558B2F),
    whitePieceColor: Color(0xFFFAFAFA),
    blackPieceColor: Color(0xFF1B3B0F),
    selectedSquareColor: Color(0xFFAED581),
    legalMoveIndicatorColor: Color(0xFF33691E),
    includedWithSubscription: true,
  );

  static const BoardTheme ocean = BoardTheme(
    id: 'ocean',
    displayName: 'Ocean',
    lightSquareColor: Color(0xFFE1F5FE),
    darkSquareColor: Color(0xFF0277BD),
    whitePieceColor: Color(0xFFFFFFFF),
    blackPieceColor: Color(0xFF01579B),
    selectedSquareColor: Color(0xFF81D4FA),
    legalMoveIndicatorColor: Color(0xFF00838F),
    includedWithSubscription: true,
  );

  static const BoardTheme midnight = BoardTheme(
    id: 'midnight',
    displayName: 'Midnight',
    lightSquareColor: Color(0xFF4A4A68),
    darkSquareColor: Color(0xFF232336),
    whitePieceColor: Color(0xFFF5F0FF),
    blackPieceColor: Color(0xFF0D0D1A),
    selectedSquareColor: Color(0xFF7C6FE0),
    legalMoveIndicatorColor: Color(0xFF9C89F5),
    includedWithSubscription: true,
  );

  // --- Free (added with the cosmetic shop) ---

  static const BoardTheme tournamentGreen = BoardTheme(
    id: 'green',
    displayName: 'Green',
    lightSquareColor: Color(0xFFEEEED2),
    darkSquareColor: Color(0xFF769656),
    whitePieceColor: Color(0xFFF8F8F8),
    blackPieceColor: Color(0xFF2C2C2C),
    selectedSquareColor: Color(0xFFF6F669),
    legalMoveIndicatorColor: Color(0xFF3B5E2B),
  );

  static const BoardTheme slate = BoardTheme(
    id: 'slate',
    displayName: 'Slate',
    lightSquareColor: Color(0xFFDADDE1),
    darkSquareColor: Color(0xFF8A939C),
    whitePieceColor: Color(0xFFFAFAFA),
    blackPieceColor: Color(0xFF212121),
    selectedSquareColor: Color(0xFFF2C14E),
    legalMoveIndicatorColor: Color(0xFF37474F),
  );

  // --- Individually purchasable (one-time IAP) ---

  static const BoardTheme walnut = BoardTheme(
    id: 'walnut',
    displayName: 'Walnut',
    lightSquareColor: Color(0xFFE3C29B),
    darkSquareColor: Color(0xFF7A4A2A),
    whitePieceColor: Color(0xFFFFF8EC),
    blackPieceColor: Color(0xFF241510),
    selectedSquareColor: Color(0xFFD9B44A),
    legalMoveIndicatorColor: Color(0xFF5E8C31),
    iapProductId: 'chess_skin_board_walnut',
    textureAsset: 'assets/images/board_skins/walnut.png',
  );

  static const BoardTheme carrara = BoardTheme(
    id: 'carrara',
    displayName: 'Carrara',
    lightSquareColor: Color(0xFFF4F4F2),
    darkSquareColor: Color(0xFF9EA4AA),
    whitePieceColor: Color(0xFFFFFFFF),
    blackPieceColor: Color(0xFF263238),
    selectedSquareColor: Color(0xFFC9B37E),
    legalMoveIndicatorColor: Color(0xFF455A64),
    iapProductId: 'chess_skin_board_carrara',
    textureAsset: 'assets/images/board_skins/carrara.png',
  );

  /// High-contrast "tournament" look - included for subscribers AND
  /// purchasable on its own.
  static const BoardTheme tournament = BoardTheme(
    id: 'tournament',
    displayName: 'Tournament',
    lightSquareColor: Color(0xFFFFFFFF),
    darkSquareColor: Color(0xFF3F6E4E),
    whitePieceColor: Color(0xFFFFFFFF),
    blackPieceColor: Color(0xFF111111),
    selectedSquareColor: Color(0xFFFFD54F),
    legalMoveIndicatorColor: Color(0xFFE65100),
    includedWithSubscription: true,
    iapProductId: 'chess_skin_board_tournament',
  );

  static const List<BoardTheme> all = [
    classic,
    wooden,
    marble,
    tournamentGreen,
    slate,
    forest,
    ocean,
    midnight,
    walnut,
    carrara,
    tournament,
  ];

  static const String cosmeticCategory = 'boardSkin';

  static BoardTheme byId(String id) =>
      all.firstWhere((theme) => theme.id == id, orElse: () => classic);
}
