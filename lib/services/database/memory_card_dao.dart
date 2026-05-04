import 'package:uuid/uuid.dart';
import '../../models/memory_card.dart';
import 'database_service.dart';

class MemoryCardDao {
  final DatabaseService _db;
  const MemoryCardDao(this._db);
  static const _uuid = Uuid();

  Future<List<MemoryCard>> getActiveByContact(String contactId) async {
    final db = await _db.database;
    final rows = await db.query(
      'memory_cards',
      where: 'contact_id = ? AND status = ?',
      whereArgs: [contactId, 'active'],
      orderBy: 'importance DESC, confidence DESC',
    );
    return rows.map(MemoryCard.fromDbMap).toList();
  }

  Future<List<MemoryCard>> searchByKeywords(
    String contactId,
    List<String> keywords,
  ) async {
    if (keywords.isEmpty) return [];
    final db = await _db.database;
    final conditions = keywords
        .map((_) => '(content LIKE ? OR tags LIKE ?)')
        .join(' OR ');
    final args = <dynamic>[contactId, 'active'];
    for (final kw in keywords) {
      args.addAll(['%$kw%', '%$kw%']);
    }
    final rows = await db.query(
      'memory_cards',
      where: 'contact_id = ? AND status = ? AND ($conditions)',
      whereArgs: args,
      orderBy: 'importance DESC, confidence DESC',
    );
    return rows.map(MemoryCard.fromDbMap).toList();
  }

  Future<void> insert(MemoryCard card) async {
    final db = await _db.database;
    final id = card.id.isEmpty ? _uuid.v4() : card.id;
    await db.insert('memory_cards', card.copyWith(id: id).toDbMap());
  }

  Future<void> update(MemoryCard card) async {
    final db = await _db.database;
    await db.update(
      'memory_cards',
      card.toDbMap(),
      where: 'id = ?',
      whereArgs: [card.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await _db.database;
    await db.delete('memory_cards', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> countByContact(String contactId) async {
    final db = await _db.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM memory_cards WHERE contact_id = ? AND status = ?',
      [contactId, 'active'],
    );
    if (result.isEmpty) return 0;
    return (result.first['cnt'] as num?)?.toInt() ?? 0;
  }
}
