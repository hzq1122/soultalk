import '../../models/regex_script.dart';

class RegexService {
  const RegexService();

  String applyScripts(String text, List<RegexScript> scripts, int placement) {
    var result = text;
    for (final script in scripts) {
      if (script.disabled) continue;
      if (!script.placement.contains(placement)) continue;
      result = _applyScript(result, script);
    }
    return result;
  }

  String applyMacros(String text, Map<String, String> macros) {
    var result = text;
    for (final entry in macros.entries) {
      result = result.replaceAll('{{${entry.key}}}', entry.value);
    }
    return result;
  }

  static bool validatePattern(String findRegex) {
    if (findRegex.isEmpty) return false;
    final parsed = _parseFindRegex(findRegex);
    return parsed != null;
  }

  String _applyScript(String text, RegexScript script) {
    final parsed = _parseFindRegex(script.findRegex);
    if (parsed == null) return text;

    var result = text;

    for (final trimStr in script.trimStrings) {
      result = result.replaceAll(trimStr, '');
    }

    if (script.substituteRegex > 0) {
      result = _applySubstituteRegex(result, script, parsed);
    } else {
      result = result.replaceAllMapped(parsed, (match) {
        var replacement = script.replaceString;
        for (var i = 0; i <= match.groupCount; i++) {
          replacement = replacement.replaceAll('\$$i', match.group(i) ?? '');
        }
        return replacement;
      });
    }

    return result;
  }

  String _applySubstituteRegex(String text, RegexScript script, RegExp regex) {
    var result = text;
    int iterations = script.substituteRegex.clamp(1, 100);
    for (int i = 0; i < iterations; i++) {
      final newResult = result.replaceAllMapped(regex, (match) {
        var replacement = script.replaceString;
        for (var j = 0; j <= match.groupCount; j++) {
          replacement = replacement.replaceAll('\$$j', match.group(j) ?? '');
        }
        return replacement;
      });
      if (newResult == result) break;
      result = newResult;
    }
    return result;
  }

  static RegExp? _parseFindRegex(String findRegex) {
    if (findRegex.isEmpty) return null;

    if (findRegex.startsWith('/')) {
      final lastSlash = findRegex.lastIndexOf('/');
      if (lastSlash > 0) {
        final pattern = findRegex.substring(1, lastSlash);
        final flags = findRegex.substring(lastSlash + 1);
        final caseSensitive = !flags.contains('i');
        final dotAll = flags.contains('s');
        final multiLine = flags.contains('m');
        try {
          return RegExp(
            pattern,
            caseSensitive: caseSensitive,
            dotAll: dotAll,
            multiLine: multiLine,
          );
        } catch (_) {
          return null;
        }
      }
    }

    try {
      return RegExp(findRegex);
    } catch (_) {
      return null;
    }
  }
}
