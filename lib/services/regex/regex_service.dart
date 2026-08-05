import '../../models/regex_script.dart';

class RegexService {
  const RegexService();

  /// 应用正则脚本。
  ///
  /// ST 语义：
  /// - [placement] 过滤脚本的 source（userInput/aiOutput/worldInfo/...）
  /// - [depth] 为当前消息在上下文中的深度（轮次）：minDepth/maxDepth
  ///   仅在提供 depth 时生效（ST 深度过滤）
  /// - [includePromptOnly] 为 false 时跳过 promptOnly 脚本
  ///   （ST ephemeral-prompt：仅注入 prompt，不改变 UI 显示文本）
  String applyScripts(
    String text,
    List<RegexScript> scripts,
    int placement, {
    int? depth,
    bool includePromptOnly = true,
  }) {
    var result = text;
    for (final script in scripts) {
      if (script.disabled) continue;
      if (!includePromptOnly && script.promptOnly) continue;
      if (!script.placement.contains(placement)) continue;
      if (depth != null) {
        if (script.minDepth != null && depth < script.minDepth!) continue;
        if (script.maxDepth != null && depth > script.maxDepth!) continue;
      }
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
