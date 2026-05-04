import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../websocket_client.dart';
import '../sync_manager.dart';
import '../api_config_manager.dart';

/// 连接状态
class PCConnectionState {
  final WsConnectionState connectionState;
  final String? deviceId;
  final String? serverUrl;
  final List<Map<String, dynamic>> messages;
  final ApiConfigMode apiMode;
  final ApiConfig? activeApiConfig;
  final String? error;

  const PCConnectionState({
    this.connectionState = WsConnectionState.disconnected,
    this.deviceId,
    this.serverUrl,
    this.messages = const [],
    this.apiMode = ApiConfigMode.followPhone,
    this.activeApiConfig,
    this.error,
  });

  PCConnectionState copyWith({
    WsConnectionState? connectionState,
    String? deviceId,
    String? serverUrl,
    List<Map<String, dynamic>>? messages,
    ApiConfigMode? apiMode,
    ApiConfig? activeApiConfig,
    String? error,
  }) {
    return PCConnectionState(
      connectionState: connectionState ?? this.connectionState,
      deviceId: deviceId ?? this.deviceId,
      serverUrl: serverUrl ?? this.serverUrl,
      messages: messages ?? this.messages,
      apiMode: apiMode ?? this.apiMode,
      activeApiConfig: activeApiConfig ?? this.activeApiConfig,
      error: error,
    );
  }
}

/// 连接管理 Provider
class PCConnectionNotifier extends StateNotifier<PCConnectionState> {
  final WebSocketClient _client = WebSocketClient();
  final ApiConfigManager _configManager = ApiConfigManager();
  SyncManager? _syncManager;

  StreamSubscription? _stateSubscription;
  StreamSubscription? _eventSubscription;
  StreamSubscription? _messagesSubscription;

  PCConnectionNotifier() : super(const PCConnectionState()) {
    _init();
  }

  Future<void> _init() async {
    await _configManager.init();

    _stateSubscription = _client.stateStream.listen((connectionState) {
      state = state.copyWith(
        connectionState: connectionState,
        deviceId: _client.deviceId,
      );
    });

    _eventSubscription = _client.events.listen(_handleEvent);

    state = state.copyWith(
      apiMode: _configManager.mode,
      activeApiConfig: _configManager.activeConfig,
    );
  }

  /// 连接到手机
  Future<void> connect(String url) async {
    state = state.copyWith(serverUrl: url, error: null);
    await _client.connect(url);

    _syncManager = SyncManager(_client);
    _messagesSubscription = _syncManager!.messagesStream.listen((messages) {
      state = state.copyWith(messages: messages);
    });
  }

  /// 断开连接
  Future<void> disconnect() async {
    await _client.disconnect();
    _syncManager?.dispose();
    _syncManager = null;
    state = state.copyWith(
      connectionState: WsConnectionState.disconnected,
      deviceId: null,
      messages: [],
    );
  }

  /// 请求同步
  void requestSync() {
    _syncManager?.requestSync();
  }

  /// 发送消息
  void sendMessage(String contactId, String content) {
    _syncManager?.sendMessage(contactId, content);
  }

  /// 切换 API 模式
  Future<void> switchApiMode(ApiConfigMode mode) async {
    await _configManager.switchMode(mode);
    state = state.copyWith(
      apiMode: mode,
      activeApiConfig: _configManager.activeConfig,
    );
  }

  /// 添加本地 API 配置
  Future<void> addLocalConfig(ApiConfig config) async {
    await _configManager.addLocalConfig(config);
    state = state.copyWith(activeApiConfig: _configManager.activeConfig);
  }

  /// 删除本地 API 配置
  Future<void> removeLocalConfig(String id) async {
    await _configManager.removeLocalConfig(id);
    state = state.copyWith(activeApiConfig: _configManager.activeConfig);
  }

  void _handleEvent(Map<String, dynamic> event) {
    final type = event['type'] as String?;

    switch (type) {
      case 'api_config':
        final configs = event['configs'] as List<dynamic>?;
        if (configs != null) {
          final apiConfigs = configs
              .map((c) => ApiConfig.fromJson(c as Map<String, dynamic>))
              .toList();
          _configManager.receiveRemoteConfigs(apiConfigs);
          if (state.apiMode == ApiConfigMode.followPhone) {
            state = state.copyWith(
              activeApiConfig: _configManager.activeConfig,
            );
          }
        }
        break;

      case 'api_config_disabled':
        _configManager.clearRemoteConfigs();
        state = state.copyWith(error: '手机已禁用 API 共享');
        break;

      case 'clear_api':
        _configManager.clearAllRemoteConfigs();
        state = state.copyWith(activeApiConfig: _configManager.activeConfig);
        break;

      case 'error':
        state = state.copyWith(error: event['message'] as String?);
        break;
    }
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _eventSubscription?.cancel();
    _messagesSubscription?.cancel();
    _client.dispose();
    _syncManager?.dispose();
    super.dispose();
  }
}

final pcConnectionProvider =
    StateNotifierProvider<PCConnectionNotifier, PCConnectionState>((ref) {
      return PCConnectionNotifier();
    });
