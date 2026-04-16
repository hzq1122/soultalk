import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../models/api_config.dart';
import 'database_service.dart';

class ApiConfigDao {
  final DatabaseService _db;
  final _uuid = const Uuid();

  ApiConfigDao(this._db);

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
    return rows.map(_fromMap).toList();
  }

  Future<ApiConfig?> getById(String id) async {
    final db = await _database;
    final rows = await db.query('api_configs', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : _fromMap(rows.first);
  }

  Future<ApiConfig> insert(ApiConfig config) async {
    final db = await _database;
    final now = DateTime.now();
    final newConfig = config.copyWith(
      id: config.id.isEmpty ? _uuid.v4() : config.id,
      createdAt: now,
      updatedAt: now,
    );
    await db.insert('api_configs', _toMap(newConfig));
    return newConfig;
  }

  Future<void> update(ApiConfig config) async {
    final db = await _database;
    final updated = config.copyWith(updatedAt: DateTime.now());
    await db.update(
      'api_configs',
      _toMap(updated),
      where: 'id = ?',
      whereArgs: [config.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await _database;
    await db.delete('api_configs', where: 'id = ?', whereArgs: [id]);
  }
}
