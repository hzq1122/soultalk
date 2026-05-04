/// PC 设备信息模型
class PcDevice {
  final String deviceId;
  final String name;
  final DateTime connectedAt;
  final DateTime lastActiveAt;
  final String? ip;

  PcDevice({
    required this.deviceId,
    required this.name,
    DateTime? connectedAt,
    DateTime? lastActiveAt,
    this.ip,
  })  : connectedAt = connectedAt ?? DateTime.now(),
        lastActiveAt = lastActiveAt ?? DateTime.now();

  PcDevice copyWith({
    String? deviceId,
    String? name,
    DateTime? connectedAt,
    DateTime? lastActiveAt,
    String? ip,
  }) {
    return PcDevice(
      deviceId: deviceId ?? this.deviceId,
      name: name ?? this.name,
      connectedAt: connectedAt ?? this.connectedAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      ip: ip ?? this.ip,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'name': name,
      'connectedAt': connectedAt.toIso8601String(),
      'lastActiveAt': lastActiveAt.toIso8601String(),
      'ip': ip,
    };
  }

  factory PcDevice.fromJson(Map<String, dynamic> json) {
    return PcDevice(
      deviceId: json['deviceId'] as String,
      name: json['name'] as String,
      connectedAt: DateTime.parse(json['connectedAt'] as String),
      lastActiveAt: DateTime.parse(json['lastActiveAt'] as String),
      ip: json['ip'] as String?,
    );
  }
}
