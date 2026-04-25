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

  String _applyScript(String text, RegexScript script) {
    final parsed = _parseFindRegex(script.findRegex);
    if (parsed == null) return text;

    final regex = parsed;
    var result = text;

    for (final trimStr in script.trimStrings) {
      result = result.replaceAll(trimStr, '');
    }

    result = result.replaceAllMapped(regex, (match) {
      var replacement = script.replaceString;
      for (var i = 0; i <= match.groupCount; i++) {
        replacement = replacement.replaceAll('\$$i', match.group(i) ?? '');
      }
      return replacement;
    });

    return result;
  }

  static RegExp? _parseFindRegex(String findRegex) {
    if (findRegex.isEmpty) return null;

    // SillyTavern format: /pattern/flags
    if (findRegex.startsWith('/')) {
      final lastSlash = findRegex.lastIndexOf('/');
      if (lastSlash > 0) {
        final pattern = findRegex.substring(1, lastSlash);
        final flags = findRegex.substring(lastSlash + 1);
        final caseSensitive = !flags.contains('i');
        final dotAll = flags.contains('s');
        final multiLine = flags.contains('m');
        try {
          return RegExp(pattern,
              caseSensitive: caseSensitive,
              dotAll: dotAll,
              multiLine: multiLine);
        } catch (_) {
          return null;
        }
      }
    }

    // Plain regex string
    try {
      return RegExp(findRegex);
    } catch (_) {
      return null;
    }
  }
}
