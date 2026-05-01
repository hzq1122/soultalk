import 'platform_config.dart';

/// Stub config for environments where dart:io is unavailable (web, tests).
class StubPlatformConfig implements PlatformConfig {
  const StubPlatformConfig();

  @override
  String get dataDirBase => 'test_data';

  @override
  int get hotContextMaxChars => 800;

  @override
  int get apiTimeoutSeconds => 10;

  @override
  int get retrievalTopK => 3;

  @override
  int get dbBatchSize => 200;

  @override
  int get minUserTextLength => 4;

  @override
  int get retrievalEveryNTurns => 6;

  @override
  double get stateConfidenceTrigger => 0.65;

  @override
  double get importanceApproveThreshold => 0.7;

  @override
  double get confidenceApproveThreshold => 0.85;
}
