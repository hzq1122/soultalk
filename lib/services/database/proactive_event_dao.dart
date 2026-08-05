import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'database_service.dart';

/// 主动消息事件日志。
class ProactiveEvent {
  final String id;
  final String contactId;
  final String? ruleId;
  final String eventType; // check / sent / skipped / failed
  final String status;
  final String? payload;
  final int createdAt;

  const ProactiveEvent({
    required this.id,
    required this.contactId,
    required this.ruleId,
    required this.eventType,
    required this.status,
    required this.payload,
    required this.createdAt,
  });

  Map<String, Object?> toMap() => {
    'id': id,
    'contact_id': contactId,
    'rule_id': ruleId,
    'event_type': eventType,
    'status': status,
    'payload': payload,
    'created_at': createdAt,
  };

  factory ProactiveEvent.fromMap(Map<String, Object?> map) => ProactiveEvent(
    id: map['id']! as String,
    contactId: map['contact_id']! as String,
    ruleId: map['rule_id'] as String?,
    eventType: map['event_type'] as String? ?? 'check',
    status: map['status'] as String? ?? 'pending',
    payload: map['payload'] as String?,
    createdAt: map['created_at'] as int? ?? 0,
  );
}

class ProactiveEventDao {
  final DatabaseService _db;
  final Uuid _uuid = const Uuid();

  ProactiveEventDao(this._db);

  Future<Database> get _database => _db.database;

  Future<ProactiveEvent> record({
    required String contactId,
    String? ruleId,
    required String eventType,
    required String status,
    String? payload,
  }) async {
    final db = await _database;
    final event = ProactiveEvent(
      id: _uuid.v4(),
      contactId: contactId,
      ruleId: ruleId,
      eventType: eventType,
      status: status,
      payload: payload,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    await db.insert('proactive_events', event.toMap());
    return event;
  }

  Future<List<ProactiveEvent>> recent({
    String? contactId,
    int limit = 50,
  }) async {
    final db = await _database;
    final rows = await db.query(
      'proactive_events',
      where: contactId == null ? null : 'contact_id = ?',
      whereArgs: contactId == null ? null : [contactId],
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map(ProactiveEvent.fromMap).toList();
  }

  /// 统计某联系人当天（自然日）发送成功的次数，用于每日次数限制。
  Future<int> countSentToday(String contactId, {String eventType = 'sent'}) async {
    final db = await _database;
    final now = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day)
        .millisecondsSinceEpoch;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM proactive_events '
      'WHERE contact_id = ? AND event_type = ? AND created_at >= ?',
      [contactId, eventType, dayStart],
    );
    return (rows.first['c'] as int?) ?? 0;
  }
}
