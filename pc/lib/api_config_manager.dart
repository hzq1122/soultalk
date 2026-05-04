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
  final String apiKey;
  final String? baseUrl;

  const ApiConfig({
    required this.id,
    required this.name,
    required this.provider,
    required this.model,
    required this.apiKey,
    this.baseUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'provider': provider,
      'model': model,
      'apiKey': apiKey,
      'baseUrl': baseUrl,
    };
  }

  factory ApiConfig.fromJson(Map<String, dynamic> json) {
    return ApiConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      provider: json['provider'] as String,
      model: json['model'] as String,
      apiKey: json['apiKey'] as String,
      baseUrl: json['baseUrl'] as String?,
    );
  }
}
