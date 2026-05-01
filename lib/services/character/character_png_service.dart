import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import '../../models/contact.dart';
import 'character_card_service.dart';

/// 从 PNG 文件的 tEXt / iTXt chunk 中提取嵌入的角色卡 JSON
///
/// SillyTavern 将角色卡 JSON 用 Base64 编码后写入 PNG 的 tEXt chunk，
/// 关键字通常为 "chara"（部分工具写 iTXt 格式）。
class CharacterPngService {
  // PNG signature: 8 bytes
  static const _pngSignature = [137, 80, 78, 71, 13, 10, 26, 10];

  /// 从 PNG 文件路径读取并解析内嵌角色卡
  static Future<Contact?> fromPngFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      final raw = _extractCharaJson(bytes);
      if (raw == null) return null;
      return CharacterCardService.fromJsonString(raw);
    } catch (e) {
      return null;
    }
  }

  /// 从 Uint8List bytes 提取角色卡 JSON 字符串（可在 isolate 中调用）
  static String? extractJsonFromBytes(Uint8List bytes) {
    return _extractCharaJson(bytes);
  }

  // -------------------------------------------------------------------------
  // 内部实现
  // -------------------------------------------------------------------------

  static String? extractCharaJson(Uint8List bytes) {
    return _extractCharaJson(bytes);
  }

  static String? _extractCharaJson(Uint8List bytes) {
    // 校验 PNG 文件头
    if (bytes.length < 8) return null;
    for (var i = 0; i < 8; i++) {
      if (bytes[i] != _pngSignature[i]) return null;
    }

    int pos = 8; // 跳过 PNG 签名
    while (pos + 12 <= bytes.length) {
      // 每个 chunk: [length 4B][type 4B][data nB][crc 4B]
      final length = _readUint32(bytes, pos);
      final type = String.fromCharCodes(bytes.sublist(pos + 4, pos + 8));
      final dataStart = pos + 8;
      final dataEnd = dataStart + length;

      if (dataEnd > bytes.length) break;

      if (type == 'tEXt') {
        final result = _parseTExt(bytes.sublist(dataStart, dataEnd));
        if (result != null) return result;
      } else if (type == 'iTXt') {
        final result = _parseITxt(bytes.sublist(dataStart, dataEnd));
        if (result != null) return result;
      } else if (type == 'IEND') {
        break; // PNG 结束
      }

      pos = dataEnd + 4; // +4 跳过 CRC
    }
    return null;
  }

  /// 解析 tEXt chunk: keyword\x00text (Latin-1)
  static String? _parseTExt(Uint8List data) {
    final nullIdx = data.indexOf(0);
    if (nullIdx < 0) return null;

    final keyword = String.fromCharCodes(data.sublist(0, nullIdx));
    if (!_isCharaKeyword(keyword)) return null;

    final textBytes = data.sublist(nullIdx + 1);
    final base64Str = String.fromCharCodes(textBytes).trim();
    return _decodeBase64Json(base64Str);
  }

  /// 解析 iTXt chunk（国际化文本，可含 UTF-8）
  /// 格式: keyword\x00compressionFlag\x00compressionMethod\x00langTag\x00translatedKeyword\x00text
  static String? _parseITxt(Uint8List data) {
    final nullIdx = data.indexOf(0);
    if (nullIdx < 0) return null;

    final keyword = String.fromCharCodes(data.sublist(0, nullIdx));
    if (!_isCharaKeyword(keyword)) return null;

    // Skip: keyword\0 + compressionFlag(1) + compressionMethod(1)
    var pos = nullIdx + 3;

    // Skip langTag\0
    final langEnd = _nextNull(data, pos);
    if (langEnd < 0) return null;
    pos = langEnd + 1;

    // Skip translatedKeyword\0
    final tkEnd = _nextNull(data, pos);
    if (tkEnd < 0) return null;
    pos = tkEnd + 1;

    // Remaining is the actual text (UTF-8)
    final textBytes = data.sublist(pos);
    final text = utf8.decode(textBytes, allowMalformed: true).trim();
    return _decodeBase64Json(text);
  }

  /// "chara" / "Chara" / "CHARA" — 忽略大小写匹配
  static bool _isCharaKeyword(String keyword) =>
      keyword.toLowerCase() == 'chara';

  /// Base64 → JSON 字符串（自动添加 padding）
  static String? _decodeBase64Json(String base64Str) {
    try {
      // 修正 padding
      var padded = base64Str;
      final rem = padded.length % 4;
      if (rem == 2) padded += '==';
      if (rem == 3) padded += '=';

      final decoded = utf8.decode(base64Decode(padded));
      // 验证是否为合法 JSON 且含角色卡标志
      if (CharacterCardService.isValidCardJson(decoded)) {
        return decoded;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static int _readUint32(Uint8List bytes, int offset) {
    return (bytes[offset] << 24) |
        (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        bytes[offset + 3];
  }

  static int _nextNull(Uint8List data, int start) {
    for (var i = start; i < data.length; i++) {
      if (data[i] == 0) return i;
    }
    return -1;
  }
}
