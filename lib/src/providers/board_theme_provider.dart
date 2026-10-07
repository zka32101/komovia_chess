import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/board_theme.dart';
import 'user_preferences_provider.dart';
import 'premium_provider.dart';

/// The user's currently selected board/piece theme pack.
///
/// Reuses `UserPreferences.boardStyle` (already persisted to Firestore via
/// `UserPreferencesService.setStyles`) as the theme id, rather than adding a
/// parallel preference field.
final selectedBoardThemeProvider = Provider<BoardTheme>((ref) {
  final preferences = ref.watch(userPreferencesProvider);
  return preferences.when(
    data: (prefs) => BoardThemeCatalog.byId(prefs.boardStyle),
    loading: () => BoardThemeCatalog.classic,
    error: (_, __) => BoardThemeCatalog.classic,
  );
});

/// Whether the signed-in user has unlocked the premium board themes.
final boardThemesUnlockedProvider = FutureProvider<bool>((ref) => ref.watch(
      premiumFeatureProvider(BoardThemeCatalog.premiumFeatureKey).future,
    ));
