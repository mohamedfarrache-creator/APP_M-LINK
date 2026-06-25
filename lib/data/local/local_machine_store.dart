import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../models/machine.dart';
import 'local_db.dart';

class LocalMachineStore {
  LocalMachineStore({LocalDb? db}) : _db = db ?? LocalDb.instance;

  static List<Machine>? _webCache;

  final LocalDb _db;

  Future<List<Machine>> fetchAll() async {
    if (kIsWeb) {
      return List<Machine>.from(_webCache ?? const <Machine>[]);
    }

    final database = await _db.database;
    final rows = await database.query('machines');
    return rows.map(Machine.fromDb).toList();
  }

  Future<void> saveAll(List<Machine> machines) async {
    if (kIsWeb) {
      _webCache = List<Machine>.from(machines);
      return;
    }

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
    if (kIsWeb) {
      final cache = List<Machine>.from(_webCache ?? const <Machine>[]);
      final index = cache.indexWhere((item) => item.id == machine.id);
      if (index >= 0) {
        cache[index] = machine;
      } else {
        cache.add(machine);
      }
      _webCache = cache;
      return;
    }

    final database = await _db.database;
    await database.update(
      'machines',
      machine.toDb(),
      where: 'id = ?',
      whereArgs: <Object?>[machine.id],
    );
  }
}
