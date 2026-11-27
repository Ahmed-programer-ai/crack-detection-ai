import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/analysis_result.dart';

class LocalStorageService {
  Database? _database;

  Future<void> initialize() async {
    if (_database != null) return;
    final directory = await getApplicationDocumentsDirectory();
    _database = await openDatabase(
      p.join(directory.path, 'crackai_history.db'),
      version: 1,
      onCreate: (database, version) async {
        await database.execute('''
          CREATE TABLE analyses (
            id TEXT PRIMARY KEY,
            created_at TEXT NOT NULL,
            status TEXT NOT NULL,
            confidence REAL NOT NULL,
            severity TEXT,
            width_mm REAL,
            original_image BLOB NOT NULL,
            segmentation_image BLOB,
            recommendations TEXT NOT NULL,
            warnings TEXT NOT NULL,
            measurements TEXT NOT NULL
          )
        ''');
        await database.execute(
          'CREATE INDEX analyses_created_at ON analyses(created_at DESC)',
        );
      },
    );
  }

  Future<void> save(AnalysisResult result) async {
    final database = _requireDatabase();
    await database.insert(
      'analyses',
      result.toDatabaseMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<List<AnalysisSummary>> getHistory() async {
    final rows = await _requireDatabase().query(
      'analyses',
      columns: ['id', 'created_at', 'status', 'confidence', 'severity'],
      orderBy: 'created_at DESC',
    );
    return rows.map(AnalysisSummary.fromDatabaseMap).toList(growable: false);
  }

  Future<AnalysisResult?> getAnalysis(String id) async {
    final rows = await _requireDatabase().query(
      'analyses',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : AnalysisResult.fromDatabaseMap(rows.single);
  }

  Future<void> delete(String id) async {
    await _requireDatabase().delete(
      'analyses',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Database _requireDatabase() {
    final database = _database;
    if (database == null) {
      throw StateError('Local analysis history is not initialized.');
    }
    return database;
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
