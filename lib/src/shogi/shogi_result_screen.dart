import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'shogi_engine.dart';

/// Minimal result screen for the bonus shogi mode, following the same
/// "icon + title + two actions" shape as this app's other result screens
/// (e.g. the chess GameResult widget), simplified since this mode keeps no
/// statistics, move history, or persistence.
class ShogiResultScreen extends StatelessWidget {
  const ShogiResultScreen({required this.outcome, super.key});

  final ShogiOutcome outcome;

  String _title(AppLocalizations l10n) {
    switch (outcome) {
      case ShogiOutcome.senteWins:
        return l10n.shogiResultSenteWins;
      case ShogiOutcome.goteWins:
        return l10n.shogiResultGoteWins;
      case ShogiOutcome.stalemateDraw:
        return l10n.shogiResultStalemateDraw;
      case ShogiOutcome.none:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.shogiScreenTitle)),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  outcome == ShogiOutcome.stalemateDraw
                      ? Icons.handshake_outlined
                      : Icons.emoji_events,
                  size: 72,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  _title(l10n),
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(true),
                  icon: const Icon(Icons.replay),
                  label: Text(l10n.shogiPlayAgainButton),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(false),
                  icon: const Icon(Icons.home_outlined),
                  label: Text(l10n.shogiBackToHomeButton),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
