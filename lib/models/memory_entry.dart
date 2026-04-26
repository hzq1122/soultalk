import 'dart:convert';

class MemoryEntry {
  final String id;
  final String contactId;
  final String category;
  final String key;
  final String value;
  final DateTime updatedAt;

  const MemoryEntry({
    required this.id,
    required this.contactId,
    required this.category,
    required this.key,
    required this.value,
    required this.updatedAt,
  });

  MemoryEntry copyWith({
    String? id,
    String? contactId,
    String? category,
    String? key,
    String? value,
    DateTime? updatedAt,
  }) {
    return MemoryEntry(
      id: id ?? this.id,
      contactId: contactId ?? this.contactId,
      category: category ?? this.category,
      key: key ?? this.key,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'contact_id': contactId,
      'category': category,
      'key': key,
      'value': value,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory MemoryEntry.fromDbMap(Map<String, dynamic> map) {
    return MemoryEntry(
      id: map['id'] as String,
      contactId: map['contact_id'] as String,
      category: map['category'] as String,
      key: map['key'] as String,
      value: map['value'] as String,
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'category': category,
        'key': key,
        'value': value,
      };

  static String tableToPrompt(List<MemoryEntry> entries) {
    if (entries.isEmpty) return '';
    final buffer = StringBuffer();

    // 渲染为自然记忆，不给用户看到表格痕迹
    buffer.writeln('你对当前对话伙伴已知的信息：');

    final categories = <String, List<MemoryEntry>>{};
    for (final entry in entries) {
      categories.putIfAbsent(entry.category, () => []).add(entry);
    }

    for (final cat in categories.entries) {
      final items = cat.value.map((e) {
        if (e.key == '备注' || e.key == 'note') return e.value;
        return '${e.key}：${e.value}';
      }).join('；');
      buffer.writeln('- ${cat.key}：$items');
    }
    return buffer.toString().trim();
  }

  static List<MemoryEntry> fromLlmResponse(
      String contactId, String response) {
    final entries = <MemoryEntry>[];
    try {
      // Strip markdown code fences if present
      var jsonStr = response.trim();
      final fenceMatch = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(jsonStr);
      if (fenceMatch != null) {
        jsonStr = fenceMatch.group(1)!.trim();
      }
      // Extract the outermost JSON array
      final firstBracket = jsonStr.indexOf('[');
      final lastBracket = jsonStr.lastIndexOf(']');
      if (firstBracket != -1 && lastBracket > firstBracket) {
        jsonStr = jsonStr.substring(firstBracket, lastBracket + 1);
      }
      final list = jsonDecode(jsonStr) as List;
      for (final item in list) {
        if (item is Map<String, dynamic>) {
          final category = (item['category'] as String?) ?? '其他';
          final key = (item['key'] as String?) ?? '';
          final value = (item['value'] as String?) ?? '';
          if (key.isNotEmpty && value.isNotEmpty) {
            entries.add(MemoryEntry(
              id: '',
              contactId: contactId,
              category: category,
              key: key,
              value: value,
              updatedAt: DateTime.now(),
            ));
          }
        }
      }
    } catch (_) {
      // Fallback: parse markdown-style output
      final lines = response.split('\n');
      String currentCategory = '其他';
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.startsWith('##') || trimmed.startsWith('**') && trimmed.endsWith('**')) {
          currentCategory = trimmed
              .replaceFirst(RegExp(r'^#+\s*'), '')
              .replaceAll('*', '')
              .trim();
        } else if (trimmed.startsWith('-') && trimmed.contains(':')) {
          final colonIdx = trimmed.indexOf(':');
          final key = trimmed.substring(1, colonIdx).trim();
          final value = trimmed.substring(colonIdx + 1).trim();
          if (key.isNotEmpty && value.isNotEmpty) {
            entries.add(MemoryEntry(
              id: '',
              contactId: contactId,
              category: currentCategory,
              key: key,
              value: value,
              updatedAt: DateTime.now(),
            ));
          }
        }
      }
    }
    return entries;
  }
}
