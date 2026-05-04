import 'package:uuid/uuid.dart';
import '../../models/memory_state.dart';
import 'database_service.dart';

class MemoryStateDao {
  final DatabaseService _db;
  const MemoryStateDao(this._db);
  static const _uuid = Uuid();

  Future<List<MemoryState>> getByContact(String contactId) async {
    final db = await _db.database;
    final rows = await db.query(
      'memory_states',
      where: 'contact_id = ? AND status = ?',
      whereArgs: [contactId, 'active'],
      orderBy: 'slot_name ASC',
    );
    return rows.map(MemoryState.fromDbMap).toList();
  }

  Future<void> upsert(MemoryState state) async {
    final db = await _db.database;
    final existing = await db.query(
      'memory_states',
      where: 'contact_id = ? AND slot_name = ?',
      whereArgs: [state.contactId, state.slotName],
    );
    if (existing.isNotEmpty) {
      await db.update(
        'memory_states',
        {
          'slot_value': state.slotValue,
          'confidence': state.confidence,
          'status': state.status,
          'updated_at': state.updatedAt.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    } else {
      final id = state.id.isEmpty ? _uuid.v4() : state.id;
      await db.insert('memory_states', state.copyWith(id: id).toDbMap());
    }
  }

  Future<void> upsertAll(List<MemoryState> states) async {
    for (final state in states) {
      await upsert(state);
    }
  }

  Future<void> markStale(String contactId) async {
    final db = await _db.database;
    await db.update(
      'memory_states',
      {'status': 'stale'},
      where: 'contact_id = ?',
      whereArgs: [contactId],
    );
  }

  Future<void> delete(String id) async {
    final db = await _db.database;
    await db.delete('memory_states', where: 'id = ?', whereArgs: [id]);
  }
}
