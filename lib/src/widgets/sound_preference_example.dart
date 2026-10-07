import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/sound_preferences_provider.dart';
import '../providers/sound_manager_provider.dart';
import '../services/sound_service.dart';

/// Example widget showing how to use sound preferences throughout the app
class SoundPreferenceExample extends ConsumerWidget {
  const SoundPreferenceExample({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final soundPreferencesAsync = ref.watch(soundPreferencesProvider);
    final soundManagerAsync = ref.watch(soundManagerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sound Preferences Demo'),
      ),
      body: soundPreferencesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
        data: (preferences) => soundManagerAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(child: Text('Error: $error')),
          data: (soundManager) => SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Current preferences display
                  _buildPreferencesDisplay(preferences),
                  const SizedBox(height: 24),

                  // Sound test buttons
                  _buildSoundTestSection(context, ref, soundManager),
                  const SizedBox(height: 24),

                  // Usage examples
                  _buildUsageExamples(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreferencesDisplay(SoundPreferences prefs) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Current Preferences',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildPreferenceRow('Master Sound', prefs.soundMasterEnabled),
              _buildPreferenceRow(
                  'Volume', '${(prefs.volume * 100).toStringAsFixed(0)}%'),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'Category Status:',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey),
              ),
              const SizedBox(height: 8),
              for (final category in SoundCategory.values)
                _buildPreferenceRow(
                  category.displayName,
                  prefs.isCategoryEnabled(category) ? 'Enabled' : 'Disabled',
                ),
            ],
          ),
        ),
      );

  Widget _buildPreferenceRow(String label, dynamic value) {
    final valueText =
        value is bool ? (value ? '✓ Enabled' : '✗ Disabled') : value.toString();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(
            valueText,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: value is bool
                  ? (value ? Colors.green : Colors.red)
                  : Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSoundTestSection(
    BuildContext context,
    WidgetRef ref,
    SoundManager soundManager,
  ) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Test Sounds',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: () => soundManager.play(SoundEffect.movePiece),
                icon: const Icon(Icons.videogame_asset),
                label: const Text('Move'),
              ),
              ElevatedButton.icon(
                onPressed: () => soundManager.play(SoundEffect.capture),
                icon: const Icon(Icons.close),
                label: const Text('Capture'),
              ),
              ElevatedButton.icon(
                onPressed: () => soundManager.play(SoundEffect.check),
                icon: const Icon(Icons.warning),
                label: const Text('Check'),
              ),
              ElevatedButton.icon(
                onPressed: () => soundManager.play(SoundEffect.checkmate),
                icon: const Icon(Icons.flag),
                label: const Text('Checkmate'),
              ),
              ElevatedButton.icon(
                onPressed: () => soundManager.play(SoundEffect.buttonTap),
                icon: const Icon(Icons.touch_app),
                label: const Text('UI Tap'),
              ),
              ElevatedButton.icon(
                onPressed: () => soundManager.play(SoundEffect.notification),
                icon: const Icon(Icons.notifications),
                label: const Text('Alert'),
              ),
            ],
          ),
        ],
      );

  Widget _buildUsageExamples() => Card(
        color: Colors.grey.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'How to Use in Your Code',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildCodeExample(
                'Play Sound (Async)',
                '''
final soundManager = await ref.read(soundManagerProvider.future);
await soundManager.play(SoundEffect.movePiece);''',
              ),
              const SizedBox(height: 12),
              _buildCodeExample(
                'Check if Category Enabled',
                '''
final soundManager = await ref.read(soundManagerProvider.future);
bool isGamePlaySoundEnabled =
    soundManager.isCategoryEnabled(SoundCategory.gamePlay);''',
              ),
              const SizedBox(height: 12),
              _buildCodeExample(
                'In ConsumerWidget',
                '''
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final soundManager = ref.watch(soundManagerProvider);
    return soundManager.when(
      data: (manager) => GestureDetector(
        onTap: () => manager.play(SoundEffect.buttonTap),
        child: child,
      ),
      loading: () => ...,
      error: (e, st) => ...,
    );
  }
}''',
              ),
            ],
          ),
        ),
      );

  Widget _buildCodeExample(String title, String code) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              code,
              style: const TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: Colors.black87,
                height: 1.4,
              ),
            ),
          ),
        ],
      );
}
