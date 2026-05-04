import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'models/pc_device.dart';

/// 管理已连接的 PC 设备
class ConnectionManager {
  final Map<String, _DeviceConnection> _connections = {};

  /// 获取已连接设备列表
  List<PcDevice> get connectedDevices =>
      _connections.values.map((c) => c.device).toList();

  /// 获取连接数量
  int get connectionCount => _connections.length;

  /// 添加设备
  void addDevice(String deviceId, WebSocketChannel channel) {
    _connections[deviceId] = _DeviceConnection(
      device: PcDevice(
        deviceId: deviceId,
        name: 'PC',
        ip: null, // 【推测】可能需要从 channel 获取
      ),
      channel: channel,
    );
  }

  /// 移除设备
  void removeDevice(String deviceId) {
    final connection = _connections.remove(deviceId);
    connection?.channel.sink.close();
  }

  /// 设置设备名称
  void setDeviceName(String deviceId, String name) {
    final connection = _connections[deviceId];
    if (connection != null) {
      _connections[deviceId] = _DeviceConnection(
        device: connection.device.copyWith(name: name),
        channel: connection.channel,
      );
    }
  }

  /// 发送消息给指定设备
  bool sendMessage(String deviceId, Map<String, dynamic> message) {
    final connection = _connections[deviceId];
    if (connection == null) return false;

    try {
      connection.channel.sink.add(jsonEncode(message));
      _connections[deviceId] = _DeviceConnection(
        device: connection.device.copyWith(lastActiveAt: DateTime.now()),
        channel: connection.channel,
      );
      return true;
    } catch (e) {
      removeDevice(deviceId);
      return false;
    }
  }

  /// 广播消息给所有设备
  void broadcast(Map<String, dynamic> message) {
    for (final deviceId in _connections.keys.toList()) {
      sendMessage(deviceId, message);
    }
  }

  /// 检查设备是否已连接
  bool isDeviceConnected(String deviceId) {
    return _connections.containsKey(deviceId);
  }

  /// 获取设备信息
  PcDevice? getDevice(String deviceId) {
    return _connections[deviceId]?.device;
  }

  /// 清空所有连接
  void clear() {
    for (final connection in _connections.values) {
      connection.channel.sink.close();
    }
    _connections.clear();
  }
}

class _DeviceConnection {
  final PcDevice device;
  final WebSocketChannel channel;

  _DeviceConnection({required this.device, required this.channel});
}
