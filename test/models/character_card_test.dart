import 'package:flutter_test/flutter_test.dart';
import 'package:soultalk/models/character_card.dart';

void main() {
  group('CharacterCard.fromV2Json', () {
    test('parses V2 format correctly', () {
      final json = {
        'spec': 'chara_card_v2',
        'spec_version': '2.0',
        'data': {
          'name': 'TestChar',
          'description': 'A test character',
          'personality': 'Friendly',
          'scenario': 'Test scenario',
          'first_mes': 'Hello!',
          'system_prompt': 'You are helpful',
          'mes_example': '<START>\nUser: Hi\nChar: Hello',
          'tags': ['test', 'v2'],
          'creator': 'TestCreator',
        },
      };

      final card = CharacterCard.fromV2Json(json);

      expect(card.name, 'TestChar');
      expect(card.description, 'A test character');
      expect(card.personality, 'Friendly');
      expect(card.scenario, 'Test scenario');
      expect(card.firstMes, 'Hello!');
      expect(card.systemPrompt, 'You are helpful');
      expect(card.tags, ['test', 'v2']);
      expect(card.spec, 'chara_card_v2');
      expect(card.specVersion, '2.0');
    });

    test('handles missing data gracefully', () {
      final json = <String, dynamic>{};

      final card = CharacterCard.fromV2Json(json);

      expect(card.name, '');
      expect(card.description, '');
      expect(card.tags, []);
    });
  });

  group('CharacterCard.fromV3Json', () {
    test('parses V3 format with alternateGreetings and extensions', () {
      final json = {
        'spec': 'chara_card_v3',
        'spec_version': '3.0',
        'data': {
          'name': 'V3Char',
          'description': 'V3 desc',
          'personality': 'Kind',
          'alternate_greetings': ['Greeting 1', 'Greeting 2'],
          'extensions': {
            'depth_prompt': {'prompt': 'test', 'depth': 4},
          },
          'character_version': '1.0.0',
        },
      };

      final card = CharacterCard.fromV3Json(json);

      expect(card.name, 'V3Char');
      expect(card.alternateGreetings, ['Greeting 1', 'Greeting 2']);
      expect(card.extensions, isA<Map<String, dynamic>>());
      expect(card.extensions['depth_prompt'], isA<Map<String, dynamic>>());
      expect(card.characterVersion, '1.0.0');
    });
  });

  group('CharacterCard.fromAutoDetectJson', () {
    test('detects V3 format', () {
      final json = {
        'spec': 'chara_card_v3',
        'spec_version': '3.0',
        'data': {'name': 'V3'},
      };

      final card = CharacterCard.fromAutoDetectJson(json);
      expect(card.spec, 'chara_card_v3');
      expect(card.specVersion, '3.0');
    });

    test('detects V2 format', () {
      final json = {
        'spec': 'chara_card_v2',
        'spec_version': '2.0',
        'data': {'name': 'V2'},
      };

      final card = CharacterCard.fromAutoDetectJson(json);
      expect(card.spec, 'chara_card_v2');
    });

    test('falls back to V1 for unknown format', () {
      final json = {
        'char_name': 'V1Char',
        'char_description': 'Old format',
        'char_greeting': 'Hi there',
      };

      final card = CharacterCard.fromAutoDetectJson(json);
      expect(card.name, 'V1Char');
      expect(card.description, 'Old format');
      expect(card.firstMes, 'Hi there');
      expect(card.spec, 'chara_card_v1');
      expect(card.specVersion, '1.0');
    });

    test('handles tags with non-String elements', () {
      final json = {
        'name': 'Test',
        'tags': [1, 2, 'string'],
      };

      final card = CharacterCard.fromAutoDetectJson(json);
      expect(card.tags, ['1', '2', 'string']);
    });
  });

  group('CharacterCard.buildSystemPrompt', () {
    test('replaces {{user}} and {{char}} in all fields', () {
      final card = CharacterCard(
        name: 'Alice',
        systemPrompt: 'You are {{char}}, talk to {{user}}',
        description: '{{char}} is a helpful AI',
        personality: '{{char}} is kind to {{user}}',
        scenario: '{{user}} meets {{char}}',
        mesExample: '{{user}}: Hi\n{{char}}: Hello',
      );

      final prompt = card.buildSystemPrompt('Bob');

      expect(prompt, contains('Alice'));
      expect(prompt, contains('Bob'));
      expect(prompt, isNot(contains('{{user}}')));
      expect(prompt, isNot(contains('{{char}}')));
    });
  });
}
