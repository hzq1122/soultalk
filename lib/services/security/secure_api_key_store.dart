import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// API Key 系统安全存储（Windows DPAPI / Android Keystore / iOS Keychain）。
///
/// 优先级语义：写入时优先安全存储，失败（平台不可用、测试环境等）
/// 时静默回退——调用方（ApiConfigDao）此时保留 SQLite 兼容字段；
/// 读取时安全存储优先，找不到时回退 SQLite。
class SecureApiKeyStore {
  static const _keyPrefix = 'api_key_';

  final FlutterSecureStorage? _storage;

  SecureApiKeyStore({FlutterSecureStorage? storage}) : _storage = storage;

  FlutterSecureStorage get _impl =>
      _storage ??
      const FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
      );

  String _keyFor(String configId) => '$_keyPrefix$configId';

  /// 读取配置对应的 API Key；安全存储不可用时返回 null（由调用方
  /// 回退 SQLite 兼容字段）。
  Future<String?> read(String configId) async {
    try {
      return await _impl.read(key: _keyFor(configId));
    } catch (_) {
      return null;
    }
  }

  /// 写入 API Key 到安全存储；返回是否写入成功。
  /// 失败（平台不可用等）时调用方将明文保留在 SQLite 兼容字段作为
  /// fallback；成功时调用方应清空 SQLite 字段，避免 DB 长期留明文。
  Future<bool> write(String configId, String key) async {
    if (key.isEmpty) return true;
    try {
      await _impl.write(key: _keyFor(configId), value: key);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 删除安全存储中的 API Key。
  Future<void> delete(String configId) async {
    try {
      await _impl.delete(key: _keyFor(configId));
    } catch (_) {}
  }
}
