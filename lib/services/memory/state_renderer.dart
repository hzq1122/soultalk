import 'package:soultalk/platform/platform_config.dart';
import '../../models/memory_state.dart';

/// Renders active [MemoryState] items into a compact natural-language
/// block for injection into the system prompt.
class StateRenderer {
  final PlatformConfig _config;

  StateRenderer([PlatformConfig? config])
      : _config = config ?? PlatformConfig.current;

  /// Render state items grouped by [slotType], respecting the character budget.
  String render(List<MemoryState> items) {
    if (items.isEmpty) return '';

    final activeItems = items.where((s) => s.status == 'active' && s.slotValue.trim().isNotEmpty).toList();
    if (activeItems.isEmpty) return '';

    final buffer = StringBuffer();
    buffer.writeln('[当前状态]');

    final typeGroups = <String, List<MemoryState>>{};
    for (final item in activeItems) {
      typeGroups.putIfAbsent(item.slotType, () => []).add(item);
    }

    var budget = _config.hotContextMaxChars;
    for (final group in typeGroups.entries) {
      for (final item in group.value) {
        final line = '- ${item.slotName}：${item.slotValue}';
        if (buffer.length + line.length + 1 > budget) break;
        buffer.writeln(line);
      }
    }

    final text = buffer.toString().trim();
    return text == '[当前状态]' ? '' : text;
  }
}
