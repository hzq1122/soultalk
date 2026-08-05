import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:soultalk/models/api_config.dart';
import 'package:soultalk/services/database/api_config_dao.dart';
import 'package:soultalk/services/database/database_service.dart';
import 'package:soultalk/services/security/secure_api_key_store.dart';

/// 内存版安全存储（模拟系统安全存储成功/失败场景）。
class _FakeSecureStore extends SecureApiKeyStore {
  final Map<String, String> values = {};
  bool failing = false;

  _FakeSecureStore() : super(storage: null);

  @override
  Future<String?> read(String configId) async {
    if (failing) return null;
    return values['api_key_$configId'];
  }

  @override
  Future<bool> write(String configId, String key) async {
    if (failing) return false;
    values['api_key_$configId'] = key;
    return true;
  }

  @override
  Future<void> delete(String configId) async {
    values.remove('api_key_$configId');
  }
}

void main() {
  late Database db;
  late DatabaseService dbService;
  late _FakeSecureStore secureStore;
  late ApiConfigDao dao;

  setUp(() async {
    sqfliteFfiInit();
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute('''
      CREATE TABLE api_configs (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        provider TEXT NOT NULL DEFAULT 'openai',
        base_url TEXT NOT NULL,
        api_key TEXT NOT NULL DEFAULT '',
        model TEXT NOT NULL,
        max_tokens INTEGER NOT NULL DEFAULT 4096,
        temperature REAL NOT NULL DEFAULT 0.8,
        stream_enabled INTEGER NOT NULL DEFAULT 1,
        thinking_enabled INTEGER NOT NULL DEFAULT 0,
        reasoning_effort TEXT NOT NULL DEFAULT 'high',
        created_at TEXT,
        updated_at TEXT
      )
    ''');
    dbService = _TestDatabaseService(db);
    secureStore = _FakeSecureStore();
    dao = ApiConfigDao(dbService, secureStore: secureStore);
  });

  tearDown(() async {
    await db.close();
  });

  ApiConfig makeConfig({String id = 'cfg-1', String apiKey = 'sk-secure'}) =>
      ApiConfig(
        id: id,
        name: 'main',
        provider: LlmProvider.openai,
        baseUrl: 'https://api.openai.com/v1',
        apiKey: apiKey,
        model: 'gpt-4o-mini',
        maxTokens: 4096,
        temperature: 0.8,
      );

  test('secure storage takes precedence over SQLite field', () async {
    secureStore.values['api_key_cfg-1'] = 'sk-from-secure';
    await db.insert('api_configs', {
      'id': 'cfg-1',
      'name': 'main',
      'base_url': 'https://api.openai.com/v1',
      'api_key': 'sk-stale-in-db',
      'model': 'gpt-4o-mini',
      'max_tokens': 4096,
      'temperature': 0.8,
    });

    final config = await dao.getById('cfg-1');
    expect(config!.apiKey, 'sk-from-secure');
  });

  test('SQLite field is fallback and gets lazily migrated to secure',
      () async {
    await db.insert('api_configs', {
      'id': 'cfg-1',
      'name': 'main',
      'base_url': 'https://api.openai.com/v1',
      'api_key': 'sk-legacy',
      'model': 'gpt-4o-mini',
      'max_tokens': 4096,
      'temperature': 0.8,
    });

    final config = await dao.getById('cfg-1');
    expect(config!.apiKey, 'sk-legacy', reason: 'fallback 必须返回 SQLite 值');

    // 惰性迁移：secure 已写入、SQLite 字段被清空
    expect(secureStore.values['api_key_cfg-1'], 'sk-legacy');
    final row = (await db.query('api_configs')).single;
    expect(row['api_key'], '');
  });

  test('insert writes key to secure storage', () async {
    final saved = await dao.insert(makeConfig());
    expect(secureStore.values['api_key_${saved.id}'], 'sk-secure');
    final reloaded = await dao.getById(saved.id);
    expect(reloaded!.apiKey, 'sk-secure');
  });

  test('secure store failure falls back to SQLite (no crash)', () async {
    secureStore.failing = true;
    await db.insert('api_configs', {
      'id': 'cfg-1',
      'name': 'main',
      'base_url': 'https://api.openai.com/v1',
      'api_key': 'sk-db-only',
      'model': 'gpt-4o-mini',
      'max_tokens': 4096,
      'temperature': 0.8,
    });

    final config = await dao.getById('cfg-1');
    expect(config!.apiKey, 'sk-db-only');
  });
}

class _TestDatabaseService implements DatabaseService {
  final Database _database;

  _TestDatabaseService(this._database);

  @override
  Future<Database> get database async => _database;

  @override
  Future<void> close() async {}
}
