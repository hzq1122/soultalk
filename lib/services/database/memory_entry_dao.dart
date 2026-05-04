import 'package:uuid/uuid.dart';
import '../../models/memory_entry.dart';
import 'database_service.dart';

class MemoryEntryDao {
  final DatabaseService _db;
  const MemoryEntryDao(this._db);
  static const _uuid = Uuid();

  Future<List<MemoryEntry>> getByContact(String contactId) async {
    final db = await _db.database;
    final rows = await db.query(
      'memory_entries',
      where: 'contact_id = ?',
      whereArgs: [contactId],
      orderBy: 'category ASC, key ASC',
    );
    return rows.map(MemoryEntry.fromDbMap).toList();
  }

  Future<void> upsert(MemoryEntry entry) async {
    final db = await _db.database;
    final existing = await db.query(
      'memory_entries',
      where: 'contact_id = ? AND category = ? AND key = ?',
      whereArgs: [entry.contactId, entry.category, entry.key],
    );
    if (existing.isNotEmpty) {
      await db.update(
        'memory_entries',
        {'value': entry.value, 'updated_at': entry.updatedAt.toIso8601String()},
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    } else {
      final id = entry.id.isEmpty ? _uuid.v4() : entry.id;
      await db.insert('memory_entries', entry.copyWith(id: id).toDbMap());
    }
  }

  Future<void> upsertAll(List<MemoryEntry> entries) async {
    final db = await _db.database;
    for (final entry in entries) {
      final existing = await db.query(
        'memory_entries',
        where: 'contact_id = ? AND category = ? AND key = ?',
        whereArgs: [entry.contactId, entry.category, entry.key],
      );
      if (existing.isNotEmpty) {
        await db.update(
          'memory_entries',
          {
            'value': entry.value,
            'updated_at': entry.updatedAt.toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [existing.first['id']],
        );
      } else {
        final id = entry.id.isEmpty ? _uuid.v4() : entry.id;
        await db.insert('memory_entries', entry.copyWith(id: id).toDbMap());
      }
    }
  }

  Future<void> delete(String id) async {
    final db = await _db.database;
    await db.delete('memory_entries', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteByContact(String contactId) async {
    final db = await _db.database;
    await db.delete(
      'memory_entries',
      where: 'contact_id = ?',
      whereArgs: [contactId],
    );
  }
}
