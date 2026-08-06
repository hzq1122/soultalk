import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../models/moment.dart';
import 'database_service.dart';

class MomentDao {
  final DatabaseService _db;
  final _uuid = const Uuid();

  MomentDao(this._db);

  Future<Database> get _database => _db.database;

  Map<String, dynamic> _toMap(Moment moment) => {
    'id': moment.id,
    'contact_id': moment.contactId,
    'content': moment.content,
    'image_url': moment.imageUrl,
    'likes': jsonEncode(moment.likes),
    'comments': jsonEncode(moment.comments.map((c) => c.toJson()).toList()),
    'created_at': moment.createdAt?.toIso8601String(),
  };

  /// 原地修改（内容/点赞/评论）必须刷新 updated_at，
  /// 供自动备份指纹与 LanSync 增量水位检测。
  static Map<String, dynamic> _touch() => {
    'updated_at': DateTime.now().toIso8601String(),
  };

  Moment _fromMap(Map<String, dynamic> map) => Moment(
    id: map['id'] as String,
    contactId: map['contact_id'] as String,
    content: map['content'] as String,
    imageUrl: map['image_url'] as String?,
    likes: List<String>.from(
      jsonDecode(map['likes'] as String? ?? '[]') as List,
    ),
    comments: (jsonDecode(map['comments'] as String? ?? '[]') as List)
        .map((c) => MomentComment.fromJson(c as Map<String, dynamic>))
        .toList(),
    createdAt: map['created_at'] != null
        ? DateTime.tryParse(map['created_at'] as String)
        : null,
  );

  Future<List<Moment>> getAll({int? limit, int? offset}) async {
    final db = await _database;
    final rows = await db.query(
      'moments',
      orderBy: 'created_at DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(_fromMap).toList();
  }

  Future<List<Moment>> getByContact(String contactId) async {
    final db = await _database;
    final rows = await db.query(
      'moments',
      where: 'contact_id = ?',
      whereArgs: [contactId],
      orderBy: 'created_at DESC',
    );
    return rows.map(_fromMap).toList();
  }

  /// 统计某联系人当天（自然日）发布的朋友圈数量，用于每日次数限制。
  Future<int> countCreatedToday(String contactId) async {
    final db = await _database;
    final now = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day).toIso8601String();
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM moments '
      'WHERE contact_id = ? AND created_at >= ?',
      [contactId, dayStart],
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  Future<Moment> insert(Moment moment) async {
    final db = await _database;
    final newMoment = Moment(
      id: moment.id.isEmpty ? _uuid.v4() : moment.id,
      contactId: moment.contactId,
      content: moment.content,
      imageUrl: moment.imageUrl,
      likes: moment.likes,
      comments: moment.comments,
      createdAt: moment.createdAt ?? DateTime.now(),
    );
    await db.insert('moments', {
      ..._toMap(newMoment),
      'updated_at': newMoment.createdAt!.toIso8601String(),
    });
    return newMoment;
  }

  Future<void> update(Moment moment) async {
    final db = await _database;
    await db.update(
      'moments',
      {..._toMap(moment), ..._touch()},
      where: 'id = ?',
      whereArgs: [moment.id],
    );
  }

  Future<void> addLike(String momentId, String userId) async {
    final db = await _database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'moments',
        where: 'id = ?',
        whereArgs: [momentId],
      );
      if (rows.isEmpty) return;
      final moment = _fromMap(rows.first);
      if (moment.likes.contains(userId)) return;
      final newLikes = [...moment.likes, userId];
      await txn.update(
        'moments',
        {'likes': jsonEncode(newLikes), ..._touch()},
        where: 'id = ?',
        whereArgs: [momentId],
      );
    });
  }

  Future<void> removeLike(String momentId, String userId) async {
    final db = await _database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'moments',
        where: 'id = ?',
        whereArgs: [momentId],
      );
      if (rows.isEmpty) return;
      final moment = _fromMap(rows.first);
      final newLikes = moment.likes.where((l) => l != userId).toList();
      await txn.update(
        'moments',
        {'likes': jsonEncode(newLikes), ..._touch()},
        where: 'id = ?',
        whereArgs: [momentId],
      );
    });
  }

  Future<void> addComment(String momentId, MomentComment comment) async {
    final db = await _database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'moments',
        where: 'id = ?',
        whereArgs: [momentId],
      );
      if (rows.isEmpty) return;
      final moment = _fromMap(rows.first);
      final newComments = [...moment.comments, comment];
      await txn.update(
        'moments',
        {
          'comments': jsonEncode(newComments.map((c) => c.toJson()).toList()),
          ..._touch(),
        },
        where: 'id = ?',
        whereArgs: [momentId],
      );
    });
  }

  Future<void> delete(String id) async {
    final db = await _database;
    await db.delete('moments', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteByContact(String contactId) async {
    final db = await _database;
    await db.delete('moments', where: 'contact_id = ?', whereArgs: [contactId]);
  }
}
