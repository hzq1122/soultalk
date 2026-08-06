import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// API 配置管理器 - 支持独立配置和跟随手机模式
class ApiConfigManager {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // 存储键
  static const String _keyMode = 'api_config_mode';
  static const String _keyConfigs = 'api_configs';
  static const String _keyActiveId = 'active_api_config_id';

  ApiConfigMode _mode = ApiConfigMode.followPhone;
  List<ApiConfig> _localConfigs = [];
  List<ApiConfig> _remoteConfigs = []; // 来自手机的配置
  String? _activeConfigId;

  ApiConfigMode get mode => _mode;
  List<ApiConfig> get localConfigs => List.unmodifiable(_localConfigs);
  List<ApiConfig> get remoteConfigs => List.unmodifiable(_remoteConfigs);
  String? get activeConfigId => _activeConfigId;

  /// 获取当前激活的配置
  ApiConfig? get activeConfig {
    if (_mode == ApiConfigMode.followPhone) {
      return _remoteConfigs.isNotEmpty ? _remoteConfigs.first : null;
    }
    return _localConfigs.where((c) => c.id == _activeConfigId).firstOrNull;
  }

  /// 初始化（platform storage 不可用时降级为空配置）
  Future<void> init() async {
    try {
      await _loadMode();
      await _loadLocalConfigs();
      await _loadActiveConfigId();
    } catch (_) {
      // flutter_secure_storage 在测试环境或某些平台不可用
    }
  }

  /// 切换模式
  Future<void> switchMode(ApiConfigMode newMode) async {
    _mode = newMode;
    await _storage.write(key: _keyMode, value: newMode.name);
  }

  /// 添加本地配置
  Future<void> addLocalConfig(ApiConfig config) async {
    _localConfigs.add(config);
    await _saveLocalConfigs();

    if (_activeConfigId == null) {
      _activeConfigId = config.id;
      await _saveActiveConfigId();
    }
  }

  /// 更新本地配置
  Future<void> updateLocalConfig(ApiConfig config) async {
    final index = _localConfigs.indexWhere((c) => c.id == config.id);
    if (index >= 0) {
      _localConfigs[index] = config;
      await _saveLocalConfigs();
    }
  }

  /// 删除本地配置
  Future<void> removeLocalConfig(String id) async {
    _localConfigs.removeWhere((c) => c.id == id);
    await _saveLocalConfigs();

    if (_activeConfigId == id) {
      _activeConfigId = _localConfigs.isNotEmpty
          ? _localConfigs.first.id
          : null;
      await _saveActiveConfigId();
    }
  }

  /// 设置激活配置
  Future<void> setActiveConfig(String id) async {
    _activeConfigId = id;
    await _saveActiveConfigId();
  }

  /// 接收手机端配置
  void receiveRemoteConfigs(List<ApiConfig> configs) {
    if (_mode == ApiConfigMode.followPhone) {
      _remoteConfigs = configs;
    }
  }

  /// 清除远程配置
  void clearRemoteConfigs() {
    _remoteConfigs.clear();
  }

  /// 收到 clear_api 指令时调用，清除远程配置和激活状态
  void clearAllRemoteConfigs() {
    _remoteConfigs.clear();
    _activeConfigId = null;
  }

  Future<void> _loadMode() async {
    final modeStr = await _storage.read(key: _keyMode);
    if (modeStr != null) {
      _mode = ApiConfigMode.values.firstWhere(
        (m) => m.name == modeStr,
        orElse: () => ApiConfigMode.followPhone,
      );
    }
  }

  Future<void> _loadLocalConfigs() async {
    final json = await _storage.read(key: _keyConfigs);
    if (json != null) {
      try {
        final list = jsonDecode(json) as List<dynamic>;
        _localConfigs = list
            .map((item) => ApiConfig.fromJson(item as Map<String, dynamic>))
            .toList();
      } catch (e) {
        _localConfigs = [];
      }
    }
  }

  Future<void> _saveLocalConfigs() async {
    final json = jsonEncode(_localConfigs.map((c) => c.toJson()).toList());
    await _storage.write(key: _keyConfigs, value: json);
  }

  Future<void> _loadActiveConfigId() async {
    _activeConfigId = await _storage.read(key: _keyActiveId);
  }

  Future<void> _saveActiveConfigId() async {
    if (_activeConfigId != null) {
      await _storage.write(key: _keyActiveId, value: _activeConfigId);
    } else {
      await _storage.delete(key: _keyActiveId);
    }
  }
}

/// API 配置模式
enum ApiConfigMode {
  followPhone, // 跟随手机
  independent, // 独立配置
}

/// API 配置
class ApiConfig {
  final String id;
  final String name;
  final String provider;
  final String model;

  /// 手机下发的配置不含 api_key（凭据不同步），
  /// 因此该字段可空；空值表示「需通过手机代理调用」。
  final String? apiKey;
  final String? baseUrl;
  final int? maxTokens;
  final double? temperature;
  final bool? streamEnabled;
  final bool? thinkingEnabled;
  final String? reasoningEffort;

  const ApiConfig({
    required this.id,
    required this.name,
    required this.provider,
    required this.model,
    this.apiKey,
    this.baseUrl,
    this.maxTokens,
    this.temperature,
    this.streamEnabled,
    this.thinkingEnabled,
    this.reasoningEffort,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'provider': provider,
      'model': model,
      'apiKey': apiKey,
      'baseUrl': baseUrl,
      'maxTokens': maxTokens,
      'temperature': temperature,
      'streamEnabled': streamEnabled,
      'thinkingEnabled': thinkingEnabled,
      'reasoningEffort': reasoningEffort,
    };
  }

  /// 容错解析：同时接受 camelCase（手机 DTO）与 snake_case（旧协议）
  /// 字段名；apiKey 可空（手机端绝不发送凭据）。解析失败返回 null，
  /// 调用方跳过该条而不是抛类型异常导致整个配置列表丢失。
  static ApiConfig? tryFromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final provider = json['provider'];
    final model = json['model'];
    if (id is! String || name is! String || provider is! String) return null;
    if (model is! String) return null;
    // 所有字段用类型守卫转换：值存在但类型不符时返回 null（跳过该条），
    // 而不是抛 TypeError 中断整个配置列表处理
    final apiKey = json['apiKey'] ?? json['api_key'];
    final baseUrl = json['baseUrl'] ?? json['base_url'];
    final maxTokens = json['maxTokens'] ?? json['max_tokens'];
    final effort = json['reasoningEffort'] ?? json['reasoning_effort'];
    final rawTemperature = json['temperature'] ?? json['temperature'];
    return ApiConfig(
      id: id,
      name: name,
      provider: provider,
      model: model,
      apiKey: apiKey is String ? apiKey : null,
      baseUrl: baseUrl is String ? baseUrl : null,
      maxTokens: maxTokens is int ? maxTokens : null,
      temperature: rawTemperature is num ? rawTemperature.toDouble() : null,
      // 旧协议（原始 DB 行）布尔列为 int（1/0），统一转 bool
      streamEnabled: _asBool(json['streamEnabled'] ?? json['stream_enabled']),
      thinkingEnabled: _asBool(
        json['thinkingEnabled'] ?? json['thinking_enabled'],
      ),
      reasoningEffort: effort is String ? effort : null,
    );
  }

  static bool? _asBool(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    return null;
  }

  factory ApiConfig.fromJson(Map<String, dynamic> json) {
    final parsed = tryFromJson(json);
    if (parsed == null) {
      throw FormatException('Invalid api config json: $json');
    }
    return parsed;
  }
}
