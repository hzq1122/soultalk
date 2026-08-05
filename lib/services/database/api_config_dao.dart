import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../models/api_config.dart';
import '../security/secure_api_key_store.dart';
import 'database_service.dart';

class ApiConfigDao {
  final DatabaseService _db;
  final SecureApiKeyStore _secureStore;
  final _uuid = const Uuid();

  /// [secureStore] 用于测试注入；默认使用系统安全存储。
  ApiConfigDao(this._db, {SecureApiKeyStore? secureStore})
    : _secureStore = secureStore ?? SecureApiKeyStore();

  Future<Database> get _database => _db.database;

  Map<String, dynamic> _toMap(ApiConfig config) => {
    'id': config.id,
    'name': config.name,
    'provider': config.provider.name,
    'base_url': config.baseUrl,
    'api_key': config.apiKey,
    'model': config.model,
    'max_tokens': config.maxTokens,
    'temperature': config.temperature,
    'stream_enabled': config.streamEnabled ? 1 : 0,
    'thinking_enabled': config.thinkingEnabled ? 1 : 0,
    'reasoning_effort': config.reasoningEffort,
    'created_at': config.createdAt?.toIso8601String(),
    'updated_at': config.updatedAt?.toIso8601String(),
  };

  ApiConfig _fromMap(Map<String, dynamic> map) => ApiConfig(
    id: map['id'] as String,
    name: map['name'] as String,
    provider: LlmProvider.values.firstWhere(
      (p) => p.name == map['provider'],
      orElse: () => LlmProvider.openai,
    ),
    baseUrl: map['base_url'] as String,
    apiKey: map['api_key'] as String,
    model: map['model'] as String,
    maxTokens: map['max_tokens'] as int,
    temperature: (map['temperature'] as num).toDouble(),
    streamEnabled: (map['stream_enabled'] as int) == 1,
    thinkingEnabled: (map['thinking_enabled'] as int? ?? 0) == 1,
    reasoningEffort: map['reasoning_effort'] as String? ?? 'high',
    createdAt: map['created_at'] != null
        ? DateTime.tryParse(map['created_at'] as String)
        : null,
    updatedAt: map['updated_at'] != null
        ? DateTime.tryParse(map['updated_at'] as String)
        : null,
  );

  Future<List<ApiConfig>> getAll() async {
    final db = await _database;
    final rows = await db.query('api_configs', orderBy: 'created_at ASC');
    final configs = <ApiConfig>[];
    for (final row in rows) {
      configs.add(await _withResolvedApiKey(_fromMap(row)));
    }
    return configs;
  }

  Future<ApiConfig?> getById(String id) async {
    final db = await _database;
    final rows = await db.query(
      'api_configs',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return null;
    return _withResolvedApiKey(_fromMap(rows.first));
  }

  /// API Key 解析：安全存储优先；SQLite 兼容字段仅作 fallback，
  /// 读取到旧 key 时惰性迁移到安全存储并清空 SQLite 字段。
  /// 安全存储写入失败时不清空 SQLite（保留 fallback，避免 key 丢失）。
  Future<ApiConfig> _withResolvedApiKey(ApiConfig config) async {
    final secureKey = await _secureStore.read(config.id);
    if (secureKey != null && secureKey.isNotEmpty) {
      return config.copyWith(apiKey: secureKey);
    }
    if (config.apiKey.isNotEmpty) {
      final secured = await _secureStore.write(config.id, config.apiKey);
      if (secured) {
        final db = await _database;
        await db.update(
          'api_configs',
          {'api_key': ''},
          where: 'id = ?',
          whereArgs: [config.id],
        );
      }
    }
    return config;
  }

  Future<ApiConfig> insert(ApiConfig config) async {
    final db = await _database;
    final now = DateTime.now();
    final newConfig = config.copyWith(
      id: config.id.isEmpty ? _uuid.v4() : config.id,
      createdAt: now,
      updatedAt: now,
    );
    // API Key 优先系统安全存储；写入成功则 SQLite 不存明文
    // （备份/同步自动剥离），失败时保留 SQLite 兼容字段作 fallback。
    if (newConfig.apiKey.isNotEmpty) {
      final secured = await _secureStore.write(newConfig.id, newConfig.apiKey);
      if (secured) {
        await db.insert('api_configs', {..._toMap(newConfig), 'api_key': ''});
        return newConfig;
      }
    }
    await db.insert('api_configs', _toMap(newConfig));
    return newConfig;
  }

  Future<void> update(ApiConfig config) async {
    final db = await _database;
    final updated = config.copyWith(updatedAt: DateTime.now());
    if (updated.apiKey.isNotEmpty) {
      final secured = await _secureStore.write(config.id, updated.apiKey);
      if (secured) {
        // 安全存储写入成功：SQLite 兼容字段置空
        await db.update(
          'api_configs',
          {..._toMap(updated), 'api_key': ''},
          where: 'id = ?',
          whereArgs: [config.id],
        );
        return;
      }
    } else {
      // 清空 key：同步删除安全存储中的旧 key，避免旧凭据继续生效
      await _secureStore.delete(config.id);
    }
    await db.update(
      'api_configs',
      _toMap(updated),
      where: 'id = ?',
      whereArgs: [config.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await _database;
    await _secureStore.delete(id);
    await db.delete('api_configs', where: 'id = ?', whereArgs: [id]);
  }
}
