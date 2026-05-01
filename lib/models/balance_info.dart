/// Snapshot of an API balance / usage check.
class BalanceInfo {
  final double? total;
  final double? used;
  final double? remaining;
  final String? unit; // CNY, USD, tokens, credits
  final String? planName;
  final String? provider;
  final DateTime checkedAt;

  const BalanceInfo({
    this.total,
    this.used,
    this.remaining,
    this.unit,
    this.planName,
    this.provider,
    required this.checkedAt,
  });

  bool get hasData => remaining != null || total != null;

  Map<String, dynamic> toJson() => {
    'total': total,
    'used': used,
    'remaining': remaining,
    'unit': unit,
    'plan_name': planName,
    'provider': provider,
    'checked_at': checkedAt.toIso8601String(),
  };

  factory BalanceInfo.fromJson(Map<String, dynamic> map) {
    return BalanceInfo(
      total: (map['total'] as num?)?.toDouble(),
      used: (map['used'] as num?)?.toDouble(),
      remaining: (map['remaining'] as num?)?.toDouble(),
      unit: map['unit'] as String?,
      planName: map['plan_name'] as String?,
      provider: map['provider'] as String?,
      checkedAt:
          DateTime.tryParse(map['checked_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
