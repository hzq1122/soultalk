import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:soultalk/models/api_config.dart';
import 'package:soultalk/services/database/api_config_dao.dart';
import 'package:soultalk/services/database/database_service.dart';

void main() {
  late Database db;
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
        api_key TEXT NOT NULL,
        model TEXT NOT NULL DEFAULT 'gpt-4o-mini',
        max_tokens INTEGER NOT NULL DEFAULT 4096,
        temperature REAL NOT NULL DEFAULT 0.8,
        stream_enabled INTEGER NOT NULL DEFAULT 1,
        thinking_enabled INTEGER NOT NULL DEFAULT 0,
        reasoning_effort TEXT NOT NULL DEFAULT 'high',
        created_at TEXT,
        updated_at TEXT
      )
    ''');
    dao = ApiConfigDao(_TestDatabaseService(db));
  });

  tearDown(() async {
    await db.close();
  });

  test('thinking config round-trips through DAO', () async {
    final inserted = await dao.insert(
      const ApiConfig(
        id: '',
        name: 'anthropic-thinking',
        provider: LlmProvider.anthropic,
        baseUrl: 'https://api.anthropic.com',
        apiKey: 'sk-ant-test',
        model: 'claude-sonnet-4-5',
        thinkingEnabled: true,
        reasoningEffort: 'low',
      ),
    );
    expect(inserted.thinkingEnabled, isTrue);
    expect(inserted.reasoningEffort, 'low');

    final loaded = await dao.getById(inserted.id);
    expect(loaded, isNotNull);
    expect(loaded!.thinkingEnabled, isTrue);
    expect(loaded.reasoningEffort, 'low');
    expect(loaded.model, 'claude-sonnet-4-5');

    // 更新后仍持久化
    await dao.update(
      loaded.copyWith(thinkingEnabled: false, reasoningEffort: 'high'),
    );
    final reloaded = await dao.getById(inserted.id);
    expect(reloaded!.thinkingEnabled, isFalse);
    expect(reloaded.reasoningEffort, 'high');
  });

  test('missing columns fall back to defaults', () async {
    // 模拟未迁移的旧库：行没有 thinking 列时读取应使用默认值
    await db.execute('ALTER TABLE api_configs RENAME TO api_configs_old');
    await db.execute('''
      CREATE TABLE api_configs (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        provider TEXT NOT NULL DEFAULT 'openai',
        base_url TEXT NOT NULL,
        api_key TEXT NOT NULL,
        model TEXT NOT NULL DEFAULT 'gpt-4o-mini',
        max_tokens INTEGER NOT NULL DEFAULT 4096,
        temperature REAL NOT NULL DEFAULT 0.8,
        stream_enabled INTEGER NOT NULL DEFAULT 1,
        created_at TEXT,
        updated_at TEXT
      )
    ''');
    await db.insert('api_configs', {
      'id': 'legacy-1',
      'name': 'legacy',
      'provider': 'openai',
      'base_url': 'https://api.openai.com/v1',
      'api_key': 'sk-legacy',
    });
    final loaded = await dao.getById('legacy-1');
    expect(loaded, isNotNull);
    expect(loaded!.thinkingEnabled, isFalse);
    expect(loaded.reasoningEffort, 'high');
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
