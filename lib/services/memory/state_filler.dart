import 'package:uuid/uuid.dart';
import '../../models/memory_state.dart';
import '../database/memory_state_dao.dart';

/// Extracts state board updates from AI responses.
///
/// Parses LLM output for state changes in the format:
/// [STATE:slot_name] value
class StateFiller {
  final MemoryStateDao _dao;
  static const _uuid = Uuid();

  const StateFiller(this._dao);

  Future<List<MemoryState>> fillFromResponse(
    String contactId,
    String aiResponse,
  ) async {
    final updates = _parseStateUpdates(aiResponse);
    if (updates.isEmpty) return [];

    final now = DateTime.now();
    final states = <MemoryState>[];

    for (final update in updates) {
      final state = MemoryState(
        id: _uuid.v4(),
        contactId: contactId,
        slotName: update.key,
        slotValue: update.value,
        slotType: 'text',
        status: 'active',
        confidence: update.confidence,
        updatedAt: now,
      );
      await _dao.upsert(state);
      states.add(state);
    }

    return states;
  }

  List<_StateUpdate> _parseStateUpdates(String response) {
    final updates = <_StateUpdate>[];
    final regex = RegExp(r'\[STATE:(\w+)\]\s*(.+?)(?:\s*\(confidence:\s*([\d.]+)\))?(?=\n|$)', multiLine: true);
    for (final match in regex.allMatches(response)) {
      final key = match.group(1) ?? '';
      final value = (match.group(2) ?? '').trim();
      final confidence = double.tryParse(match.group(3) ?? '') ?? 0.7;
      if (key.isNotEmpty && value.isNotEmpty) {
        updates.add(_StateUpdate(key, value, confidence));
      }
    }
    return updates;
  }
}

class _StateUpdate {
  final String key;
  final String value;
  final double confidence;
  const _StateUpdate(this.key, this.value, this.confidence);
}
