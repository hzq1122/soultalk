import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:soultalk/models/memory_card.dart';
import 'package:soultalk/services/database/database_service.dart';
import 'package:soultalk/services/database/memory_card_dao.dart';
import 'package:soultalk/services/memory/card_extractor.dart';

void main() {
  late Database db;
  late DatabaseService dbService;
  late MemoryCardDao dao;

  setUp(() async {
    sqfliteFfiInit();
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute('''
      CREATE TABLE memory_cards (
        id TEXT PRIMARY KEY,
        contact_id TEXT NOT NULL,
        content TEXT NOT NULL,
        card_type TEXT NOT NULL DEFAULT 'fact',
        importance REAL NOT NULL DEFAULT 0.5,
        confidence REAL NOT NULL DEFAULT 0.5,
        scope TEXT NOT NULL DEFAULT 'local',
        tags TEXT NOT NULL DEFAULT '[]',
        status TEXT NOT NULL DEFAULT 'pending',
        created_at TEXT NOT NULL,
        updated_at TEXT,
        reviewed_at TEXT
      )
    ''');
    dbService = _TestDatabaseService(db);
    dao = MemoryCardDao(dbService);
  });

  tearDown(() async {
    await db.close();
  });

  test('extracted cards carry current contactId', () async {
    final cards = await const CardExtractor().extractFromResponse(
      'c-1',
      '[MEMORY:fact] 喜欢红茶 (importance: 0.9, confidence: 0.9)',
    );
    expect(cards, hasLength(1));
    expect(cards.single.contactId, 'c-1');

    await dao.insert(cards.single);
    final row = (await db.query('memory_cards')).single;
    expect(row['contact_id'], 'c-1');
  });

  test('memory cards are isolated per contact', () async {
    await dao.insert(
      MemoryCard(
        id: 'm1',
        contactId: 'c-1',
        content: 'tea',
        cardType: 'fact',
        importance: 0.8,
        confidence: 0.9,
        scope: 'local',
        tags: const [],
        status: 'active',
        createdAt: DateTime.now(),
      ),
    );
    await dao.insert(
      MemoryCard(
        id: 'm2',
        contactId: 'c-2',
        content: 'coffee',
        cardType: 'fact',
        importance: 0.8,
        confidence: 0.9,
        scope: 'local',
        tags: const [],
        status: 'active',
        createdAt: DateTime.now(),
      ),
    );

    expect(await dao.countByContact('c-1'), 1);
    final forC1 = await dao.getActiveByContact('c-1');
    expect(forC1.single.id, 'm1');
    expect(forC1.single.content, 'tea');
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
