import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_chess/src/providers/event_provider.dart';
import 'package:komovia_chess/src/services/event_config_service.dart';

class _FakeSource implements EventConfigSource {
  _FakeSource(this.values);
  final Map<String, String> values;
  @override
  String getString(String key) => values[key] ?? '';
}

ProviderContainer _container(Map<String, String> values, DateTime now) =>
    ProviderContainer(overrides: [
      eventConfigSourceProvider.overrideWithValue(_FakeSource(values)),
      eventClockProvider.overrideWithValue(() => now),
    ]);

void main() {
  final now = DateTime.utc(2026, 11, 5);
  const window = {
    'hybrid_battle_event_start': '2026-11-01T00:00:00Z',
    'hybrid_battle_event_end': '2026-11-15T00:00:00Z',
  };

  test('defaults keep every event key empty', () {
    expect(EventConfigService.defaults.values.every((v) => v == ''), isTrue);
    expect(EventConfigService.defaults.length, NoveltyEvent.values.length * 2);
  });

  test('unconfigured event is hidden (fail closed)', () {
    final c = _container({}, now);
    expect(c.read(eventWindowProvider(NoveltyEvent.hybridBattle)), isNull);
    expect(c.read(eventActiveProvider(NoveltyEvent.hybridBattle)), isFalse);
    expect(c.read(eventActiveProvider(NoveltyEvent.shogi)), isFalse);
  });

  test('malformed config is hidden', () {
    final c = _container({
      'novelty_shogi_event_start': 'not a date',
      'novelty_shogi_event_end': '2026-11-15T00:00:00Z',
    }, now);
    expect(c.read(eventActiveProvider(NoveltyEvent.shogi)), isFalse);
  });

  test('active inside the window, only for its own keys', () {
    final c = _container(window, now);
    expect(c.read(eventActiveProvider(NoveltyEvent.hybridBattle)), isTrue);
    expect(c.read(eventActiveProvider(NoveltyEvent.shogi)), isFalse);
  });

  test('inactive before and after the window', () {
    expect(
        _container(window, DateTime.utc(2026, 10, 31))
            .read(eventActiveProvider(NoveltyEvent.hybridBattle)),
        isFalse);
    expect(
        _container(window, DateTime.utc(2026, 11, 15))
            .read(eventActiveProvider(NoveltyEvent.hybridBattle)),
        isFalse);
  });
}
