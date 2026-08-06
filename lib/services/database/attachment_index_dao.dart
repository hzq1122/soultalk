import 'dart:convert';
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
  /// 重建会清空旧索引，并从 messages 表 metadata 恢复 message_id /
  /// mime_type / relative_path 关联（消息行不随附件索引删除）。
  Future<int> rebuildFromDirectory(Directory root) async {
    final db = await _database;
    // 收集消息 metadata 中的附件信息：id → (messageId, mime, relativePath)
    final attachmentRefs =
        <String, ({String messageId, String? mime, String? relativePath})>{};
    try {
      final messageRows = await db.query(
        'messages',
        columns: ['id', 'metadata'],
      );
      for (final row in messageRows) {
        final messageId = row['id'] as String?;
        final metadataJson = row['metadata'] as String?;
        if (messageId == null || metadataJson == null) continue;
        final metadata = jsonDecode(metadataJson) as Map<String, dynamic>?;
        final attachment = metadata?['attachment'];
        if (attachment is! Map) continue;
        final id = attachment['id'];
        if (id is! String || id.isEmpty) continue;
        attachmentRefs[id] = (
          messageId: messageId,
          mime: attachment['mime'] as String?,
          relativePath: attachment['relative_path'] as String?,
        );
      }
    } catch (_) {
      // metadata 解析失败不影响重建（message_id/mime 恢复是尽力而为）
    }
    var count = 0;
    await db.transaction((txn) async {
      await txn.delete('attachment_index');
      if (!await root.exists()) return;
      // 递归扫描：目录结构 {root}/{chatId}/[.../{uuid}-{name}]，
      // chatId 为相对 root 的第一层目录名
      await for (final entity in root.list(recursive: true)) {
        if (entity is! File) continue;
        final rel = p
            .relative(entity.path, from: root.path)
            .split(p.separator)
            .join('/');
        final segments = rel.split('/');
        if (segments.length < 2) continue;
        final chatId = segments.first;
        final name = segments.last;
        if (name.length <= 37 || name[36] != '-') continue;
        final id = name.substring(0, 36);
        final originalName = name.substring(37);
        final digest = await sha256.bind(entity.openRead()).first;
        final stat = await entity.stat();
        final ref = attachmentRefs[id];
        final relativePath = 'soultalk/attachments/$rel';
        await txn.insert('attachment_index', {
          'id': id,
          'chat_id': chatId,
          'message_id': ref?.messageId,
          'original_name': originalName,
          // mime 优先取消息 metadata；其次按扩展名推断
          'mime_type': ref?.mime ?? _inferMimeType(originalName),
          'relative_path': relativePath,
          'sha256': digest.toString(),
          'size': stat.size,
          'created_at': stat.modified.millisecondsSinceEpoch,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        count++;
      }
    });
    return count;
  }

  static String? _inferMimeType(String name) {
    return switch (p.extension(name).toLowerCase()) {
      '.jpg' || '.jpeg' => 'image/jpeg',
      '.png' => 'image/png',
      '.gif' => 'image/gif',
      '.webp' => 'image/webp',
      '.pdf' => 'application/pdf',
      '.txt' || '.md' || '.log' => 'text/plain',
      '.json' => 'application/json',
      '.zip' => 'application/zip',
      '.mp3' => 'audio/mpeg',
      '.wav' => 'audio/wav',
      '.mp4' => 'video/mp4',
      _ => null,
    };
  }
}
