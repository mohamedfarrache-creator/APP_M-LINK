import 'package:sqflite/sqflite.dart';

import '../models/project_calendar.dart';
import 'local_db.dart';

class LocalCalendarStore {
  LocalCalendarStore({LocalDb? db}) : _db = db ?? LocalDb.instance;

  final LocalDb _db;

  Future<List<ProjectCalendar>> fetchAll() async {
    final database = await _db.database;
    final rows = await database.query('project_calendars');
    return rows.map(ProjectCalendar.fromDb).toList();
  }

  Future<void> saveAll(List<ProjectCalendar> calendars) async {
    final database = await _db.database;
    final batch = database.batch();
    for (final calendar in calendars) {
      batch.insert(
        'project_calendars',
        calendar.toDb(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }
}
