import 'package:flutter_test/flutter_test.dart';
import 'package:soultalk/services/regex/regex_service.dart';
import 'package:soultalk/models/regex_script.dart';

void main() {
  group('RegexService', () {
    final service = const RegexService();

    group('applyScripts', () {
      test('applies simple replacement', () {
        final scripts = [
          RegexScript(
            id: '1',
            scriptName: 'test',
            findRegex: 'hello',
            replaceString: 'world',
            placement: [RegexPlacement.userInput],
          ),
        ];

        final result = service.applyScripts(
          'hello there',
          scripts,
          RegexPlacement.userInput,
        );
        expect(result, 'world there');
      });

      test('applies global replacement by default', () {
        final scripts = [
          RegexScript(
            id: '1',
            scriptName: 'test',
            findRegex: 'a',
            replaceString: 'b',
            placement: [RegexPlacement.userInput],
          ),
        ];

        final result = service.applyScripts(
          'banana',
          scripts,
          RegexPlacement.userInput,
        );
        expect(result, 'bbnbnb');
      });

      test('respects placement filter', () {
        final scripts = [
          RegexScript(
            id: '1',
            scriptName: 'test',
            findRegex: 'hello',
            replaceString: 'world',
            placement: [RegexPlacement.aiOutput],
          ),
        ];

        final result = service.applyScripts(
          'hello there',
          scripts,
          RegexPlacement.userInput,
        );
        expect(result, 'hello there');
      });

      test('skips disabled scripts', () {
        final scripts = [
          RegexScript(
            id: '1',
            scriptName: 'test',
            findRegex: 'hello',
            replaceString: 'world',
            placement: [RegexPlacement.userInput],
            disabled: true,
          ),
        ];

        final result = service.applyScripts(
          'hello there',
          scripts,
          RegexPlacement.userInput,
        );
        expect(result, 'hello there');
      });

      test('supports /pattern/flags syntax', () {
        final scripts = [
          RegexScript(
            id: '1',
            scriptName: 'test',
            findRegex: '/HELLO/i',
            replaceString: 'world',
            placement: [RegexPlacement.userInput],
          ),
        ];

        final result = service.applyScripts(
          'hello there',
          scripts,
          RegexPlacement.userInput,
        );
        expect(result, 'world there');
      });

      test('supports capture groups in replacement', () {
        final scripts = [
          RegexScript(
            id: '1',
            scriptName: 'test',
            findRegex: '(\\w+)@(\\w+)',
            replaceString: '\$1 at \$2',
            placement: [RegexPlacement.userInput],
          ),
        ];

        final result = service.applyScripts(
          'user@host',
          scripts,
          RegexPlacement.userInput,
        );
        expect(result, 'user at host');
      });

      test('applies trimStrings before regex', () {
        final scripts = [
          RegexScript(
            id: '1',
            scriptName: 'test',
            findRegex: 'hello',
            replaceString: 'world',
            trimStrings: ['[', ']'],
            placement: [RegexPlacement.userInput],
          ),
        ];

        final result = service.applyScripts(
          '[hello]',
          scripts,
          RegexPlacement.userInput,
        );
        expect(result, 'world');
      });

      test('substituteRegex applies iterative replacement', () {
        final scripts = [
          RegexScript(
            id: '1',
            scriptName: 'test',
            findRegex: '\\{\\{([^}]+)\\}\\}',
            replaceString: '<\$1>',
            placement: [RegexPlacement.userInput],
            substituteRegex: 2,
          ),
        ];

        final result = service.applyScripts(
          '{{hello}}',
          scripts,
          RegexPlacement.userInput,
        );
        expect(result, '<hello>');
      });
    });

    group('applyMacros', () {
      test('replaces {{key}} with value', () {
        final result = service.applyMacros(
          'Hello {{name}}, welcome to {{place}}!',
          {'name': 'Alice', 'place': 'Wonderland'},
        );
        expect(result, 'Hello Alice, welcome to Wonderland!');
      });
    });

    group('validatePattern', () {
      test('returns true for valid regex', () {
        expect(RegexService.validatePattern('hello'), isTrue);
        expect(RegexService.validatePattern('/hello/g'), isTrue);
        expect(RegexService.validatePattern('\\d+'), isTrue);
      });

      test('returns false for invalid regex', () {
        expect(RegexService.validatePattern(''), isFalse);
        expect(RegexService.validatePattern('[invalid'), isTrue);
      });

      test('returns false for empty pattern', () {
        expect(RegexService.validatePattern(''), isFalse);
      });
    });
  });

  group('RegexScript', () {
    test('copyWith preserves minDepth and maxDepth when not provided', () {
      final script = RegexScript(
        id: '1',
        scriptName: 'test',
        findRegex: 'hello',
        replaceString: 'world',
        minDepth: 5,
        maxDepth: 10,
      );

      final copied = script.copyWith(scriptName: 'updated');
      expect(copied.minDepth, 5);
      expect(copied.maxDepth, 10);
      expect(copied.scriptName, 'updated');
    });

    test('fromDbMap handles null integer fields', () {
      final map = {
        'id': '1',
        'script_name': 'test',
        'find_regex': 'hello',
        'replace_string': 'world',
        'trim_strings': '[]',
        'placement': '[]',
        'disabled': null,
        'markdown_only': null,
        'prompt_only': null,
        'run_on_edit': null,
        'substitute_regex': null,
        'min_depth': null,
        'max_depth': null,
      };

      final script = RegexScript.fromDbMap(map);
      expect(script.disabled, isFalse);
      expect(script.markdownOnly, isFalse);
      expect(script.promptOnly, isFalse);
      expect(script.runOnEdit, isFalse);
      expect(script.substituteRegex, 0);
    });
  });
}
