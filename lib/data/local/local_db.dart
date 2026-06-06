import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class LocalDb {
  LocalDb._();

  static final LocalDb instance = LocalDb._();
  Database? _db;

  Future<Database> get database async {
    final existing = _db;
    if (existing != null) {
      return existing;
    }

    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'm_link_local.db');
    final db = await openDatabase(
      path,
      version: 1,
      onCreate: (database, _) async {
        await database.execute(
          'CREATE TABLE machines('
          'id TEXT PRIMARY KEY,'
          'name TEXT,'
          'serial TEXT,'
          'project TEXT,'
          'site TEXT,'
          'zone TEXT,'
          'mapX REAL,'
          'mapY REAL,'
          'status TEXT,'
          'nextKw INTEGER,'
          'machineType TEXT,'
          'drsNumbers TEXT,'
          'checklist TEXT'
          ')',
        );

        await database.execute(
          'CREATE TABLE project_calendars('
          'project TEXT PRIMARY KEY,'
          'sourceFile TEXT,'
          'machineType TEXT,'
          'drsNumbers TEXT'
          ')',
        );
      },
    );

    _db = db;
    return db;
  }
}
