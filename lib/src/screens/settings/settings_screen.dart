import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_preferences_provider.dart';
import 'sound_preferences_screen.dart';
import 'legal_documents_screen.dart';
import 'board_themes_screen.dart';
import '../../providers/board_theme_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferencesAsync = ref.watch(userPreferencesProvider);
    final preferencesService = ref.watch(userPreferencesServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
        elevation: 0,
      ),
      body: preferencesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => Center(
          child: Text('Error: $error'),
        ),
        data: (preferences) => SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Theme settings
                _buildSettingSection(
                  title: 'Display',
                  children: [
                    _buildThemeOption(
                      context,
                      ref,
                      preferences.themeMode,
                      preferencesService,
                    ),
                    const Divider(height: 1),
                    _buildLanguageOption(
                      context,
                      ref,
                      preferences.language,
                      preferencesService,
                    ),
                  ],
                ),

                // Sound & Notifications
                _buildSettingSection(
                  title: 'Sound & Notifications',
                  children: [
                    ListTile(
                      leading: const Icon(Icons.volume_up),
                      title: const Text('Sound Settings'),
                      subtitle: const Text('Manage sound effects and volume'),
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
                      title: 'Notifications',
                      subtitle: 'Receive game and match notifications',
                      value: preferences.notificationsEnabled,
                      onChanged: (value) {
                        preferencesService.setNotificationsEnabled(value);
                      },
                    ),
                  ],
                ),

                // Board settings
                _buildSettingSection(
                  title: 'Board',
                  children: [
                    _buildBoardSizeOption(
                      context,
                      ref,
                      preferences.boardSize,
                      preferencesService,
                    ),
                    const Divider(height: 1),
                    _buildToggleOption(
                      title: 'Show Coordinates',
                      subtitle: 'Display board coordinates (a-h, 1-8)',
                      value: preferences.showCoordinates,
                      onChanged: (value) {
                        preferencesService.setShowCoordinates(value);
                      },
                    ),
                    const Divider(height: 1),
                    _buildBoardThemeOption(context, ref),
                    const Divider(height: 1),
                    _buildStyleOption(
                      title: 'Piece Style',
                      currentValue: preferences.pieceStyle,
                      options: const ['Default', 'Wooden', 'Classic'],
                      onChanged: (value) {
                        preferencesService.setStyles(
                          pieceStyle: value.toLowerCase(),
                          boardStyle: preferences.boardStyle,
                        );
                      },
                    ),
                  ],
                ),

                // Account settings
                _buildSettingSection(
                  title: 'Account',
                  children: [
                    ListTile(
                      title: const Text('Reset to Defaults'),
                      subtitle:
                          const Text('Restore all settings to default values'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        _showResetDialog(context, preferencesService);
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.logout),
                      title: const Text('Sign Out'),
                      onTap: () {
                        _showSignOutDialog(context, ref);
                      },
                    ),
                  ],
                ),

                // About
                _buildSettingSection(
                  title: 'About',
                  children: [
                    const ListTile(
                      title: Text('Version'),
                      subtitle: Text('1.0.0'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: const Text('Privacy Policy'),
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
                      title: const Text('Terms of Service'),
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
  ) =>
      ListTile(
        title: const Text('Theme'),
        subtitle: Text(
          currentMode == ThemeMode.light
              ? 'Light'
              : currentMode == ThemeMode.dark
                  ? 'Dark'
                  : 'System',
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
                    title: const Text('Light'),
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
                    title: const Text('Dark'),
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
                    title: const Text('System'),
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
  ) =>
      ListTile(
        title: const Text('Language'),
        subtitle: Text(
          currentLanguage == 'en' ? 'English' : '日本語',
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
                    title: const Text('English'),
                    trailing: currentLanguage == 'en'
                        ? const Icon(Icons.check, color: Colors.blue)
                        : null,
                    onTap: () {
                      service.setLanguage('en');
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    title: const Text('日本語'),
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
  ) =>
      ListTile(
        title: const Text('Board Size'),
        subtitle: Text('$currentSize × $currentSize pixels'),
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
                        const Text(
                          'Select Board Size',
                          style: TextStyle(
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
                          'Current: $currentSize × $currentSize pixels',
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

  Widget _buildBoardThemeOption(BuildContext context, WidgetRef ref) {
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
      title: const Text('Board Theme'),
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

  Widget _buildStyleOption({
    required String title,
    required String currentValue,
    required List<String> options,
    required Function(String) onChanged,
  }) =>
      Builder(
        builder: (context) => ListTile(
          title: Text(title),
          subtitle:
              Text(currentValue[0].toUpperCase() + currentValue.substring(1)),
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
                      child: Text(
                        'Select $title',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    ...options.map((option) => ListTile(
                          title: Text(option),
                          trailing: option.toLowerCase() == currentValue
                              ? const Icon(Icons.check, color: Colors.blue)
                              : null,
                          onTap: () {
                            onChanged(option.toLowerCase());
                            Navigator.pop(context);
                          },
                        )),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        ),
      );

  Widget _buildToggleOption({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
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
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Settings'),
        content: const Text(
            'Are you sure you want to reset all settings to their default values?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              service.resetToDefaults();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Settings reset to defaults')),
              );
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  void _showSignOutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(authStateNotifierProvider.notifier).signOut();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error signing out: $e')),
                  );
                }
              }
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}
