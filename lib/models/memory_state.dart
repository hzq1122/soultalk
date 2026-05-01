/// MemoryState — Hot layer: per-conversation state board entry.
///
/// Lightweight key-value pairs that update every turn and are injected
/// at the top of the prompt before any long-term memory retrieval.
class MemoryState {
  final String id;
  final String contactId;
  final String slotName;
  final String slotValue;
  final String slotType; // text, number, bool, enum, json
  final String status; // active, stale, locked
  final double confidence;
  final DateTime updatedAt;

  const MemoryState({
    required this.id,
    required this.contactId,
    required this.slotName,
    required this.slotValue,
    this.slotType = 'text',
    this.status = 'active',
    this.confidence = 0.5,
    required this.updatedAt,
  });

  MemoryState copyWith({
    String? id,
    String? contactId,
    String? slotName,
    String? slotValue,
    String? slotType,
    String? status,
    double? confidence,
    DateTime? updatedAt,
  }) {
    return MemoryState(
      id: id ?? this.id,
      contactId: contactId ?? this.contactId,
      slotName: slotName ?? this.slotName,
      slotValue: slotValue ?? this.slotValue,
      slotType: slotType ?? this.slotType,
      status: status ?? this.status,
      confidence: confidence ?? this.confidence,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toDbMap() => {
    'id': id,
    'contact_id': contactId,
    'slot_name': slotName,
    'slot_value': slotValue,
    'slot_type': slotType,
    'status': status,
    'confidence': confidence,
    'updated_at': updatedAt.toIso8601String(),
  };

  factory MemoryState.fromDbMap(Map<String, dynamic> map) {
    return MemoryState(
      id: map['id'] as String? ?? '',
      contactId: map['contact_id'] as String? ?? '',
      slotName: map['slot_name'] as String? ?? '',
      slotValue: map['slot_value'] as String? ?? '',
      slotType: map['slot_type'] as String? ?? 'text',
      status: map['status'] as String? ?? 'active',
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.5,
      updatedAt:
          DateTime.tryParse(map['updated_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'contact_id': contactId,
    'slot_name': slotName,
    'slot_value': slotValue,
    'slot_type': slotType,
    'status': status,
    'confidence': confidence,
    'updated_at': updatedAt.toIso8601String(),
  };
}
