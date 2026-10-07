import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/sound_preferences_provider.dart';

class SoundPreferencesScreen extends ConsumerWidget {
  const SoundPreferencesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferencesAsync = ref.watch(soundPreferencesProvider);
    final preferencesService = ref.watch(soundPreferencesServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sound Settings'),
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
                // Master sound toggle
                _buildMasterControlSection(
                  context,
                  ref,
                  preferences,
                  preferencesService,
                ),

                // Volume control
                _buildVolumeControlSection(
                  context,
                  ref,
                  preferences,
                  preferencesService,
                ),

                // Sound category toggles
                _buildCategoryControlsSection(
                  context,
                  ref,
                  preferences,
                  preferencesService,
                ),

                // Help text
                _buildHelpSection(),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMasterControlSection(
    BuildContext context,
    WidgetRef ref,
    SoundPreferences preferences,
    SoundPreferencesService service,
  ) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Master Volume',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Turn all sounds on or off',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: Icon(
                preferences.soundMasterEnabled
                    ? Icons.volume_up
                    : Icons.volume_off,
                size: 28,
              ),
              title: const Text('All Sound Effects'),
              subtitle: preferences.soundMasterEnabled
                  ? const Text('Sounds are enabled')
                  : const Text('All sounds are muted'),
              trailing: Switch(
                value: preferences.soundMasterEnabled,
                onChanged: (value) {
                  service.setSoundMasterEnabled(value);
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      );

  Widget _buildVolumeControlSection(
    BuildContext context,
    WidgetRef ref,
    SoundPreferences preferences,
    SoundPreferencesService service,
  ) {
    final volume = ref.watch(soundVolumeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Volume',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Adjust overall sound volume',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.volume_mute,
                      color: Colors.grey.shade600,
                    ),
                    Expanded(
                      child: Slider(
                        value: volume,
                        min: 0,
                        max: 1,
                        divisions: 10,
                        onChanged: preferences.soundMasterEnabled
                            ? (value) {
                                service.setVolume(value);
                              }
                            : null,
                      ),
                    ),
                    Icon(
                      Icons.volume_up,
                      color: Colors.grey.shade600,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Volume: ${(volume * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildCategoryControlsSection(
    BuildContext context,
    WidgetRef ref,
    SoundPreferences preferences,
    SoundPreferencesService service,
  ) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sound Categories',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Enable or disable specific sound types',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                for (int i = 0; i < SoundCategory.values.length; i++) ...[
                  _buildCategoryTile(
                    context,
                    ref,
                    SoundCategory.values[i],
                    preferences,
                    service,
                  ),
                  if (i < SoundCategory.values.length - 1)
                    const Divider(height: 1),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      );

  Widget _buildCategoryTile(
    BuildContext context,
    WidgetRef ref,
    SoundCategory category,
    SoundPreferences preferences,
    SoundPreferencesService service,
  ) {
    final isEnabled = ref.watch(soundCategoryProvider(category));

    return ListTile(
      leading: Icon(
        category.icon,
        size: 28,
      ),
      title: Text(category.displayName),
      subtitle: Text(category.description),
      trailing: Switch(
        value: isEnabled,
        onChanged: preferences.soundMasterEnabled
            ? (value) {
                service.setCategoryEnabled(category, value);
              }
            : null,
      ),
    );
  }

  Widget _buildHelpSection() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline,
                color: Colors.blue.shade700,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Disable "All Sound Effects" to mute everything. Individual categories can only be toggled when the master control is on.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue.shade700,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}
