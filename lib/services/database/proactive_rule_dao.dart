import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'database_service.dart';

/// 主动消息规则（每联系人一条）。
class ProactiveRule {
  final String id;
  final String contactId;
  final bool enabled;
  final int minHours;
  final double probability;
  final DateTime? lastTriggeredAt;
  final int createdAt;
  final int updatedAt;

  const ProactiveRule({
    required this.id,
    required this.contactId,
    required this.enabled,
    required this.minHours,
    required this.probability,
    required this.lastTriggeredAt,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, Object?> toMap() => {
    'id': id,
    'contact_id': contactId,
    'enabled': enabled ? 1 : 0,
    'min_hours': minHours,
    'probability': probability,
    'last_triggered_at': lastTriggeredAt?.toIso8601String(),
    'created_at': createdAt,
    'updated_at': updatedAt,
  };

  factory ProactiveRule.fromMap(Map<String, Object?> map) => ProactiveRule(
    id: map['id']! as String,
    contactId: map['contact_id']! as String,
    enabled: (map['enabled'] as int? ?? 1) == 1,
    minHours: map['min_hours'] as int? ?? 2,
    probability: (map['probability'] as num? ?? 0.3).toDouble(),
    lastTriggeredAt: map['last_triggered_at'] != null
        ? DateTime.tryParse(map['last_triggered_at'] as String)
        : null,
    createdAt: map['created_at'] as int? ?? 0,
    updatedAt: map['updated_at'] as int? ?? 0,
  );
}

class ProactiveRuleDao {
  final DatabaseService _db;
  final Uuid _uuid = const Uuid();

  ProactiveRuleDao(this._db);

  Future<Database> get _database => _db.database;

  /// 按联系人 upsert 规则（默认参数来自旧 contacts 字段语义）。
  Future<ProactiveRule> upsertForContact(
    String contactId, {
    bool? enabled,
    int? minHours,
    double? probability,
  }) async {
    final db = await _database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await getByContact(contactId);
    final rule = ProactiveRule(
      id: existing?.id ?? _uuid.v4(),
      contactId: contactId,
      enabled: enabled ?? existing?.enabled ?? true,
      minHours: minHours ?? existing?.minHours ?? 2,
      probability: probability ?? existing?.probability ?? 0.3,
      lastTriggeredAt: existing?.lastTriggeredAt,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    await db.insert(
      'proactive_rules',
      rule.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return rule;
  }

  Future<ProactiveRule?> getByContact(String contactId) async {
    final db = await _database;
    final rows = await db.query(
      'proactive_rules',
      where: 'contact_id = ?',
      whereArgs: [contactId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ProactiveRule.fromMap(rows.first);
  }

  Future<List<ProactiveRule>> getAllEnabled() async {
    final db = await _database;
    final rows = await db.query(
      'proactive_rules',
      where: 'enabled = ?',
      whereArgs: [1],
      orderBy: 'updated_at ASC',
    );
    return rows.map(ProactiveRule.fromMap).toList();
  }

  Future<void> updateTriggeredAt(String contactId, DateTime at) async {
    final db = await _database;
    await db.update(
      'proactive_rules',
      {
        'last_triggered_at': at.toIso8601String(),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'contact_id = ?',
      whereArgs: [contactId],
    );
  }
}
