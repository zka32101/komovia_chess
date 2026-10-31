import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_chess/src/models/online_game.dart';

OnlineGame _game({
  String status = 'active',
  DateTime? createdAt,
  DateTime? whiteLast,
  DateTime? blackLast,
}) =>
    OnlineGame(
      gameId: 'g',
      type: 'online_pvp',
      status: status,
      createdAt: createdAt ?? DateTime.now(),
      whitePlayerId: 'w',
      blackPlayerId: 'b',
      whitePlayerName: 'W',
      blackPlayerName: 'B',
      whiteRating: 1200,
      blackRating: 1200,
      pgn: '',
      currentFen: '',
      moves: const [], // white to move
      timeControl: '10min',
      timeControlMs: 600000,
      whiteTimeRemainingMs: 600000,
      blackTimeRemainingMs: 600000,
      whiteLastActivityTimestamp: whiteLast,
      blackLastActivityTimestamp: blackLast,
    );

void main() {
  final old = DateTime.now().subtract(const Duration(hours: 49));
  final recent = DateTime.now().subtract(const Duration(hours: 1));

  test('waiting player can claim after 48h of delinquent inactivity', () {
    expect(_game(whiteLast: old).canClaimAbandonmentForfeit('b'), isTrue);
  });
  test('player on turn cannot claim', () {
    expect(_game(whiteLast: old).canClaimAbandonmentForfeit('w'), isFalse);
  });
  test('not claimable before threshold', () {
    expect(_game(whiteLast: recent).canClaimAbandonmentForfeit('b'), isFalse);
  });
  test('falls back to createdAt when no activity recorded', () {
    expect(_game(createdAt: old).canClaimAbandonmentForfeit('b'), isTrue);
    expect(_game(createdAt: recent).canClaimAbandonmentForfeit('b'), isFalse);
  });
  test('non-participant and non-active games cannot claim', () {
    expect(_game(whiteLast: old).canClaimAbandonmentForfeit('x'), isFalse);
    expect(_game(status: 'completed', whiteLast: old)
        .canClaimAbandonmentForfeit('b'), isFalse);
  });
  test('custom threshold is honored', () {
    expect(
        _game(whiteLast: recent).canClaimAbandonmentForfeit('b',
            threshold: const Duration(minutes: 30)),
        isTrue);
  });
}
