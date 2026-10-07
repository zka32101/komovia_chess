import 'package:flutter/material.dart';

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
    this.isPremium = false,
  });
  final String id;
  final String displayName;
  final Color lightSquareColor;
  final Color darkSquareColor;
  final Color whitePieceColor;
  final Color blackPieceColor;
  final Color selectedSquareColor;
  final Color legalMoveIndicatorColor;
  final bool isPremium;
}

/// Built-in catalog of board/piece theme packs. Some are free, some require
/// the `custom_board_themes` premium feature (see `premium_provider.dart`).
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
    isPremium: true,
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
    isPremium: true,
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
    isPremium: true,
  );

  static const List<BoardTheme> all = [
    classic,
    wooden,
    marble,
    forest,
    ocean,
    midnight,
  ];

  /// Feature key checked against `premiumFeatureProvider` to unlock the
  /// [BoardTheme.isPremium] entries in [all].
  static const String premiumFeatureKey = 'custom_board_themes';

  static BoardTheme byId(String id) =>
      all.firstWhere((theme) => theme.id == id, orElse: () => classic);
}
