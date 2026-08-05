import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_test/flutter_test.dart';
import 'package:soultalk/services/backup/backup_encryption.dart';

void main() {
  group('BackupEncryption AES-256-GCM', () {
    test('round-trips plaintext with password', () {
      final plain = Uint8List.fromList(utf8.encode('soultalk backup data'));
      final encrypted = BackupEncryption.encrypt(plain, 'secret-password');
      // 新格式：'SG1' + salt(32) + nonce(12) + ciphertext + tag(16)
      expect(encrypted.length, greaterThan(plain.length + 60));
      expect(encrypted[0], 0x53); // 'S'
      expect(encrypted[1], 0x47); // 'G'
      expect(encrypted[2], 0x31); // '1'

      final decrypted = BackupEncryption.decrypt(encrypted, 'secret-password');
      expect(utf8.decode(decrypted), 'soultalk backup data');
    });

    test(
      'generates different ciphertext for same plaintext (random salt/nonce)',
      () {
        final plain = Uint8List.fromList(utf8.encode('same data'));
        final a = BackupEncryption.encrypt(plain, 'pw');
        final b = BackupEncryption.encrypt(plain, 'pw');
        expect(a, isNot(equals(b)));
      },
    );

    test('rejects wrong password', () {
      final plain = Uint8List.fromList(utf8.encode('top secret'));
      final encrypted = BackupEncryption.encrypt(plain, 'correct');
      expect(
        () => BackupEncryption.decrypt(encrypted, 'wrong'),
        throwsA(anything),
      );
    });

    test('detects tampered ciphertext (authentication tag)', () {
      final plain = Uint8List.fromList(utf8.encode('integrity matters'));
      final encrypted = BackupEncryption.encrypt(plain, 'pw');
      final tampered = Uint8List.fromList(encrypted);
      // 翻转密文中间一个字节
      tampered[tampered.length ~/ 2] ^= 0x01;
      expect(() => BackupEncryption.decrypt(tampered, 'pw'), throwsA(anything));
    });

    test('rejects truncated data', () {
      expect(
        () => BackupEncryption.decrypt(
          Uint8List.fromList(List.filled(10, 0)),
          'pw',
        ),
        throwsA(anything),
      );
    });
  });

  group('BackupEncryption legacy CBC compatibility', () {
    test('decrypts legacy format backups', () {
      // 用历史算法（encrypt 包 CBC + 旧 KDF）构造旧备份样本
      final legacy = _legacyCbcEncrypt(
        Uint8List.fromList(utf8.encode('legacy backup content')),
        'legacy-password',
      );
      final decrypted = BackupEncryption.decrypt(legacy, 'legacy-password');
      expect(utf8.decode(decrypted), 'legacy backup content');
    });

    test('rejects legacy wrong password', () {
      final legacy = _legacyCbcEncrypt(
        Uint8List.fromList(utf8.encode('data')),
        'right',
      );
      expect(
        () => BackupEncryption.decrypt(legacy, 'wrong'),
        throwsA(anything),
      );
    });
  });
}

/// 历史版本（旧 backup_encryption 实现）的 AES-128-CBC 加密：
/// salt(32) + iv(16) + ciphertext；KDF 为 10000 次 HMAC-SHA256 迭代。
Uint8List _legacyCbcEncrypt(Uint8List plainData, String password) {
  final salt = Uint8List.fromList(List.generate(32, (i) => (i * 7 + 3) % 256));
  final saltStr = String.fromCharCodes(salt);
  var key = utf8.encode('$password$saltStr');
  final passwordBytes = utf8.encode(password);
  for (var i = 0; i < 10000; i++) {
    final hmac = Hmac(sha256, key);
    key = Uint8List.fromList(hmac.convert(passwordBytes).bytes);
  }
  final keyBytes = Uint8List.fromList(sha256.convert(key).bytes.sublist(0, 16));

  final iv = enc.IV(
    Uint8List.fromList(List.generate(16, (i) => (i * 13 + 5) % 256)),
  );
  final encrypter = enc.Encrypter(
    enc.AES(enc.Key(keyBytes), mode: enc.AESMode.cbc),
  );
  final cipherBytes = encrypter.encryptBytes(plainData, iv: iv).bytes;

  final result = Uint8List(32 + 16 + cipherBytes.length);
  result.setAll(0, salt);
  result.setAll(32, iv.bytes);
  result.setAll(48, cipherBytes);
  return result;
}
