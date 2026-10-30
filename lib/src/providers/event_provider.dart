import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_core/komovia_core.dart';

import '../services/event_config_service.dart';

export '../services/event_config_service.dart' show NoveltyEvent;

final eventConfigSourceProvider =
    Provider<EventConfigSource>((ref) => RemoteConfigEventSource());

final eventConfigServiceProvider = Provider<EventConfigService>(
  (ref) => EventConfigService(ref.watch(eventConfigSourceProvider)),
);

/// Injectable clock so tests can pin "now".
final eventClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// The configured window for [NoveltyEvent], or null when none is configured.
final eventWindowProvider = Provider.family<EventWindow?, NoveltyEvent>(
  (ref, event) => ref.watch(eventConfigServiceProvider).windowFor(event),
);

/// Whether the event is running right now. Null window -> false (hidden).
final eventActiveProvider = Provider.family<bool, NoveltyEvent>((ref, event) {
  final window = ref.watch(eventWindowProvider(event));
  if (window == null) return false;
  return window.isActive(ref.watch(eventClockProvider)());
});
