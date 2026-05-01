import 'platform_config.dart';

class MobilePlatformConfig implements PlatformConfig {
  const MobilePlatformConfig();

  @override
  String get dataDirBase => 'app_flutter';

  @override
  int get hotContextMaxChars => 600;

  @override
  int get apiTimeoutSeconds => 15;

  @override
  int get retrievalTopK => 3;

  @override
  int get dbBatchSize => 100;

  @override
  int get minUserTextLength => 4;

  @override
  int get retrievalEveryNTurns => 8;

  @override
  double get stateConfidenceTrigger => 0.65;

  @override
  double get importanceApproveThreshold => 0.7;

  @override
  double get confidenceApproveThreshold => 0.85;
}
