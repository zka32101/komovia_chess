import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_preferences_provider.dart';
import '../../utils/komovia_cross_promo_roster.dart';
import 'sound_preferences_screen.dart';
import 'legal_documents_screen.dart';
import 'board_themes_screen.dart';
import '../../providers/board_theme_provider.dart';
import '../../l10n/app_localizations.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferencesAsync = ref.watch(userPreferencesProvider);
    final preferencesService = ref.watch(userPreferencesServiceProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsTitle),
        centerTitle: true,
        elevation: 0,
      ),
      body: preferencesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => Center(
          child: Text(l10n.settingsErrorMessage(error.toString())),
        ),
        data: (preferences) => SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Theme settings
                _buildSettingSection(
                  title: l10n.settingsDisplaySection,
                  children: [
                    _buildThemeOption(
                      context,
                      ref,
                      preferences.themeMode,
                      preferencesService,
                      l10n,
                    ),
                    const Divider(height: 1),
                    _buildLanguageOption(
                      context,
                      ref,
                      preferences.language,
                      preferencesService,
                      l10n,
                    ),
                  ],
                ),

                // Sound & Notifications
                _buildSettingSection(
                  title: l10n.settingsSoundNotificationsSection,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.volume_up),
                      title: Text(l10n.settingsSoundSettingsTitle),
                      subtitle: Text(l10n.settingsSoundSettingsSubtitle),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const SoundPreferencesScreen(),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    _buildToggleOption(
                      title: l10n.settingsNotificationsTitle,
                      subtitle: l10n.settingsNotificationsSubtitle,
                      value: preferences.notificationsEnabled,
                      onChanged: (value) {
                        preferencesService.setNotificationsEnabled(value);
                      },
                    ),
                    const Divider(height: 1),
                    _buildToggleOption(
                      title: l10n.settingsFriendRequestsTitle,
                      subtitle: l10n.settingsFriendRequestsSubtitle,
                      value: preferences.notificationsEnabled &&
                          preferences.notifyFriendRequests,
                      onChanged: preferences.notificationsEnabled
                          ? (value) {
                              preferencesService.setNotifyFriendRequests(value);
                            }
                          : null,
                    ),
                    const Divider(height: 1),
                    _buildToggleOption(
                      title: l10n.settingsGameAlertsTitle,
                      subtitle: l10n.settingsGameAlertsSubtitle,
                      value: preferences.notificationsEnabled &&
                          preferences.notifyGameAlerts,
                      onChanged: preferences.notificationsEnabled
                          ? (value) {
                              preferencesService.setNotifyGameAlerts(value);
                            }
                          : null,
                    ),
                    const Divider(height: 1),
                    _buildToggleOption(
                      title: l10n.settingsAchievementsTitle,
                      subtitle: l10n.settingsAchievementsSubtitle,
                      value: preferences.notificationsEnabled &&
                          preferences.notifyAchievements,
                      onChanged: preferences.notificationsEnabled
                          ? (value) {
                              preferencesService.setNotifyAchievements(value);
                            }
                          : null,
                    ),
                  ],
                ),

                // Board settings
                _buildSettingSection(
                  title: l10n.settingsBoardSection,
                  children: [
                    _buildBoardSizeOption(
                      context,
                      ref,
                      preferences.boardSize,
                      preferencesService,
                      l10n,
                    ),
                    const Divider(height: 1),
                    _buildToggleOption(
                      title: l10n.settingsShowCoordinatesTitle,
                      subtitle: l10n.settingsShowCoordinatesSubtitle,
                      value: preferences.showCoordinates,
                      onChanged: (value) {
                        preferencesService.setShowCoordinates(value);
                      },
                    ),
                    const Divider(height: 1),
                    _buildBoardThemeOption(context, ref, l10n),
                  ],
                ),

                // Analysis settings - previously no user-facing control
                // over post-game computer analysis quality at all
                // (GameReviewScreen's Stockfish evaluation was hardcoded
                // to a fixed 500ms time budget).
                _buildSettingSection(
                  title: l10n.settingsAnalysisSection,
                  children: [
                    _buildAnalysisDepthOption(
                      context,
                      preferences.analysisDepth,
                      preferencesService,
                      l10n,
                    ),
                    const Divider(height: 1),
                    _buildBlindfoldModeOption(
                      preferences.blindfoldMode,
                      preferencesService,
                      l10n,
                    ),
                  ],
                ),

                // Account settings
                _buildSettingSection(
                  title: l10n.settingsAccountSection,
                  children: [
                    ListTile(
                      title: Text(l10n.settingsResetToDefaultsTitle),
                      subtitle: Text(l10n.settingsResetToDefaultsSubtitle),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        _showResetDialog(context, preferencesService, l10n);
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.logout),
                      title: Text(l10n.settingsSignOutTitle),
                      onTap: () {
                        _showSignOutDialog(context, ref, l10n);
                      },
                    ),
                  ],
                ),

                // Cross-promotion for the other Komovia series apps
                _buildSettingSection(
                  title: l10n.settingsCrossPromoSection,
                  children: _buildCrossPromoTiles(context, l10n),
                ),

                // About
                _buildSettingSection(
                  title: l10n.settingsAboutSection,
                  children: [
                    ListTile(
                      title: Text(l10n.settingsVersionTitle),
                      subtitle: const Text('1.0.0'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: Text(l10n.settingsPrivacyPolicyTitle),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LegalDocumentsScreen(
                                documentType: 'privacy'),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: Text(l10n.settingsTermsOfServiceTitle),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LegalDocumentsScreen(
                                documentType: 'terms'),
                          ),
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// One tappable [ListTile] per sibling Komovia app (shogi/go), built
  /// from the shared [PromotedApp] model (komovia_core). The store URL
  /// is intentionally just a honest placeholder for now (see
  /// komovia_cross_promo_roster.dart) - tapping a not-yet-published
  /// sibling shows a "まだ公開されていません" message instead of
  /// opening a broken link, the same honest-coming-soon convention
  /// already used elsewhere in this app for unfinished integrations.
  List<Widget> _buildCrossPromoTiles(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    final others = otherKomoviaApps(komoviaRoster, kKomoviaChessAppId);
    final tiles = <Widget>[];

    for (var i = 0; i < others.length; i++) {
      if (i > 0) tiles.add(const Divider(height: 1));
      final app = others[i];
      tiles.add(
        ListTile(
          leading: Icon(_iconForCategory(app.category)),
          title: Text(app.name),
          subtitle: Text(app.tagline),
          trailing: const Icon(Icons.open_in_new, size: 16),
          onTap: () => _openStore(context, app, l10n),
        ),
      );
    }

    return tiles;
  }

  IconData _iconForCategory(String category) {
    switch (category) {
      case 'shogi':
        return Icons.sports_esports;
      case 'go':
        return Icons.circle_outlined;
      case 'chess':
        return Icons.sports_esports_outlined;
      default:
        return Icons.apps;
    }
  }

  Future<void> _openStore(
    BuildContext context,
    PromotedApp app,
    AppLocalizations l10n,
  ) async {
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    final storeUrl = app.storeUrlFor(isIOS: isIOS);

    if (storeUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.settingsAppNotYetPublishedMessage(app.name)),
        ),
      );
      return;
    }

    final uri = Uri.parse(storeUrl);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.settingsAppStoreOpenFailedMessage(app.name)),
        ),
      );
    }
  }

  Widget _buildSettingSection({
    required String title,
    required List<Widget> children,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(children: children),
          ),
          const SizedBox(height: 16),
        ],
      );

  Widget _buildThemeOption(
    BuildContext context,
    WidgetRef ref,
    ThemeMode currentMode,
    UserPreferencesService service,
    AppLocalizations l10n,
  ) =>
      ListTile(
        title: Text(l10n.settingsThemeTitle),
        subtitle: Text(
          currentMode == ThemeMode.light
              ? l10n.settingsThemeLight
              : currentMode == ThemeMode.dark
                  ? l10n.settingsThemeDark
                  : l10n.settingsThemeSystem,
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          showModalBottomSheet(
            context: context,
            builder: (context) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: Text(l10n.settingsThemeLight),
                    trailing: currentMode == ThemeMode.light
                        ? const Icon(Icons.check, color: Colors.blue)
                        : null,
                    onTap: () {
                      service.setThemeMode(ThemeMode.light);
                      ref.read(themeModeProvider.notifier).state =
                          ThemeMode.light;
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    title: Text(l10n.settingsThemeDark),
                    trailing: currentMode == ThemeMode.dark
                        ? const Icon(Icons.check, color: Colors.blue)
                        : null,
                    onTap: () {
                      service.setThemeMode(ThemeMode.dark);
                      ref.read(themeModeProvider.notifier).state =
                          ThemeMode.dark;
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    title: Text(l10n.settingsThemeSystem),
                    trailing: currentMode == ThemeMode.system
                        ? const Icon(Icons.check, color: Colors.blue)
                        : null,
                    onTap: () {
                      service.setThemeMode(ThemeMode.system);
                      ref.read(themeModeProvider.notifier).state =
                          ThemeMode.system;
                      Navigator.pop(context);
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
      );

  Widget _buildLanguageOption(
    BuildContext context,
    WidgetRef ref,
    String currentLanguage,
    UserPreferencesService service,
    AppLocalizations l10n,
  ) =>
      ListTile(
        title: Text(l10n.settingsLanguageTitle),
        subtitle: Text(
          currentLanguage == 'en'
              ? l10n.settingsLanguageEnglish
              : l10n.settingsLanguageJapanese,
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          showModalBottomSheet(
            context: context,
            builder: (context) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: Text(l10n.settingsLanguageEnglish),
                    trailing: currentLanguage == 'en'
                        ? const Icon(Icons.check, color: Colors.blue)
                        : null,
                    onTap: () {
                      service.setLanguage('en');
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    title: Text(l10n.settingsLanguageJapanese),
                    trailing: currentLanguage == 'ja'
                        ? const Icon(Icons.check, color: Colors.blue)
                        : null,
                    onTap: () {
                      service.setLanguage('ja');
                      Navigator.pop(context);
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
      );

  Widget _buildBoardSizeOption(
    BuildContext context,
    WidgetRef ref,
    int currentSize,
    UserPreferencesService service,
    AppLocalizations l10n,
  ) =>
      ListTile(
        title: Text(l10n.settingsBoardSizeTitle),
        subtitle: Text(l10n.settingsBoardSizePixels(currentSize)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          showModalBottomSheet(
            context: context,
            builder: (context) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.settingsSelectBoardSizeTitle,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Slider(
                          value: currentSize.toDouble(),
                          min: 300,
                          max: 600,
                          divisions: 6,
                          label: '${currentSize}px',
                          onChanged: (value) {
                            service.setBoardSize(value.toInt());
                          },
                        ),
                        Text(
                          l10n.settingsCurrentBoardSize(currentSize),
                          style: TextStyle(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
      );

  Widget _buildAnalysisDepthOption(
    BuildContext context,
    int currentDepth,
    UserPreferencesService service,
    AppLocalizations l10n,
  ) =>
      ListTile(
        title: Text(l10n.settingsAnalysisDepthTitle),
        subtitle: Text(l10n.settingsAnalysisDepthSubtitle(currentDepth)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          showModalBottomSheet(
            context: context,
            builder: (context) => SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.settingsComputerAnalysisDepthTitle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Slider(
                      value: currentDepth.toDouble(),
                      min: 8,
                      max: 20,
                      divisions: 12,
                      label: l10n.settingsAnalysisDepthLabel(currentDepth),
                      onChanged: (value) {
                        service.setAnalysisDepth(value.toInt());
                      },
                    ),
                    Text(
                      l10n.settingsAnalysisDepthDescription,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );

  Widget _buildBlindfoldModeOption(
    bool enabled,
    UserPreferencesService service,
    AppLocalizations l10n,
  ) =>
      SwitchListTile(
        title: Text(l10n.settingsBlindfoldModeTitle),
        subtitle: Text(l10n.settingsBlindfoldModeSubtitle),
        value: enabled,
        onChanged: (value) {
          service.setBlindfoldMode(value);
        },
      );

  Widget _buildBoardThemeOption(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    final selectedTheme = ref.watch(selectedBoardThemeProvider);

    return ListTile(
      leading: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          gradient: LinearGradient(
            colors: [
              selectedTheme.lightSquareColor,
              selectedTheme.darkSquareColor,
            ],
          ),
        ),
      ),
      title: Text(l10n.settingsBoardThemeTitle),
      subtitle: Text(selectedTheme.displayName),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const BoardThemesScreen(),
          ),
        );
      },
    );
  }

  Widget _buildToggleOption({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool)? onChanged,
  }) =>
      ListTile(
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
        ),
      );

  void _showResetDialog(
    BuildContext context,
    UserPreferencesService service,
    AppLocalizations l10n,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.settingsResetSettingsTitle),
        content: Text(l10n.settingsResetSettingsConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.settingsCancelButton),
          ),
          FilledButton(
            onPressed: () {
              service.resetToDefaults();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.settingsResetDoneMessage)),
              );
            },
            child: Text(l10n.settingsResetButton),
          ),
        ],
      ),
    );
  }

  void _showSignOutDialog(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.settingsSignOutTitle),
        content: Text(l10n.settingsSignOutConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.settingsCancelButton),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(authStateNotifierProvider.notifier).signOut();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text(l10n.settingsSignOutErrorMessage(e.toString())),
                    ),
                  );
                }
              }
            },
            child: Text(l10n.settingsSignOutButton),
          ),
        ],
      ),
    );
  }
}
