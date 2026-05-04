import 'package:soultalk/platform/platform_config.dart';
import '../../models/memory_card.dart';

/// Semi-automatic review policy for candidate memory cards.
///
/// Adapted from jiyi1's review_policy.py. Determines whether a candidate
/// should be auto-approved, held pending, or rejected.
class ReviewPolicy {
  final PlatformConfig _config;

  ReviewPolicy([PlatformConfig? config])
    : _config = config ?? PlatformConfig.current;

  ReviewAction review(MemoryCard card) {
    // Reject trivial content
    if (card.importance < 0.3) return ReviewAction.reject;

    // Reject if LLM explicitly marked for rejection
    if (card.tags.contains('suggested_action:reject')) {
      return ReviewAction.reject;
    }

    // Pending if LLM explicitly marked
    if (card.tags.contains('suggested_action:pending')) {
      return ReviewAction.pending;
    }

    // Pending high-risk types
    if (_highRiskTypes.contains(card.cardType)) return ReviewAction.pending;

    // Auto-approve from LLM suggestion
    if (card.tags.contains('suggested_action:auto_approve') &&
        card.importance >= _config.importanceApproveThreshold &&
        card.confidence >= _config.confidenceApproveThreshold) {
      return ReviewAction.approve;
    }

    // Auto-approve low-risk types with strong scores
    if (_lowRiskTypes.contains(card.cardType) &&
        card.importance >= _config.importanceApproveThreshold &&
        card.confidence >= _config.confidenceApproveThreshold) {
      return ReviewAction.approve;
    }

    // Auto-approve universal high quality
    if (card.importance >= _config.importanceApproveThreshold &&
        card.confidence >= _config.confidenceApproveThreshold) {
      return ReviewAction.approve;
    }

    // Low confidence → pending
    if (card.confidence < 0.6) return ReviewAction.pending;

    return ReviewAction.pending;
  }

  static const _highRiskTypes = {
    'boundary',
    'preference',
    'relationship',
    'world_state',
    'character_state',
  };
  static const _lowRiskTypes = {
    'fact',
    'event',
    'roleplay_rule',
    'speech_style',
    'persona_rule',
    'speech_habit',
    'misc',
  };
}

enum ReviewAction { approve, pending, reject }
