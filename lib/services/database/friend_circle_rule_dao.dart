import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'database_service.dart';

/// 朋友圈发布规则（每联系人一条）。
class FriendCircleRule {
  final String id;
  final String contactId;
  final bool enabled;
  final int intervalHours;
  final DateTime? lastPostedAt;
  final int createdAt;
  final int updatedAt;

  const FriendCircleRule({
    required this.id,
    required this.contactId,
    required this.enabled,
    required this.intervalHours,
    required this.lastPostedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, Object?> toMap() => {
    'id': id,
    'contact_id': contactId,
    'enabled': enabled ? 1 : 0,
    'interval_hours': intervalHours,
    'last_posted_at': lastPostedAt?.toIso8601String(),
    'created_at': createdAt,
    'updated_at': updatedAt,
  };

  factory FriendCircleRule.fromMap(Map<String, Object?> map) =>
      FriendCircleRule(
        id: map['id']! as String,
        contactId: map['contact_id']! as String,
        enabled: (map['enabled'] as int? ?? 1) == 1,
        intervalHours: map['interval_hours'] as int? ?? 24,
        lastPostedAt: map['last_posted_at'] != null
            ? DateTime.tryParse(map['last_posted_at'] as String)
            : null,
        createdAt: map['created_at'] as int? ?? 0,
        updatedAt: map['updated_at'] as int? ?? 0,
      );
}

class FriendCircleRuleDao {
  final DatabaseService _db;
  final Uuid _uuid = const Uuid();

  FriendCircleRuleDao(this._db);

  Future<Database> get _database => _db.database;

  /// 按联系人 upsert 规则。
  Future<FriendCircleRule> upsertForContact(
    String contactId, {
    bool? enabled,
    int? intervalHours,
  }) async {
    final db = await _database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await getByContact(contactId);
    final rule = FriendCircleRule(
      id: existing?.id ?? _uuid.v4(),
      contactId: contactId,
      enabled: enabled ?? existing?.enabled ?? true,
      intervalHours: intervalHours ?? existing?.intervalHours ?? 24,
      lastPostedAt: existing?.lastPostedAt,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    await db.insert(
      'friend_circle_rules',
      rule.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return rule;
  }

  Future<FriendCircleRule?> getByContact(String contactId) async {
    final db = await _database;
    final rows = await db.query(
      'friend_circle_rules',
      where: 'contact_id = ?',
      whereArgs: [contactId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return FriendCircleRule.fromMap(rows.first);
  }

  Future<List<FriendCircleRule>> getAllEnabled() async {
    final db = await _database;
    final rows = await db.query(
      'friend_circle_rules',
      where: 'enabled = ?',
      whereArgs: [1],
      orderBy: 'updated_at ASC',
    );
    return rows.map(FriendCircleRule.fromMap).toList();
  }

  Future<void> updatePostedAt(String contactId, DateTime at) async {
    final db = await _database;
    await db.update(
      'friend_circle_rules',
      {
        'last_posted_at': at.toIso8601String(),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'contact_id = ?',
      whereArgs: [contactId],
    );
  }
}
