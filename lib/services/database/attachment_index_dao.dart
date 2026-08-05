import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'database_service.dart';

class AttachmentIndexRecord {
  final String id;
  final String chatId;
  final String? messageId;
  final String originalName;
  final String? mimeType;
  final String relativePath;
  final String sha256;
  final int size;
  final int createdAt;

  const AttachmentIndexRecord({
    required this.id,
    required this.chatId,
    required this.messageId,
    required this.originalName,
    required this.mimeType,
    required this.relativePath,
    required this.sha256,
    required this.size,
    required this.createdAt,
  });

  Map<String, Object?> toMap() => {
    'id': id,
    'chat_id': chatId,
    'message_id': messageId,
    'original_name': originalName,
    'mime_type': mimeType,
    'relative_path': relativePath,
    'sha256': sha256,
    'size': size,
    'created_at': createdAt,
  };

  factory AttachmentIndexRecord.fromMap(Map<String, Object?> map) {
    return AttachmentIndexRecord(
      id: map['id']! as String,
      chatId: map['chat_id']! as String,
      messageId: map['message_id'] as String?,
      originalName: map['original_name']! as String,
      mimeType: map['mime_type'] as String?,
      relativePath: map['relative_path']! as String,
      sha256: map['sha256']! as String,
      size: map['size']! as int,
      createdAt: map['created_at']! as int,
    );
  }
}

class AttachmentIndexDao {
  final DatabaseService _db;

  AttachmentIndexDao(this._db);

  Future<Database> get _database => _db.database;

  Future<void> upsert(AttachmentIndexRecord record) async {
    final db = await _database;
    await db.insert(
      'attachment_index',
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<AttachmentIndexRecord?> getById(String id) async {
    final db = await _database;
    final rows = await db.query(
      'attachment_index',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return AttachmentIndexRecord.fromMap(rows.first);
  }

  Future<void> updateMessageId(String id, String messageId) async {
    final db = await _database;
    await db.update(
      'attachment_index',
      {'message_id': messageId},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteById(String id) async {
    final db = await _database;
    await db.delete('attachment_index', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<AttachmentIndexRecord>> getByMessageId(String messageId) async {
    final db = await _database;
    final rows = await db.query(
      'attachment_index',
      where: 'message_id = ?',
      whereArgs: [messageId],
    );
    return rows.map(AttachmentIndexRecord.fromMap).toList();
  }

  Future<AttachmentIndexRecord?> getByRelativePath(String relativePath) async {
    final db = await _database;
    final rows = await db.query(
      'attachment_index',
      where: 'relative_path = ?',
      whereArgs: [relativePath],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return AttachmentIndexRecord.fromMap(rows.first);
  }

  Future<List<AttachmentIndexRecord>> getByChatId(String chatId) async {
    final db = await _database;
    final rows = await db.query(
      'attachment_index',
      where: 'chat_id = ?',
      whereArgs: [chatId],
    );
    return rows.map(AttachmentIndexRecord.fromMap).toList();
  }

  /// 以文件系统为权威源重建附件索引（备份恢复后调用）。
  /// 文件名约定：`{uuid}-{originalName}`，uuid 固定 36 字符。
  /// 重建会清空旧索引（message_id 关联无法从文件恢复，由消息 metadata 承载）。
  Future<int> rebuildFromDirectory(Directory root) async {
    final db = await _database;
    var count = 0;
    await db.transaction((txn) async {
      await txn.delete('attachment_index');
      if (!await root.exists()) return;
      await for (final entity in root.list()) {
        if (entity is! Directory) continue;
        final chatId = p.basename(entity.path);
        await for (final file in entity.list()) {
          if (file is! File) continue;
          final name = p.basename(file.path);
          if (name.length <= 37 || name[36] != '-') continue;
          final id = name.substring(0, 36);
          final originalName = name.substring(37);
          final digest = await sha256.bind(file.openRead()).first;
          final stat = await file.stat();
          await txn.insert('attachment_index', {
            'id': id,
            'chat_id': chatId,
            'message_id': null,
            'original_name': originalName,
            'mime_type': null,
            'relative_path': 'soultalk/attachments/$chatId/$name',
            'sha256': digest.toString(),
            'size': stat.size,
            'created_at': stat.modified.millisecondsSinceEpoch,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
          count++;
        }
      }
    });
    return count;
  }
}
