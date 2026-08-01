import 'dart:io';
import 'dart:typed_data';

class AtomicFileWriter {
  Future<void> writeAsBytes(File target, Uint8List bytes) async {
    await target.parent.create(recursive: true);
    final temp = File(
      '${target.path}.tmp.${DateTime.now().microsecondsSinceEpoch}',
    );
    await temp.writeAsBytes(bytes, flush: true);
    if (await target.exists()) {
      await target.delete();
    }
    await temp.rename(target.path);
  }

  /// 流式写入：适合大文件，避免整文件载入内存。
  /// 写入失败时清理临时文件并 rethrow。
  Future<void> writeFromStream(File target, Stream<List<int>> stream) async {
    await target.parent.create(recursive: true);
    final temp = File(
      '${target.path}.tmp.${DateTime.now().microsecondsSinceEpoch}',
    );
    final sink = temp.openWrite(flush: true);
    try {
      await stream.pipe(sink);
    } catch (_) {
      await sink.close();
      if (await temp.exists()) await temp.delete();
      rethrow;
    }
    if (await target.exists()) {
      await target.delete();
    }
    await temp.rename(target.path);
  }

  Future<void> writeAsString(File target, String contents) async {
    await target.parent.create(recursive: true);
    final temp = File(
      '${target.path}.tmp.${DateTime.now().microsecondsSinceEpoch}',
    );
    await temp.writeAsString(contents, flush: true);
    if (await target.exists()) {
      await target.delete();
    }
    await temp.rename(target.path);
  }
}
