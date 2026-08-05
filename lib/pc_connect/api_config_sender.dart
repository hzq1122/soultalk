import 'package:shared_preferences/shared_preferences.dart';

import '../services/database/database_service.dart';
import 'connection_manager.dart';

/// 下发 API 配置给 PC 端。
/// 安全约束：绝不发送 api_key（LanSync 不同步任何凭据/secrets）；
/// 受「允许 PC 使用手机 API」开关（prefs `pc_allow_api`）控制。
class ApiConfigSender {
  final DatabaseService? _dbService;

  ApiConfigSender({DatabaseService? dbService}) : _dbService = dbService;

  /// 发送 API 配置给指定设备
  Future<void> sendConfig(
    String deviceId,
    ConnectionManager connectionManager,
  ) async {
    if (!await _allowApiSharing()) {
      sendConfigDisabled(deviceId, connectionManager);
      return;
    }
    final configs = await getConfigsForSync();

    connectionManager.sendMessage(deviceId, {
      'type': 'api_config',
      'configs': configs,
    });
  }

  /// 广播配置更新给所有已连接设备
  Future<void> broadcastConfigUpdate(
    ConnectionManager connectionManager,
  ) async {
    if (!await _allowApiSharing()) return;
    final configs = await getConfigsForSync();

    connectionManager.broadcast({
      'type': 'api_config',
      'update': true,
      'configs': configs,
    });
  }

  /// 通知 PC API 配置已禁用
  void sendConfigDisabled(
    String deviceId,
    ConnectionManager connectionManager,
  ) {
    connectionManager.sendMessage(deviceId, {'type': 'api_config_disabled'});
  }

  /// 清除 PC 端的 API 配置
  void clearRemoteConfig(String deviceId, ConnectionManager connectionManager) {
    connectionManager.sendMessage(deviceId, {'type': 'clear_api'});
  }

  Future<bool> _allowApiSharing() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('pc_allow_api') ?? true;
  }

  /// 读取可下发的 API 配置（公开供测试与诊断使用）。
  /// 安全：剥离 api_key 等凭据字段，只保留非敏感配置。
  Future<List<Map<String, dynamic>>> getConfigsForSync() async {
    final db = await (_dbService ?? DatabaseService()).database;
    final rows = await db.query('api_configs');
    return rows
        .map((row) => {...row}..removeWhere((key, _) => key == 'api_key'))
        .toList();
  }
}
