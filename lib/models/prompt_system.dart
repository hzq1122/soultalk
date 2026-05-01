import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

enum PromptInjectionPosition {
  beforeMain,
  afterMain,
  beforeChar,
  afterChar,
  beforeHistory,
  afterHistory,
  absolute,
}

enum PromptInjectionStrategy { relative, absolute }

class PromptEntry {
  final String id;
  final String name;
  final String content;
  final String role;
  final bool enabled;
  final PromptInjectionPosition position;
  final PromptInjectionStrategy strategy;
  final int depth;
  final int priority;

  const PromptEntry({
    required this.id,
    required this.name,
    required this.content,
    this.role = 'system',
    this.enabled = true,
    this.position = PromptInjectionPosition.afterMain,
    this.strategy = PromptInjectionStrategy.relative,
    this.depth = 0,
    this.priority = 0,
  });

  PromptEntry copyWith({
    String? id,
    String? name,
    String? content,
    String? role,
    bool? enabled,
    PromptInjectionPosition? position,
    PromptInjectionStrategy? strategy,
    int? depth,
    int? priority,
  }) => PromptEntry(
    id: id ?? this.id,
    name: name ?? this.name,
    content: content ?? this.content,
    role: role ?? this.role,
    enabled: enabled ?? this.enabled,
    position: position ?? this.position,
    strategy: strategy ?? this.strategy,
    depth: depth ?? this.depth,
    priority: priority ?? this.priority,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'content': content,
    'role': role,
    'enabled': enabled,
    'position': position.index,
    'strategy': strategy.index,
    'depth': depth,
    'priority': priority,
  };

  factory PromptEntry.fromJson(Map<String, dynamic> json) => PromptEntry(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    content: json['content'] as String? ?? '',
    role: json['role'] as String? ?? 'system',
    enabled: json['enabled'] as bool? ?? true,
    position: _parsePosition(json['position'] as int?),
    strategy: _parseStrategy(json['strategy'] as int?),
    depth: json['depth'] as int? ?? 0,
    priority: json['priority'] as int? ?? 0,
  );

  static PromptInjectionPosition _parsePosition(int? index) {
    if (index != null &&
        index >= 0 &&
        index < PromptInjectionPosition.values.length) {
      return PromptInjectionPosition.values[index];
    }
    return PromptInjectionPosition.afterMain;
  }

  static PromptInjectionStrategy _parseStrategy(int? index) {
    if (index != null &&
        index >= 0 &&
        index < PromptInjectionStrategy.values.length) {
      return PromptInjectionStrategy.values[index];
    }
    return PromptInjectionStrategy.relative;
  }
}

class WorldInfoEntry {
  final String id;
  final String contactId;
  final String key;
  final List<String> keySecondary;
  final String content;
  final String comment;
  final bool enabled;
  final bool constant;
  final int position;
  final int priority;
  final String group;
  final int depth;
  final bool selective;
  final String caseSensitive;

  const WorldInfoEntry({
    required this.id,
    this.contactId = '',
    required this.key,
    this.keySecondary = const [],
    required this.content,
    this.comment = '',
    this.enabled = true,
    this.constant = false,
    this.position = 0,
    this.priority = 0,
    this.group = '',
    this.depth = 0,
    this.selective = false,
    this.caseSensitive = 'none',
  });

  WorldInfoEntry copyWith({
    String? id,
    String? contactId,
    String? key,
    List<String>? keySecondary,
    String? content,
    String? comment,
    bool? enabled,
    bool? constant,
    int? position,
    int? priority,
    String? group,
    int? depth,
    bool? selective,
    String? caseSensitive,
  }) => WorldInfoEntry(
    id: id ?? this.id,
    contactId: contactId ?? this.contactId,
    key: key ?? this.key,
    keySecondary: keySecondary ?? this.keySecondary,
    content: content ?? this.content,
    comment: comment ?? this.comment,
    enabled: enabled ?? this.enabled,
    constant: constant ?? this.constant,
    position: position ?? this.position,
    priority: priority ?? this.priority,
    group: group ?? this.group,
    depth: depth ?? this.depth,
    selective: selective ?? this.selective,
    caseSensitive: caseSensitive ?? this.caseSensitive,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'contactId': contactId,
    'key': key,
    'keySecondary': keySecondary,
    'content': content,
    'comment': comment,
    'enabled': enabled,
    'constant': constant,
    'position': position,
    'priority': priority,
    'group': group,
    'depth': depth,
    'selective': selective,
    'caseSensitive': caseSensitive,
  };

  factory WorldInfoEntry.fromJson(Map<String, dynamic> json) => WorldInfoEntry(
    id: json['id'] as String? ?? '',
    contactId: json['contactId'] as String? ?? '',
    key: json['key'] as String? ?? '',
    keySecondary:
        (json['keySecondary'] as List?)?.map((e) => e.toString()).toList() ??
        [],
    content: json['content'] as String? ?? '',
    comment: json['comment'] as String? ?? '',
    enabled: json['enabled'] as bool? ?? true,
    constant: json['constant'] as bool? ?? false,
    position: json['position'] as int? ?? 0,
    priority: json['priority'] as int? ?? 0,
    group: json['group'] as String? ?? '',
    depth: json['depth'] as int? ?? 0,
    selective: json['selective'] as bool? ?? false,
    caseSensitive: json['caseSensitive'] as String? ?? 'none',
  );

  bool matchesKey(String text) {
    if (constant) return true;
    if (key.isEmpty) return false;

    final keys = key.split(',').map((k) => k.trim()).where((k) => k.isNotEmpty);

    for (final k in keys) {
      final isCaseSensitive = caseSensitive == 'yes';
      final found = isCaseSensitive
          ? text.contains(k)
          : text.toLowerCase().contains(k.toLowerCase());
      if (found) {
        if (selective && keySecondary.isNotEmpty) {
          final secondaryMatch = keySecondary.any((sk) {
            final skTrimmed = sk.trim();
            if (skTrimmed.isEmpty) return false;
            return isCaseSensitive
                ? text.contains(skTrimmed)
                : text.toLowerCase().contains(skTrimmed.toLowerCase());
          });
          if (!secondaryMatch) return false;
        }
        return true;
      }
    }
    return false;
  }
}

class ContextTemplate {
  final String id;
  final String name;
  final String storyString;
  final bool enabled;

  const ContextTemplate({
    required this.id,
    required this.name,
    this.storyString =
        '{{system}}\n{{wiBefore}}\n{{description}}\n{{personality}}\n{{scenario}}\n{{wiAfter}}',
    this.enabled = true,
  });

  ContextTemplate copyWith({
    String? id,
    String? name,
    String? storyString,
    bool? enabled,
  }) => ContextTemplate(
    id: id ?? this.id,
    name: name ?? this.name,
    storyString: storyString ?? this.storyString,
    enabled: enabled ?? this.enabled,
  );

  String render(Map<String, String> variables) {
    var result = storyString;
    for (final entry in variables.entries) {
      result = result.replaceAll('{{${entry.key}}}', entry.value);
    }
    result = result.replaceAll(RegExp(r'\{\{[^}]+\}\}'), '');
    return result.trim();
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'storyString': storyString,
    'enabled': enabled,
  };

  factory ContextTemplate.fromJson(
    Map<String, dynamic> json,
  ) => ContextTemplate(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? 'Default',
    storyString:
        json['storyString'] as String? ??
        '{{system}}\n{{wiBefore}}\n{{description}}\n{{personality}}\n{{scenario}}\n{{wiAfter}}',
    enabled: json['enabled'] as bool? ?? true,
  );
}

class PromptPreset {
  final String id;
  final String name;
  final String mainPrompt;
  final String secondaryPrompt;
  final String postHistoryInstructions;
  final ContextTemplate contextTemplate;
  final List<PromptEntry> customPrompts;
  final bool enabled;

  const PromptPreset({
    required this.id,
    required this.name,
    this.mainPrompt = '',
    this.secondaryPrompt = '',
    this.postHistoryInstructions = '',
    this.contextTemplate = const ContextTemplate(
      id: 'default',
      name: 'Default',
    ),
    this.customPrompts = const [],
    this.enabled = true,
  });

  PromptPreset copyWith({
    String? id,
    String? name,
    String? mainPrompt,
    String? secondaryPrompt,
    String? postHistoryInstructions,
    ContextTemplate? contextTemplate,
    List<PromptEntry>? customPrompts,
    bool? enabled,
  }) => PromptPreset(
    id: id ?? this.id,
    name: name ?? this.name,
    mainPrompt: mainPrompt ?? this.mainPrompt,
    secondaryPrompt: secondaryPrompt ?? this.secondaryPrompt,
    postHistoryInstructions:
        postHistoryInstructions ?? this.postHistoryInstructions,
    contextTemplate: contextTemplate ?? this.contextTemplate,
    customPrompts: customPrompts ?? this.customPrompts,
    enabled: enabled ?? this.enabled,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'mainPrompt': mainPrompt,
    'secondaryPrompt': secondaryPrompt,
    'postHistoryInstructions': postHistoryInstructions,
    'contextTemplate': contextTemplate.toJson(),
    'customPrompts': customPrompts.map((p) => p.toJson()).toList(),
    'enabled': enabled,
  };

  factory PromptPreset.fromJson(Map<String, dynamic> json) => PromptPreset(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? 'Unnamed',
    mainPrompt: json['mainPrompt'] as String? ?? '',
    secondaryPrompt: json['secondaryPrompt'] as String? ?? '',
    postHistoryInstructions: json['postHistoryInstructions'] as String? ?? '',
    contextTemplate: json['contextTemplate'] != null
        ? ContextTemplate.fromJson(
            json['contextTemplate'] as Map<String, dynamic>,
          )
        : const ContextTemplate(id: 'default', name: 'Default'),
    customPrompts:
        (json['customPrompts'] as List?)
            ?.map((p) => PromptEntry.fromJson(p as Map<String, dynamic>))
            .toList() ??
        [],
    enabled: json['enabled'] as bool? ?? true,
  );

  static Future<PromptPreset> load(SharedPreferences prefs, String key) async {
    final jsonStr = prefs.getString(key);
    if (jsonStr != null) {
      try {
        return PromptPreset.fromJson(
          jsonDecode(jsonStr) as Map<String, dynamic>,
        );
      } catch (_) {}
    }
    return PromptPreset(id: key, name: 'Default');
  }

  Future<void> save(SharedPreferences prefs, String key) async {
    await prefs.setString(key, jsonEncode(toJson()));
  }
}
