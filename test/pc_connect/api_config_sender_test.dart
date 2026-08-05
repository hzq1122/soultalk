import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:soultalk/pc_connect/api_config_sender.dart';
import 'package:soultalk/services/database/database_service.dart';

void main() {
  late Database db;
  late ApiConfigSender sender;

  setUp(() async {
    sqfliteFfiInit();
    SharedPreferences.setMockInitialValues({});
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute('''
      CREATE TABLE api_configs (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        provider TEXT NOT NULL DEFAULT 'openai',
        base_url TEXT NOT NULL,
        api_key TEXT NOT NULL,
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
    await db.insert('api_configs', {
      'id': 'cfg-1',
      'name': 'main',
      'provider': 'openai',
      'base_url': 'https://api.openai.com/v1',
      'api_key': 'sk-secret-456',
      'model': 'gpt-4o-mini',
      'max_tokens': 4096,
      'temperature': 0.8,
      'stream_enabled': 1,
      'thinking_enabled': 1,
      'reasoning_effort': 'high',
    });
    sender = ApiConfigSender(dbService: _TestDatabaseService(db));
  });

  tearDown(() async {
    await db.close();
  });

  test('configs sent to PC never contain api_key', () async {
    final configs = await sender.getConfigsForSync();

    expect(configs, hasLength(1));
    expect(configs.single.containsKey('api_key'), isFalse);
    expect(configs.single['model'], 'gpt-4o-mini');
    expect(configs.single['thinking_enabled'], 1);
    expect(jsonEncodeSafe(configs), isNot(contains('sk-secret-456')));
  });

  test('empty table yields empty config list', () async {
    await db.delete('api_configs');
    final configs = await sender.getConfigsForSync();
    expect(configs, isEmpty);
  });
}

String jsonEncodeSafe(List<Map<String, dynamic>> configs) =>
    configs.map((c) => c.toString()).join();

class _TestDatabaseService implements DatabaseService {
  final Database _database;

  _TestDatabaseService(this._database);

  @override
  Future<Database> get database async => _database;

  @override
  Future<void> close() async {}
}
