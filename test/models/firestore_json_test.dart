import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_chess/src/models/firestore_json.dart';
import 'package:komovia_chess/src/models/puzzle.dart';

void main() {
  final created = DateTime.utc(2026, 10, 30, 11, 22, 33);

  group('firestoreDataToJson', () {
    test('Timestamp は ISO-8601 文字列になり、他の値はそのまま', () {
      final json = firestoreDataToJson({
        'createdAt': Timestamp.fromDate(created),
        'theme': 'Checkmate patterns',
        'count': 7,
        'puzzleIds': ['a', 'b'],
      });

      expect(json['createdAt'], isA<String>());
      expect(DateTime.parse(json['createdAt'] as String).toUtc(), created);
      expect(json['theme'], 'Checkmate patterns');
      expect(json['count'], 7);
      expect(json['puzzleIds'], ['a', 'b']);
    });

    test('入れ子の Map と List の中の Timestamp も変換する', () {
      final json = firestoreDataToJson({
        'meta': {'at': Timestamp.fromDate(created)},
        'history': [Timestamp.fromDate(created), 'x'],
      });

      expect((json['meta'] as Map)['at'], isA<String>());
      expect((json['history'] as List).first, isA<String>());
      expect((json['history'] as List).last, 'x');
    });
  });

  group('Firestore のデータをモデルに読む(実機で起きた失敗の再現)', () {
    final raw = <String, dynamic>{
      'theme': 'Checkmate patterns',
      'puzzleIds': ['p1', 'p2'],
      'createdAt': Timestamp.fromDate(created),
    };

    test('変換しないと「Timestamp は String ではない」で失敗する', () {
      expect(
        () => DailyChallengeModel.fromJson({...raw, 'date': '2026-10-30'}),
        throwsA(isA<TypeError>()),
      );
    });

    test('変換すれば DailyChallengeModel として読める', () {
      final model = DailyChallengeModel.fromJson({
        ...firestoreDataToJson(raw),
        'date': '2026-10-30',
      });

      expect(model.date, '2026-10-30');
      expect(model.puzzleIds, ['p1', 'p2']);
      expect(model.createdAt!.toUtc(), created);
    });

    test('変換すれば PuzzleModel として読める', () {
      final model = PuzzleModel.fromJson({
        ...firestoreDataToJson({
          'fen': '7k/Q7/6K1/8/8/8/8/8 w - - 0 1',
          'moves': ['a7g7'],
          'rating': 350,
          'themes': ['checkmate'],
          'createdAt': Timestamp.fromDate(created),
        }),
        'id': 'mate1',
      });

      expect(model.id, 'mate1');
      expect(model.createdAt!.toUtc(), created);
    });
  });
}
