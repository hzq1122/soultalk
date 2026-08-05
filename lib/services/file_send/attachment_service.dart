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

  /// 删除附件：attachment_index 记录 + 磁盘文件。
  /// 用于发送流程中途失败时的补偿清理。
  ///
  /// 安全：relative_path 来自索引（可能源自备份/导入），删除前做
  /// OS 级 canonical containment 校验，禁止越界删除应用目录外文件。
  Future<void> deleteAttachment(String attachmentId) async {
    final record = await attachmentIndexDao.getById(attachmentId);
    if (record == null) return;
    final file = File(p.join(paths.root.path, record.relativePath));
    // 先做 canonical containment 校验再删除：
    // 越界路径直接拒绝（索引保留，避免索引/文件不一致）。
    if (await file.exists() && !await _withinRootCanonical(file)) return;
    await attachmentIndexDao.deleteById(attachmentId);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// OS 级 canonical 校验：文件真实路径（解析符号链接后）必须位于
  /// 应用根目录内，防止 ../、绝对路径、junction 越界。
  Future<bool> _withinRootCanonical(File file) async {
    try {
      final rootPath = p.normalize(await paths.root.resolveSymbolicLinks());
      final filePath = p.normalize(await file.resolveSymbolicLinks());
      return filePath == rootPath || p.isWithin(rootPath, filePath);
    } catch (_) {
      final rootPath = p.normalize(p.absolute(paths.root.path));
      final filePath = p.normalize(p.absolute(file.path));
      return filePath == rootPath || p.isWithin(rootPath, filePath);
    }
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

    // 写入后校验：从最终落盘文件重新计算 hash/size，与写入前读取值
    // 比对，防止源文件在复制期间被修改导致索引记录与内容不一致。
    final writtenDigest = (await sha256.bind(target.openRead()).first)
        .toString();
    final writtenSize = await target.length();
    if (writtenDigest != digest.toString() || writtenSize != size) {
      if (await target.exists()) await target.delete();
      throw StateError('附件写入校验失败：源文件在复制期间发生变化');
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
