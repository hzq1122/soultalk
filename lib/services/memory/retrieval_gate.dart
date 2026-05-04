import 'package:soultalk/platform/platform_config.dart';
import '../../models/memory_state.dart';

/// Decision result from the retrieval gate.
class GateDecision {
  final bool shouldRetrieve;
  final String reason;
  final List<String> reasons;
  final int stateItemCount;
  final double? avgStateConfidence;

  const GateDecision({
    required this.shouldRetrieve,
    required this.reason,
    required this.reasons,
    required this.stateItemCount,
    this.avgStateConfidence,
  });
}

/// Rule-based gate that decides whether long-term memory retrieval is needed.
///
/// Avoids expensive retrieval on every turn by checking multiple triggers:
/// new session, keywords, periodic refresh, low state confidence.
class RetrievalGate {
  final PlatformConfig _config;
  final List<String> _triggerKeywords;

  RetrievalGate({PlatformConfig? config, List<String>? triggerKeywords})
    : _config = config ?? PlatformConfig.current,
      _triggerKeywords = triggerKeywords ?? const [];

  GateDecision decide({
    required String userText,
    int? turnIndex,
    List<MemoryState> stateItems = const [],
    String mode = 'auto',
  }) {
    final m = mode.toLowerCase();
    final stats = _computeStats(stateItems);

    if (m == 'always') {
      return GateDecision(
        shouldRetrieve: true,
        reason: 'mode_always',
        reasons: ['mode_always'],
        stateItemCount: stats.itemCount,
        avgStateConfidence: stats.avgConfidence,
      );
    }
    if (m == 'never') {
      return GateDecision(
        shouldRetrieve: false,
        reason: 'mode_never',
        reasons: ['mode_never'],
        stateItemCount: stats.itemCount,
        avgStateConfidence: stats.avgConfidence,
      );
    }

    final text = userText.trim();
    final reasons = <String>[];

    // New session trigger
    if (turnIndex == null || turnIndex <= 0) {
      reasons.add('new_session');
    }

    // Keyword trigger
    for (final kw in _triggerKeywords) {
      if (kw.isNotEmpty && text.contains(kw)) {
        reasons.add('keyword:$kw');
        break;
      }
    }

    // Periodic refresh
    final everyN = _config.retrievalEveryNTurns;
    if (everyN > 0 &&
        turnIndex != null &&
        turnIndex > 0 &&
        turnIndex % everyN == 0) {
      reasons.add('periodic:$everyN');
    }

    // Low state confidence trigger
    if (stateItems.isNotEmpty && stats.avgConfidence != null) {
      if (stats.avgConfidence! < _config.stateConfidenceTrigger) {
        reasons.add('low_state_confidence');
      }
    }

    if (reasons.isNotEmpty) {
      return GateDecision(
        shouldRetrieve: true,
        reason: reasons.first,
        reasons: reasons,
        stateItemCount: stats.itemCount,
        avgStateConfidence: stats.avgConfidence,
      );
    }

    // Skip: text too short
    if (text.length < _config.minUserTextLength) {
      return GateDecision(
        shouldRetrieve: false,
        reason: 'short_text',
        reasons: ['short_text'],
        stateItemCount: stats.itemCount,
        avgStateConfidence: stats.avgConfidence,
      );
    }

    // Skip: state board is sufficient
    if (stateItems.isNotEmpty) {
      return GateDecision(
        shouldRetrieve: false,
        reason: 'state_sufficient',
        reasons: ['state_sufficient'],
        stateItemCount: stats.itemCount,
        avgStateConfidence: stats.avgConfidence,
      );
    }

    return GateDecision(
      shouldRetrieve: true,
      reason: 'no_state_fallback',
      reasons: ['no_state_fallback'],
      stateItemCount: stats.itemCount,
      avgStateConfidence: stats.avgConfidence,
    );
  }

  _StateStats _computeStats(List<MemoryState> items) {
    final active = items.where((s) => s.status == 'active').toList();
    if (active.isEmpty) return _StateStats(0, null);
    final avg =
        active.fold<double>(0, (sum, s) => sum + s.confidence) / active.length;
    return _StateStats(active.length, avg);
  }
}

class _StateStats {
  final int itemCount;
  final double? avgConfidence;
  const _StateStats(this.itemCount, this.avgConfidence);
}
