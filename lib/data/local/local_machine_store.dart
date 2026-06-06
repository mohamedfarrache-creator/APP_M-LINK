import 'package:sqflite/sqflite.dart';

import '../models/machine.dart';
import 'local_db.dart';

class LocalMachineStore {
  LocalMachineStore({LocalDb? db}) : _db = db ?? LocalDb.instance;

  final LocalDb _db;

  Future<List<Machine>> fetchAll() async {
    final database = await _db.database;
    final rows = await database.query('machines');
    return rows.map(Machine.fromDb).toList();
  }

  Future<void> saveAll(List<Machine> machines) async {
    final database = await _db.database;
    final batch = database.batch();
    for (final machine in machines) {
      batch.insert(
        'machines',
        machine.toDb(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> updateMachine(Machine machine) async {
    final database = await _db.database;
    await database.update(
      'machines',
      machine.toDb(),
      where: 'id = ?',
      whereArgs: <Object?>[machine.id],
    );
  }
}
