import 'dart:io';
import 'dart:typed_data';

/// 原子文件写入器。
///
/// 替换策略（防数据丢失）：先把已存在的目标文件改名为 `.bak`，
/// 再把临时文件 rename 为目标；rename 失败时把 `.bak` 恢复回去，
/// 避免“先删旧文件再 rename，新文件写入失败时旧文件已丢失”的问题。
/// 所有路径统一走 [_replaceFile]。
class AtomicFileWriter {
  Future<void> writeAsBytes(File target, Uint8List bytes) async {
    await target.parent.create(recursive: true);
    final temp = File(
      '${target.path}.tmp.${DateTime.now().microsecondsSinceEpoch}',
    );
    try {
      await temp.writeAsBytes(bytes, flush: true);
      await _replaceFile(temp, target);
    } finally {
      if (await temp.exists()) {
        try {
          await temp.delete();
        } catch (_) {}
      }
    }
  }

  /// 流式写入：适合大文件，避免整文件载入内存。
  /// 写入失败时清理临时文件并 rethrow。
  Future<void> writeFromStream(File target, Stream<List<int>> stream) async {
    await target.parent.create(recursive: true);
    final temp = File(
      '${target.path}.tmp.${DateTime.now().microsecondsSinceEpoch}',
    );
    // pipe 完成会自动 close 并 flush 到磁盘
    final sink = temp.openWrite();
    try {
      await stream.pipe(sink);
      await _replaceFile(temp, target);
    } catch (_) {
      await sink.close();
      rethrow;
    } finally {
      if (await temp.exists()) {
        try {
          await temp.delete();
        } catch (_) {}
      }
    }
  }

  Future<void> writeAsString(File target, String contents) async {
    await target.parent.create(recursive: true);
    final temp = File(
      '${target.path}.tmp.${DateTime.now().microsecondsSinceEpoch}',
    );
    try {
      await temp.writeAsString(contents, flush: true);
      await _replaceFile(temp, target);
    } finally {
      if (await temp.exists()) {
        try {
          await temp.delete();
        } catch (_) {}
      }
    }
  }

  /// 安全替换：目标存在时先移走为 .bak，再 rename 临时文件；
  /// rename 失败则尝试把 .bak 恢复，最后清理 .bak。
  Future<void> _replaceFile(File temp, File target) async {
    final backup = File('${target.path}.bak');
    var movedOld = false;
    if (await target.exists()) {
      // Windows 上 rename 到已存在目标会失败，必须先移走旧文件
      await target.rename(backup.path);
      movedOld = true;
    }
    try {
      await temp.rename(target.path);
    } catch (_) {
      // 新文件就位失败：恢复旧文件，避免数据丢失
      if (movedOld && await backup.exists()) {
        try {
          await backup.rename(target.path);
          movedOld = false;
        } catch (_) {}
      }
      rethrow;
    } finally {
      if (movedOld && await backup.exists()) {
        try {
          await backup.delete();
        } catch (_) {}
      }
    }
  }
}
