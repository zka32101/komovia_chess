import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/board_theme.dart';
import '../../providers/board_theme_provider.dart';
import '../../providers/user_preferences_provider.dart';

/// Lets the user pick a board/piece theme pack. Free themes apply
/// immediately; premium themes show a lock badge and, until unlocked,
/// tapping one explains why instead of applying it.
class BoardThemesScreen extends ConsumerWidget {
  const BoardThemesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTheme = ref.watch(selectedBoardThemeProvider);
    final unlockedAsync = ref.watch(boardThemesUnlockedProvider);
    final preferencesService = ref.watch(userPreferencesServiceProvider);
    final preferencesAsync = ref.watch(userPreferencesProvider);
    final isUnlocked = unlockedAsync.value ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Board Themes'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.85,
          ),
          itemCount: BoardThemeCatalog.all.length,
          itemBuilder: (context, index) {
            final theme = BoardThemeCatalog.all[index];
            final isSelected = theme.id == selectedTheme.id;
            final isLocked = theme.isPremium && !isUnlocked;

            return _ThemeCard(
              theme: theme,
              isSelected: isSelected,
              isLocked: isLocked,
              onTap: () {
                if (isLocked) {
                  _showPremiumMessage(context);
                  return;
                }
                final currentPieceStyle =
                    preferencesAsync.value?.pieceStyle ?? 'default';
                preferencesService.setStyles(
                  pieceStyle: currentPieceStyle,
                  boardStyle: theme.id,
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _showPremiumMessage(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Premium Theme'),
        content: const Text(
          'This board theme is part of the premium theme pack. '
          'Upgrade to Pro or Premium to unlock it, plus the rest of the '
          'app\'s premium features.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.theme,
    required this.isSelected,
    required this.isLocked,
    required this.onTap,
  });
  final BoardTheme theme;
  final bool isSelected;
  final bool isLocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey.shade300,
              width: isSelected ? 2.5 : 1,
            ),
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Opacity(
                          opacity: isLocked ? 0.45 : 1,
                          child: _MiniBoardPreview(theme: theme),
                        ),
                      ),
                    ),
                    if (isLocked)
                      const Positioned(
                        top: 6,
                        right: 6,
                        child:
                            Icon(Icons.lock, color: Colors.black54, size: 20),
                      ),
                    if (isSelected)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Icon(
                          Icons.check_circle,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    theme.displayName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (theme.isPremium) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.workspace_premium,
                      size: 14,
                      color: Colors.amber.shade700,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      );
}

/// A tiny static 4x4 checkerboard swatch previewing a [BoardTheme], with a
/// king glyph on each color to preview the piece colors too.
class _MiniBoardPreview extends StatelessWidget {
  const _MiniBoardPreview({required this.theme});
  final BoardTheme theme;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final squareSize = constraints.maxWidth / 4;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
                4,
                (row) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(4, (col) {
                        final isLight = (row + col).isEven;
                        final showWhiteKing = row == 2 && col == 1;
                        final showBlackKing = row == 1 && col == 2;
                        return Container(
                          width: squareSize,
                          height: squareSize,
                          color: isLight
                              ? theme.lightSquareColor
                              : theme.darkSquareColor,
                          child: showWhiteKing || showBlackKing
                              ? Center(
                                  child: Text(
                                    '♚',
                                    style: TextStyle(
                                      fontSize: squareSize * 0.75,
                                      color: showWhiteKing
                                          ? theme.whitePieceColor
                                          : theme.blackPieceColor,
                                    ),
                                  ),
                                )
                              : null,
                        );
                      }),
                    )),
          );
        },
      );
}
