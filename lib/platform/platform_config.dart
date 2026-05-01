import 'dart:io' show Platform;
import 'platform_config_mobile.dart';
import 'platform_config_desktop.dart';

/// Abstract platform configuration.
///
/// Use [PlatformConfig.current] to get the runtime-appropriate instance.
abstract class PlatformConfig {
  static final PlatformConfig current = _createPlatformConfig();

  /// Data directory path for the current platform.
  String get dataDirBase;

  /// Max characters for hot context (state board) injection in prompt.
  int get hotContextMaxChars;

  /// Timeout in seconds for HTTP API calls.
  int get apiTimeoutSeconds;

  /// Number of top memory cards to retrieve.
  int get retrievalTopK;

  /// Max records per batch DB operation.
  int get dbBatchSize;

  /// Minimum user input length to trigger retrieval gate checks.
  int get minUserTextLength;

  /// Periodic retrieval every N turns.
  int get retrievalEveryNTurns;

  /// Trigger retrieval when avg state confidence drops below this.
  double get stateConfidenceTrigger;

  /// Threshold for auto-approving a memory card (importance).
  double get importanceApproveThreshold;

  /// Threshold for auto-approving a memory card (confidence).
  double get confidenceApproveThreshold;

  static PlatformConfig _createPlatformConfig() {
    if (Platform.isAndroid || Platform.isIOS) {
      return MobilePlatformConfig();
    }
    return DesktopPlatformConfig();
  }
}
