import 'package:sqflite/sqflite.dart';
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
    final id = entry.id.isEmpty ? _uuid.v4() : entry.id;
    try {
      // 依赖 (contact_id, category, key) 唯一索引，原子 UPSERT 防并发重复
      await db.rawInsert(
        '''INSERT INTO memory_entries (id, contact_id, category, key, value, updated_at)
        VALUES (?, ?, ?, ?, ?, ?)
        ON CONFLICT(contact_id, category, key) DO UPDATE SET
          value = excluded.value,
          updated_at = excluded.updated_at''',
        [
          id,
          entry.contactId,
          entry.category,
          entry.key,
          entry.value,
          entry.updatedAt.toIso8601String(),
        ],
      );
    } on DatabaseException {
      // 兜底：唯一索引不存在（未迁移的旧库）时回退到 check-then-act
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
        await db.insert('memory_entries', entry.copyWith(id: id).toDbMap());
      }
    }
  }

  Future<void> upsertAll(List<MemoryEntry> entries) async {
    for (final entry in entries) {
      await upsert(entry);
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
