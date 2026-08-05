import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soultalk/services/backup/cloud_storage.dart';

void main() {
  test('S3 signature uses real file content hash', () async {
    final tempDir = await Directory.systemTemp.createTemp('s3hash_');
    try {
      final file = File('${tempDir.path}/backup.enc.zip');
      final bytes = List<int>.generate(2048, (i) => (i * 7) % 251);
      await file.writeAsBytes(bytes);

      // upload 读取的字节与签名 hash 必须一致：
      // bodyHashFor(文件字节) == sha256(文件字节)
      final uploadedBytes = await file.readAsBytes();
      final hash = S3Storage.bodyHashFor(uploadedBytes);
      expect(hash, sha256.convert(bytes).toString());
      expect(hash.length, 64);
    } finally {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    }
  });

  test('bodyHashFor is stable for empty and ascii content', () {
    expect(
      S3Storage.bodyHashFor(const []),
      sha256.convert(const <int>[]).toString(),
    );
    expect(
      S3Storage.bodyHashFor('hello'.codeUnits),
      sha256.convert('hello'.codeUnits).toString(),
    );
    expect(S3Storage.bodyHashFor(const []).length, 64);
  });
}
