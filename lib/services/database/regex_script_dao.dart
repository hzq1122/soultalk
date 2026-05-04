import 'package:uuid/uuid.dart';
import '../../models/regex_script.dart';
import 'database_service.dart';

class RegexScriptDao {
  final DatabaseService _db;
  const RegexScriptDao(this._db);
  static const _uuid = Uuid();

  Future<List<RegexScript>> getAll() async {
    final db = await _db.database;
    final rows = await db.query('regex_scripts', orderBy: 'script_name ASC');
    return rows.map(RegexScript.fromDbMap).toList();
  }

  Future<List<RegexScript>> getEnabled() async {
    final db = await _db.database;
    final rows = await db.query(
      'regex_scripts',
      where: 'disabled = 0',
      orderBy: 'script_name ASC',
    );
    return rows.map(RegexScript.fromDbMap).toList();
  }

  Future<RegexScript> insert(RegexScript script) async {
    final db = await _db.database;
    final id = script.id.isEmpty ? _uuid.v4() : script.id;
    final row = script.copyWith(id: id).toDbMap();
    await db.insert('regex_scripts', row);
    return RegexScript.fromDbMap(row);
  }

  Future<void> insertAll(List<RegexScript> scripts) async {
    final db = await _db.database;
    final batch = db.batch();
    for (final script in scripts) {
      final id = script.id.isEmpty ? _uuid.v4() : script.id;
      batch.insert('regex_scripts', script.copyWith(id: id).toDbMap());
    }
    await batch.commit(noResult: true);
  }

  Future<void> update(RegexScript script) async {
    final db = await _db.database;
    await db.update(
      'regex_scripts',
      script.toDbMap(),
      where: 'id = ?',
      whereArgs: [script.id],
    );
  }

  Future<void> toggleDisabled(String id) async {
    final db = await _db.database;
    await db.rawUpdate(
      'UPDATE regex_scripts SET disabled = CASE WHEN disabled = 0 THEN 1 ELSE 0 END WHERE id = ?',
      [id],
    );
  }

  Future<void> delete(String id) async {
    final db = await _db.database;
    await db.delete('regex_scripts', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteAll() async {
    final db = await _db.database;
    await db.delete('regex_scripts');
  }
}
