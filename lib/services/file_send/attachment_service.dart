import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../core/app_paths.dart';
import '../../core/file_store/atomic_file_writer.dart';
import '../../core/file_store/path_sanitizer.dart';
import '../database/attachment_index_dao.dart';
import '../database/database_service.dart';

class AttachmentService {
  final AppPaths paths;
  final AttachmentIndexDao attachmentIndexDao;
  final AtomicFileWriter atomicFileWriter;
  final PathSanitizer pathSanitizer;
  final Uuid uuid;

  AttachmentService({
    required this.paths,
    required this.attachmentIndexDao,
    AtomicFileWriter? atomicFileWriter,
    PathSanitizer? pathSanitizer,
    Uuid? uuid,
  }) : atomicFileWriter = atomicFileWriter ?? AtomicFileWriter(),
       pathSanitizer = pathSanitizer ?? PathSanitizer(),
       uuid = uuid ?? const Uuid();

  static Future<AttachmentService> create() async {
    final paths = await AppPaths.create();
    await paths.ensureInitialized();
    return AttachmentService(
      paths: paths,
      attachmentIndexDao: AttachmentIndexDao(DatabaseService()),
    );
  }

  static String? inferMimeType(String path) {
    return switch (p.extension(path).toLowerCase()) {
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

  Future<void> attachToMessage({
    required String attachmentId,
    required String messageId,
  }) {
    return attachmentIndexDao.updateMessageId(attachmentId, messageId);
  }

  Future<AttachmentIndexRecord> importFile({
    required String chatId,
    required File source,
    String? messageId,
    String? mimeType,
  }) async {
    final id = uuid.v4();
    final originalName = p.basename(source.path);
    final safeChatId = pathSanitizer.fileName(chatId, fallback: 'chat');
    final safeName = pathSanitizer.fileName(originalName);
    final relativePath = 'soultalk/attachments/$safeChatId/$id-$safeName';
    final target = File(p.join(paths.root.path, relativePath));

    // 流式计算 sha256 与大小，不把大文件整体载入内存
    final digest = await sha256.bind(source.openRead()).first;
    final size = await source.length();

    try {
      await atomicFileWriter.writeFromStream(target, source.openRead());
    } catch (_) {
      // 写入失败时清理可能残留的临时/目标文件
      if (await target.exists()) await target.delete();
      rethrow;
    }

    final record = AttachmentIndexRecord(
      id: id,
      chatId: chatId,
      messageId: messageId,
      originalName: originalName,
      mimeType: mimeType,
      relativePath: relativePath,
      sha256: digest.toString(),
      size: size,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    try {
      await attachmentIndexDao.upsert(record);
    } catch (_) {
      // 索引写入失败时删除已复制的文件，避免留下孤儿文件
      if (await target.exists()) await target.delete();
      rethrow;
    }
    return record;
  }

  Map<String, dynamic> toChatExtra(AttachmentIndexRecord record) {
    return {
      'id': record.id,
      'name': record.originalName,
      'mime': record.mimeType,
      'relative_path': record.relativePath,
      'size': record.size,
      'sha256': record.sha256,
    };
  }
}
