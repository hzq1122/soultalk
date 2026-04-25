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
    buffer.writeln('[Character Memory Table]');

    final categories = <String, List<MemoryEntry>>{};
    for (final entry in entries) {
      categories.putIfAbsent(entry.category, () => []).add(entry);
    }

    for (final cat in categories.entries) {
      buffer.writeln('## ${cat.key}');
      for (final e in cat.value) {
        buffer.writeln('- ${e.key}: ${e.value}');
      }
    }
    return buffer.toString().trim();
  }

  static List<MemoryEntry> fromLlmResponse(
      String contactId, String response) {
    final entries = <MemoryEntry>[];
    try {
      var jsonStr = response;
      final jsonMatch = RegExp(r'\[[\s\S]*\]').firstMatch(response);
      if (jsonMatch != null) {
        jsonStr = jsonMatch.group(0)!;
      }
      final list = jsonDecode(jsonStr) as List;
      for (final item in list) {
        if (item is Map<String, dynamic>) {
          entries.add(MemoryEntry(
            id: '',
            contactId: contactId,
            category: item['category'] as String? ?? '基本信息',
            key: item['key'] as String? ?? '',
            value: item['value'] as String? ?? '',
            updatedAt: DateTime.now(),
          ));
        }
      }
    } catch (_) {
      final lines = response.split('\n');
      String currentCategory = '基本信息';
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.startsWith('##')) {
          currentCategory = trimmed.replaceFirst(RegExp(r'^#+\s*'), '').trim();
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
