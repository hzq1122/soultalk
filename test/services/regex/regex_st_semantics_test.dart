import 'package:flutter_test/flutter_test.dart';
import 'package:soultalk/models/regex_script.dart';
import 'package:soultalk/services/regex/regex_service.dart';

void main() {
  const service = RegexService();

  RegexScript script({
    int? minDepth,
    int? maxDepth,
    bool promptOnly = false,
    List<int> placement = const [RegexPlacement.aiOutput],
    String? findRegexOverride,
    String? replaceOverride,
  }) => RegexScript(
    id: 'r1',
    scriptName: 'test',
    findRegex: findRegexOverride ?? r'\bfoo\b',
    replaceString: replaceOverride ?? 'bar',
    placement: placement,
    promptOnly: promptOnly,
    minDepth: minDepth,
    maxDepth: maxDepth,
  );

  test('minDepth/maxDepth filter by context depth (ST semantics)', () {
    final s = script(minDepth: 3, maxDepth: 5);
    // 深度不足：不应用
    expect(service.applyScripts('foo', [s], RegexPlacement.aiOutput, depth: 2), 'foo');
    // 深度范围内：应用
    expect(service.applyScripts('foo', [s], RegexPlacement.aiOutput, depth: 4), 'bar');
    // 深度超出：不应用
    expect(service.applyScripts('foo', [s], RegexPlacement.aiOutput, depth: 6), 'foo');
  });

  test('without depth, depth limits are ignored (backward compatible)', () {
    final s = script(minDepth: 3);
    expect(service.applyScripts('foo', [s], RegexPlacement.aiOutput), 'bar');
  });

  test('promptOnly scripts are skipped when includePromptOnly=false', () {
    final promptOnly = script(
      findRegexOverride: r'\bfoo\b',
      replaceOverride: 'x',
      promptOnly: true,
    );
    final normal = script(
      findRegexOverride: r'\bbaz\b',
      replaceOverride: 'y',
    );
    // prompt 路径：两者都应用
    expect(
      service.applyScripts(
        'foo baz',
        [promptOnly, normal],
        RegexPlacement.aiOutput,
      ),
      'x y',
    );
    // UI 显示路径：仅普通脚本应用（ST ephemeral-prompt 语义）
    expect(
      service.applyScripts(
        'foo baz',
        [promptOnly, normal],
        RegexPlacement.aiOutput,
        includePromptOnly: false,
      ),
      'foo y',
    );
  });

  test('placement still gates application', () {
    final s = script(placement: [RegexPlacement.userInput]);
    expect(service.applyScripts('foo', [s], RegexPlacement.aiOutput), 'foo');
    expect(service.applyScripts('foo', [s], RegexPlacement.userInput), 'bar');
  });
}
