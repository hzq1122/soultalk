import 'platform_config.dart';

class DesktopPlatformConfig implements PlatformConfig {
  const DesktopPlatformConfig();

  @override
  String get dataDirBase => 'app_flutter';

  @override
  int get hotContextMaxChars => 1200;

  @override
  int get apiTimeoutSeconds => 10;

  @override
  int get retrievalTopK => 5;

  @override
  int get dbBatchSize => 500;

  @override
  int get minUserTextLength => 3;

  @override
  int get retrievalEveryNTurns => 6;

  @override
  double get stateConfidenceTrigger => 0.6;

  @override
  double get importanceApproveThreshold => 0.65;

  @override
  double get confidenceApproveThreshold => 0.8;
}
