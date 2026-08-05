import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/block/modes/gcm.dart';
import 'package:pointycastle/pointycastle.dart' show AEADParameters, KeyParameter;

/// 备份加密。
///
/// 新格式使用 AES-256-GCM（自带认证标签，篡改或密码错误会被检测）：
///   'SG1' + salt(32) + nonce(12) + ciphertext + tag(16)
/// 旧格式（历史版本）为 AES-128-CBC 无认证：
///   salt(32) + iv(16) + ciphertext
/// [decrypt] 通过前缀魔数自动判别两种格式，旧备份仍可恢复。
class BackupEncryption {
  /// 新格式魔数前缀 'SG1'。
  static const List<int> _magic = [0x53, 0x47, 0x31];
  static const int _saltLength = 32;
  static const int _nonceLength = 12;
  static const int _tagLength = 16;
  static const int _macSizeBits = 128; // GCM tag = 16 字节
  static const int _kdfIterations = 100000;

  /// Encrypt bytes with AES-256-GCM using password.
  static Uint8List encrypt(Uint8List plainData, String password) {
    final salt = _randomBytes(_saltLength);
    final nonce = _randomBytes(_nonceLength);
    final key = _pbkdf2Sha256(password, salt, iterations: _kdfIterations);

    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        true,
        AEADParameters<KeyParameter>(
          KeyParameter(key),
          _macSizeBits,
          nonce,
          Uint8List(0),
        ),
      );
    final out = Uint8List(cipher.getOutputSize(plainData.length));
    final len1 = cipher.processBytes(plainData, 0, plainData.length, out, 0);
    final len2 = cipher.doFinal(out, len1);
    final body = Uint8List.sublistView(out, 0, len1 + len2);

    final result = Uint8List(
      _magic.length + _saltLength + _nonceLength + body.length,
    );
    var offset = 0;
    result.setAll(offset, _magic);
    offset += _magic.length;
    result.setAll(offset, salt);
    offset += _saltLength;
    result.setAll(offset, nonce);
    offset += _nonceLength;
    result.setAll(offset, body);
    return result;
  }

  /// Decrypt bytes. 新格式（GCM）失败抛异常；旧格式（CBC）自动兼容。
  static Uint8List decrypt(Uint8List encryptedData, String password) {
    if (_startsWithMagic(encryptedData)) {
      return _decryptGcm(encryptedData, password);
    }
    return _decryptLegacyCbc(encryptedData, password);
  }

  static Uint8List _decryptGcm(Uint8List encryptedData, String password) {
    final minLength =
        _magic.length + _saltLength + _nonceLength + _tagLength;
    if (encryptedData.length < minLength) {
      throw ArgumentError('Invalid encrypted data: too short');
    }
    var offset = _magic.length;
    final saltBytes = encryptedData.sublist(offset, offset + _saltLength);
    offset += _saltLength;
    final nonceBytes = encryptedData.sublist(offset, offset + _nonceLength);
    offset += _nonceLength;
    final body = encryptedData.sublist(offset);

    final key = _pbkdf2Sha256(
      password,
      saltBytes,
      iterations: _kdfIterations,
    );
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        false,
        AEADParameters<KeyParameter>(
          KeyParameter(key),
          _macSizeBits,
          nonceBytes,
          Uint8List(0),
        ),
      );
    final out = Uint8List(cipher.getOutputSize(body.length));
    final len1 = cipher.processBytes(body, 0, body.length, out, 0);
    final len2 = cipher.doFinal(out, len1);
    return Uint8List.sublistView(out, 0, len1 + len2);
  }

  /// 旧格式：salt(32) + iv(16) + ciphertext（AES-128-CBC，无认证标签）。
  static Uint8List _decryptLegacyCbc(Uint8List encryptedData, String password) {
    if (encryptedData.length < _saltLength + 16 + 16) {
      throw ArgumentError('Invalid encrypted data: too short');
    }
    final saltBytes = encryptedData.sublist(0, _saltLength);
    final ivBytes = encryptedData.sublist(_saltLength, _saltLength + 16);
    final cipherBytes = encryptedData.sublist(_saltLength + 16);

    final keyBytes = _deriveLegacyKey(password, saltBytes);
    final key = enc.Key(keyBytes);
    final iv = enc.IV(Uint8List.fromList(ivBytes));

    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final decrypted = encrypter.decryptBytes(
      enc.Encrypted(Uint8List.fromList(cipherBytes)),
      iv: iv,
    );

    return Uint8List.fromList(decrypted);
  }

  static Uint8List _randomBytes(int length) {
    final rng = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => rng.nextInt(256)),
    );
  }

  /// PBKDF2-HMAC-SHA256，单块输出（length <= 32）。
  static Uint8List _pbkdf2Sha256(
    String password,
    List<int> salt, {
    required int iterations,
    int length = 32,
  }) {
    final passwordBytes = utf8.encode(password);
    final hmac = Hmac(sha256, passwordBytes);
    // U1 = HMAC(password, salt || INT(1))
    final block = <int>[...salt, 0, 0, 0, 1];
    var u = hmac.convert(block).bytes;
    final result = Uint8List.fromList(u);
    for (var i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < result.length; j++) {
        result[j] ^= u[j];
      }
    }
    return result.sublist(0, length);
  }

  static bool _startsWithMagic(Uint8List bytes) {
    if (bytes.length < _magic.length) return false;
    for (var i = 0; i < _magic.length; i++) {
      if (bytes[i] != _magic[i]) return false;
    }
    return true;
  }

  /// 旧格式密钥派生（历史实现，仅用于解密旧备份）。
  static Uint8List _deriveLegacyKey(String password, List<int> salt) {
    final saltStr = String.fromCharCodes(salt);
    var key = utf8.encode('$password$saltStr');
    final passwordBytes = utf8.encode(password);
    for (var i = 0; i < 10000; i++) {
      final hmac = Hmac(sha256, key);
      key = Uint8List.fromList(hmac.convert(passwordBytes).bytes);
    }
    return Uint8List.fromList(sha256.convert(key).bytes.sublist(0, 16));
  }
}
