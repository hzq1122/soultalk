import 'connection_manager.dart';

/// 下发 API 配置给 PC 端
class ApiConfigSender {
  /// 发送 API 配置给指定设备
  Future<void> sendConfig(
    String deviceId,
    ConnectionManager connectionManager,
  ) async {
    // 【推测】实际实现需要从数据库读取 API 配置
    // 这里返回模拟数据结构
    final configs = await _getEnabledConfigs();

    connectionManager.sendMessage(deviceId, {
      'type': 'api_config',
      'configs': configs,
    });
  }

  /// 广播配置更新给所有已连接设备
  Future<void> broadcastConfigUpdate(
    ConnectionManager connectionManager,
  ) async {
    final configs = await _getEnabledConfigs();

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

  Future<List<Map<String, dynamic>>> _getEnabledConfigs() async {
    // 【推测】实际实现需要从数据库读取
    // 这里返回空列表，实际应该读取 api_config 表
    return [];
  }
}
