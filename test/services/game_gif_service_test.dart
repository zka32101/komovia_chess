import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_chess/src/services/game_gif_service.dart';

void main() {
  late GameGifService service;

  setUp(() {
    service = GameGifService();
  });

  test('generates a valid non-empty GIF for a short real game', () async {
    // 1. e4 e5 2. Nf3 - three legal half-moves from the standard start.
    final gifBytes = await service.generateGif(moves: const [
      (from: 'e2', to: 'e4', promotion: null),
      (from: 'e7', to: 'e5', promotion: null),
      (from: 'g1', to: 'f3', promotion: null),
    ]);

    expect(gifBytes, isNotEmpty);
    // GIF magic header: "GIF89a" or "GIF87a".
    expect(gifBytes.sublist(0, 3), [0x47, 0x49, 0x46]);
  });

  test('produces at least an initial-position frame for an empty move list',
      () async {
    final gifBytes = await service.generateGif(moves: const []);
    expect(gifBytes, isNotEmpty);
  });

  test('skips an illegal/malformed move instead of throwing', () async {
    final gifBytes = await service.generateGif(moves: const [
      (from: 'e2', to: 'e4', promotion: null),
      (from: 'a1', to: 'a1', promotion: null), // not a legal move
      (from: 'e7', to: 'e5', promotion: null),
    ]);

    expect(gifBytes, isNotEmpty);
  });
}
