import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

// Phase M: オフラインモード & モバイル最適化
class OfflineService {
  factory OfflineService() => _instance;
  OfflineService._internal();
  static final OfflineService _instance = OfflineService._internal();
  late Database _db;

  Future<void> initialize() async {
    final dbPath = await getDatabasesPath();
    _db = await openDatabase(join(dbPath, 'chess_tactics.db'));
    await _createTables();
  }

  Future<void> _createTables() async {
    await _db.execute(
        'CREATE TABLE IF NOT EXISTS puzzles(id TEXT PRIMARY KEY, pgn TEXT, difficulty TEXT)');
    await _db.execute(
        'CREATE TABLE IF NOT EXISTS lessons(id TEXT PRIMARY KEY, title TEXT, content TEXT)');
    await _db.execute(
        'CREATE TABLE IF NOT EXISTS games(id TEXT PRIMARY KEY, pgn TEXT, result TEXT)');
  }

  Future<void> cachePuzzles(List<Map<String, dynamic>> puzzles) async {
    for (final puzzle in puzzles) {
      await _db.insert('puzzles', puzzle,
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<List<Map<String, dynamic>>> getCachedPuzzles() async =>
      _db.query('puzzles');

  Future<void> saveLessonOffline(
      String lessonId, String title, String content) async {
    await _db.insert(
        'lessons', {'id': lessonId, 'title': title, 'content': content},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> close() => _db.close();
}
