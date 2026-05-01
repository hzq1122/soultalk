import 'package:flutter_test/flutter_test.dart';
import 'package:soultalk/models/memory_entry.dart';
import 'package:soultalk/models/wallet_transaction.dart';
import 'package:soultalk/models/prompt_system.dart';

void main() {
  group('MemoryEntry', () {
    test('fromDbMap handles null fields gracefully', () {
      final map = <String, dynamic>{};

      final entry = MemoryEntry.fromDbMap(map);

      expect(entry.id, '');
      expect(entry.contactId, '');
      expect(entry.category, '');
      expect(entry.key, '');
      expect(entry.value, '');
    });

    test('fromDbMap parses valid data', () {
      final map = {
        'id': '123',
        'contact_id': 'c1',
        'category': 'personal',
        'key': 'name',
        'value': 'Alice',
        'updated_at': '2024-01-01T00:00:00.000',
      };

      final entry = MemoryEntry.fromDbMap(map);

      expect(entry.id, '123');
      expect(entry.contactId, 'c1');
      expect(entry.category, 'personal');
      expect(entry.key, 'name');
      expect(entry.value, 'Alice');
    });

    test('toJson includes all fields', () {
      final entry = MemoryEntry(
        id: '123',
        contactId: 'c1',
        category: 'personal',
        key: 'name',
        value: 'Alice',
        updatedAt: DateTime(2024),
      );

      final json = entry.toJson();

      expect(json.containsKey('id'), isTrue);
      expect(json.containsKey('contact_id'), isTrue);
      expect(json.containsKey('updated_at'), isTrue);
      expect(json['id'], '123');
    });

    test('fromLlmResponse parses JSON array', () {
      final response = '[{"category":"personal","key":"name","value":"Alice"}]';

      final entries = MemoryEntry.fromLlmResponse('c1', response);

      expect(entries.length, 1);
      expect(entries.first.key, 'name');
      expect(entries.first.value, 'Alice');
    });

    test('fromLlmResponse handles empty entries', () {
      final entries = MemoryEntry.fromLlmResponse('c1', '[]');
      expect(entries, isEmpty);
    });

    test('tableToPrompt renders categories', () {
      final entries = [
        MemoryEntry(
          id: '1',
          contactId: 'c1',
          category: 'personal',
          key: 'name',
          value: 'Alice',
          updatedAt: DateTime.now(),
        ),
        MemoryEntry(
          id: '2',
          contactId: 'c1',
          category: 'personal',
          key: 'age',
          value: '25',
          updatedAt: DateTime.now(),
        ),
      ];

      final prompt = MemoryEntry.tableToPrompt(entries);
      expect(prompt, contains('personal'));
      expect(prompt, contains('name'));
      expect(prompt, contains('Alice'));
    });
  });

  group('WalletTransaction', () {
    test('fromDbMap handles null fields', () {
      final map = <String, dynamic>{};

      final tx = WalletTransaction.fromDbMap(map);

      expect(tx.id, '');
      expect(tx.amount, 0.0);
      expect(tx.type, 'spend');
      expect(tx.description, '');
    });

    test('fromDbMap parses valid data', () {
      final map = {
        'id': 'tx1',
        'amount': 99.5,
        'type': 'recharge',
        'description': 'Top up',
        'contact_id': null,
        'contact_name': null,
        'created_at': '2024-01-01T00:00:00.000',
      };

      final tx = WalletTransaction.fromDbMap(map);

      expect(tx.id, 'tx1');
      expect(tx.amount, 99.5);
      expect(tx.type, 'recharge');
      expect(tx.description, 'Top up');
    });

    test('copyWith preserves fields', () {
      final tx = WalletTransaction(
        id: 'tx1',
        amount: 100,
        type: 'spend',
        description: 'Test',
        createdAt: DateTime(2024),
      );

      final copied = tx.copyWith(amount: 50);
      expect(copied.id, 'tx1');
      expect(copied.amount, 50);
      expect(copied.type, 'spend');
    });
  });

  group('PromptInjectionPosition', () {
    test('PromptEntry.fromJson handles out-of-range position index', () {
      final json = {
        'id': '1',
        'name': 'test',
        'content': 'hello',
        'position': 999,
        'strategy': 999,
      };

      final entry = PromptEntry.fromJson(json);

      expect(entry.position, PromptInjectionPosition.afterMain);
      expect(entry.strategy, PromptInjectionStrategy.relative);
    });

    test('PromptEntry.fromJson handles null position', () {
      final json = {'id': '1', 'name': 'test', 'content': 'hello'};

      final entry = PromptEntry.fromJson(json);

      expect(entry.position, PromptInjectionPosition.afterMain);
      expect(entry.strategy, PromptInjectionStrategy.relative);
    });
  });

  group('WorldInfoEntry', () {
    test('matchesKey with constant entry', () {
      final wi = WorldInfoEntry(
        id: '1',
        key: '',
        content: 'Always included',
        constant: true,
      );

      expect(wi.matchesKey('anything'), isTrue);
    });

    test('matchesKey with single key', () {
      final wi = WorldInfoEntry(
        id: '1',
        key: 'dragon',
        content: 'A dragon appears',
      );

      expect(wi.matchesKey('I saw a dragon today'), isTrue);
      expect(wi.matchesKey('I saw a cat today'), isFalse);
    });

    test('matchesKey with multiple comma-separated keys', () {
      final wi = WorldInfoEntry(
        id: '1',
        key: 'dragon, wyrm',
        content: 'A dragon appears',
      );

      expect(wi.matchesKey('The wyrm attacks'), isTrue);
      expect(wi.matchesKey('The cat sleeps'), isFalse);
    });

    test('matchesKey with selective mode requires secondary key', () {
      final wi = WorldInfoEntry(
        id: '1',
        key: 'dragon',
        keySecondary: ['fire'],
        content: 'Fire dragon info',
        selective: true,
      );

      expect(wi.matchesKey('A dragon breathes fire'), isTrue);
      expect(wi.matchesKey('A dragon sleeps'), isFalse);
    });

    test('matchesKey is case insensitive by default', () {
      final wi = WorldInfoEntry(id: '1', key: 'Dragon', content: 'Info');

      expect(wi.matchesKey('I saw a dragon'), isTrue);
      expect(wi.matchesKey('I saw a DRAGON'), isTrue);
    });
  });

  group('ContextTemplate', () {
    test('render replaces Handlebars variables', () {
      final template = ContextTemplate(
        id: '1',
        name: 'Test',
        storyString: '{{system}}\n{{description}}\n{{wiBefore}}',
      );

      final result = template.render({
        'system': 'You are helpful',
        'description': 'A character',
        'wiBefore': 'World info',
      });

      expect(result, contains('You are helpful'));
      expect(result, contains('A character'));
      expect(result, contains('World info'));
    });

    test('render removes unmatched variables', () {
      final template = ContextTemplate(
        id: '1',
        name: 'Test',
        storyString: '{{system}}\n{{unknown}}',
      );

      final result = template.render({'system': 'Hello'});

      expect(result, contains('Hello'));
      expect(result, isNot(contains('{{unknown}}')));
    });
  });
}
