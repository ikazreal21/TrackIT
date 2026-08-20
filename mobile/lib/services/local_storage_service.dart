import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/health_data.dart';

/// Persists fetched health records locally so they survive app restarts.
class LocalStorageService {
  static Database? _db;

  Future<Database> get _database async {
    _db ??= await _init();
    return _db!;
  }

  Future<Database> _init() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'health_records.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE records (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT NOT NULL,
            value REAL NOT NULL,
            unit TEXT NOT NULL,
            date_from TEXT NOT NULL,
            date_to TEXT NOT NULL,
            UNIQUE(type, date_from, date_to)
          )
        ''');
        await db.execute(
            'CREATE INDEX idx_records_type ON records(type)');
        await db.execute(
            'CREATE INDEX idx_records_date_from ON records(date_from)');
      },
    );
  }

  Future<List<HealthRecord>> loadRecords() async {
    final db = await _database;
    final rows = await db.query(
      'records',
      orderBy: 'date_from DESC',
    );
    return rows.map((r) => HealthRecord(
      type: r['type'] as String,
      value: r['value'] as num,
      unit: r['unit'] as String,
      dateFrom: DateTime.parse(r['date_from'] as String),
      dateTo: DateTime.parse(r['date_to'] as String),
    )).toList();
  }

  Future<void> saveRecords(List<HealthRecord> records) async {
    final db = await _database;
    await db.transaction((txn) async {
      for (final r in records) {
        await txn.insert(
          'records',
          {
            'type': r.type,
            'value': r.value,
            'unit': r.unit,
            'date_from': r.dateFrom.toUtc().toIso8601String(),
            'date_to': r.dateTo.toUtc().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
  }

  Future<void> clear() async {
    final db = await _database;
    await db.delete('records');
  }
}
