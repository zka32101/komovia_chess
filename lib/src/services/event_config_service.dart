import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:komovia_core/komovia_core.dart';

/// Time-limited novelty events gated by Remote Config. Each event has a
/// pair of ISO-8601 string keys; missing/empty/unparseable values mean
/// "no event configured" and the feature stays HIDDEN (fail closed).
enum NoveltyEvent {
  shogi('novelty_shogi_event_start', 'novelty_shogi_event_end'),
  hybridBattle('hybrid_battle_event_start', 'hybrid_battle_event_end');

  const NoveltyEvent(this.startKey, this.endKey);
  final String startKey;
  final String endKey;
}

/// Minimal key/value source so tests can substitute a fake instead of
/// Firebase Remote Config.
abstract class EventConfigSource {
  String getString(String key);
}

class RemoteConfigEventSource implements EventConfigSource {
  @override
  String getString(String key) {
    try {
      return FirebaseRemoteConfig.instance.getString(key);
    } catch (e) {
      // Firebase not initialized (e.g. dev build without config): no event.
      return '';
    }
  }
}

class EventConfigService {
  EventConfigService(this._source);
  final EventConfigSource _source;

  /// Remote Config defaults: every event key empty = every event hidden.
  static Map<String, dynamic> get defaults => {
        for (final e in NoveltyEvent.values) ...{e.startKey: '', e.endKey: ''},
      };

  /// Called once from main() after Firebase.initializeApp. Failures are
  /// logged and swallowed - defaults (all events hidden) remain in effect.
  static Future<void> initialize() async {
    try {
      final rc = FirebaseRemoteConfig.instance;
      await rc.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 1),
      ));
      await rc.setDefaults(defaults);
      await rc.fetchAndActivate();
      debugPrint('✅ Remote Config fetched/activated');
    } catch (e) {
      debugPrint('⚠️ Remote Config initialization warning: $e');
    }
  }

  EventWindow? windowFor(NoveltyEvent event) => EventWindow.tryParse(
        startIso: _source.getString(event.startKey),
        endIso: _source.getString(event.endKey),
      );
}
