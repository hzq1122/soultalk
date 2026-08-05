import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soultalk/core/app_paths.dart';
import 'package:soultalk/models/contact.dart';
import 'package:soultalk/models/message.dart';
import 'package:soultalk/services/api/prompt_assembly_service.dart';

/// 端到端：ST 文件（世界书）→ PromptAssemblyService → 最终 API request body。
void main() {
  late Directory root;
  late AppPaths paths;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    root = await Directory.systemTemp.createTemp('st_e2e_');
    paths = AppPaths.fromRootForTesting(root);
    await paths.ensureInitialized();
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  Future<void> writeWorldBook() async {
    final world = {
      'name': 'Tea World',
      // ST 格式：entries 是 uid→条目 的 Map
      'entries': {
        '1': {
          'uid': 1,
          'key': ['tea'],
          'content': 'Alice 的设定：她只喝红茶，讨厌咖啡。',
          'position': 0,
        },
      },
    };
    await File('${paths.worlds.path}/tea_world.json')
        .create(recursive: true)
        .then((f) => f.writeAsString(jsonEncode(world)));
  }

  test(
    'ST world info file affects final API request body end-to-end',
    () async {
      await writeWorldBook();

      final assembled = await PromptAssemblyService(
        paths: paths,
      ).assemble(
        contact: Contact(id: 'c1', name: 'Alice'),
        history: [
          Message(
            id: 'm1',
            contactId: 'c1',
            role: MessageRole.user,
            content: '我想喝点 tea',
            createdAt: DateTime.now(),
          ),
        ],
      );

      expect(
        assembled.systemPrompt,
        contains('Alice 的设定：她只喝红茶'),
        reason: '世界书关键词匹配必须注入最终 prompt',
      );

      // 模拟 chat_service 构造的 API request body
      final requestBody = {
        'model': 'gpt-4o-mini',
        'messages': [
          {'role': 'system', 'content': assembled.systemPrompt},
          {'role': 'user', 'content': '我想喝点 tea'},
        ],
      };
      final bodyJson = jsonEncode(requestBody);
      expect(bodyJson, contains('她只喝红茶'));
      expect(bodyJson, contains('system'));
    },
  );

  test(
    'ST world info without keyword match is not injected (file source priority)',
    () async {
      await writeWorldBook();

      final assembled = await PromptAssemblyService(
        paths: paths,
      ).assemble(
        contact: Contact(id: 'c1', name: 'Alice'),
        history: [
          Message(
            id: 'm1',
            contactId: 'c1',
            role: MessageRole.user,
            content: '今天天气不错',
            createdAt: DateTime.now(),
          ),
        ],
      );

      expect(assembled.systemPrompt, isNot(contains('她只喝红茶')));
    },
  );

  test('character card fields flow into system prompt of request body', () async {
    final cardJson = jsonEncode({
      'spec': 'chara_card_v2',
      'data': {
        'name': 'Alice',
        'description': 'e2e description',
        'personality': 'e2e personality',
        'scenario': 'e2e scenario',
        'post_history_instructions': 'e2e post history',
      },
    });

    final assembled = await PromptAssemblyService(
      paths: paths,
    ).assemble(
      contact: Contact(
        id: 'c1',
        name: 'Alice',
        characterCardJson: cardJson,
      ),
      history: const [],
      userName: 'Bob',
    );

    final system = assembled.systemPrompt;
    expect(system, contains('e2e description'));
    expect(system, contains('e2e personality'));
    expect(system, contains('e2e scenario'));
    expect(assembled.postHistoryPrompt, contains('e2e post history'));
  });
}
