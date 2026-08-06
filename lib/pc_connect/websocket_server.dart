import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math';

import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'connection_manager.dart';
import 'pairing_store.dart';
import '../services/database/database_service.dart';
import 'sync_handler.dart';
import 'api_config_sender.dart';
import 'manifest/manifest_builder.dart';
import 'sync_exporter.dart';
import 'push/push_applier.dart';

/// WebSocket 服务端，用于手机端与 PC 端通信
class WebSocketServer {
  static const int _minPort = 49152;
  static const int _maxPort = 65535;
  static const int _maxDevices = 3;
  static const int _maxPendingConnections = 5;
  static const Duration _tokenTtl = Duration(minutes: 2);
  static const Duration _idleTimeout = Duration(minutes: 5);

  HttpServer? _server;
  String? _jwtSecret;
  String? _currentToken;
  Timer? _idleTimer;

  final _uuid = const Uuid();
  final ConnectionManager _connectionManager = ConnectionManager();
  final SyncHandler _syncHandler = SyncHandler();
  final ApiConfigSender _apiConfigSender = ApiConfigSender();
  final PairingStore _pairingStore = PairingStore();

  /// 已通过配对校验的 socket（按服务器 socketDeviceId 索引）
  final Set<String> _authenticatedSockets = {};

  /// socketDeviceId → 客户端持久 deviceId 映射（用于事件身份一致）
  final Map<String, String> _clientDeviceIds = {};
  final SyncManifestBuilder _manifestBuilder = SyncManifestBuilder(
    dbService: DatabaseService(),
  );
  final SyncExporter _syncExporter = SyncExporter(dbService: DatabaseService());
  final PushApplier _pushApplier = const PushApplier();

  final StreamController<Map<String, dynamic>> _eventController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get events => _eventController.stream;
  ConnectionManager get connectionManager => _connectionManager;

  bool get isRunning => _server != null;
  int? get port => _server?.port;
  String? get currentToken => _currentToken;

  /// 启动 WebSocket 服务器
  Future<int> start() async {
    if (_server != null) {
      throw StateError('Server already running');
    }

    // 生成 JWT 密钥
    _jwtSecret = _generateSecret();
    _refreshToken();

    final handler = shelf.Pipeline()
        .addMiddleware(_checkAuth())
        .addHandler(webSocketHandler(_handleConnection));

    // 带重试的端口绑定
    final rng = Random.secure();
    const maxRetries = 20;
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      final port = _minPort + rng.nextInt(_maxPort - _minPort + 1);
      try {
        _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
        _startIdleTimer();
        _eventController.add({'type': 'server_started', 'port': port});
        return port;
      } on SocketException {
        if (attempt == maxRetries - 1) rethrow;
        continue;
      }
    }
    throw StateError('Failed to bind to any port after $maxRetries attempts');
  }

  /// 停止服务器
  Future<void> stop() async {
    _idleTimer?.cancel();
    _idleTimer = null;

    // 通知所有连接的 PC
    for (final device in _connectionManager.connectedDevices) {
      _connectionManager.sendMessage(device.deviceId, {
        'type': 'disconnect',
        'reason': 'server_shutdown',
      });
    }

    await _server?.close(force: true);
    _server = null;
    _currentToken = null;
    _connectionManager.clear();
    // 清理认证状态，避免 stop→start 快速重启后计数残留
    _authenticatedSockets.clear();
    _clientDeviceIds.clear();

    _eventController.add({'type': 'server_stopped'});
  }

  /// 刷新 JWT token
  String refreshToken() {
    _refreshToken();
    return _currentToken!;
  }

  /// 获取连接 URI
  String getConnectionUri(String localIp) {
    return 'ws://$localIp:${_server?.port}/ws?token=$_currentToken&version=1';
  }

  void _refreshToken() {
    _jwtSecret = _generateSecret();
    final jwt = JWT({
      'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'exp': DateTime.now().add(_tokenTtl).millisecondsSinceEpoch ~/ 1000,
    });
    _currentToken = jwt.sign(SecretKey(_jwtSecret!));
  }

  String _generateSecret() {
    final rng = Random.secure();
    final random = List.generate(32, (_) => rng.nextInt(256));
    return base64Url.encode(random);
  }

  shelf.Middleware _checkAuth() {
    return (shelf.Handler innerHandler) {
      return (shelf.Request request) {
        // 只检查 WebSocket 连接
        if (request.url.path == 'ws') {
          final token = request.url.queryParameters['token'];
          if (token == null || !_validateToken(token)) {
            return shelf.Response.forbidden('Invalid or expired token');
          }

          // 检查是否超过最大设备数（仅统计已认证设备，
          // 未认证连接不占名额，防止空连接 DoS）
          if (_authenticatedSockets.length >= _maxDevices) {
            return shelf.Response.forbidden('Maximum devices reached');
          }

          // 检查是否内网 IP
          final clientIp = _getClientIp(request);
          if (clientIp == null || !_isPrivateIp(clientIp)) {
            return shelf.Response.forbidden('Only LAN connections allowed');
          }
        }
        return innerHandler(request);
      };
    };
  }

  /// 获取客户端 IP 地址
  ///
  /// shelf_io 在请求 context 中暴露 `shelf.io.connection_info`
  /// （`HttpConnectionInfo`），优先从中取真实远端地址；仅在代理场景下
  /// 回退到 X-Forwarded-For / X-Real-IP 头。
  String? _getClientIp(shelf.Request request) {
    final connectionInfo = request.context['shelf.io.connection_info'];
    if (connectionInfo is HttpConnectionInfo) {
      final address = connectionInfo.remoteAddress.address;
      if (address.isNotEmpty) return address;
    }

    // 代理场景：X-Forwarded-For 取第一个 IP（最初的客户端 IP）
    final forwardedFor = request.headers['x-forwarded-for'];
    if (forwardedFor != null) {
      return forwardedFor.split(',').first.trim();
    }

    // 代理场景：X-Real-IP 头
    final realIp = request.headers['x-real-ip'];
    if (realIp != null) {
      return realIp;
    }

    return null;
  }

  /// 检查是否为内网 IP 地址
  bool _isPrivateIp(String ip) {
    try {
      final addr = InternetAddress(ip);
      // IPv4 内网地址范围
      if (addr.type == InternetAddressType.IPv4) {
        final parts = ip.split('.').map(int.parse).toList();
        if (parts.length != 4) return false;

        // 10.0.0.0/8
        if (parts[0] == 10) return true;
        // 172.16.0.0/12
        if (parts[0] == 172 && parts[1] >= 16 && parts[1] <= 31) return true;
        // 192.168.0.0/16
        if (parts[0] == 192 && parts[1] == 168) return true;
        // 127.0.0.0/8 (localhost)
        if (parts[0] == 127) return true;

        return false;
      }

      // IPv6 内网地址
      if (addr.type == InternetAddressType.IPv6) {
        // ::1 (localhost)
        if (ip == '::1') return true;
        // fe80::/10 (link-local)
        if (ip.startsWith('fe80:')) return true;
        // fc00::/7 (unique local)
        if (ip.startsWith('fc') || ip.startsWith('fd')) return true;

        return false;
      }

      return false;
    } catch (e) {
      // IP 解析失败，默认拒绝
      return false;
    }
  }

  void _handleConnection(WebSocketChannel webSocket, String? protocol) {
    // 未认证连接上限：JWT 窗口内建立大量空连接会占用 fd/内存
    // 并阻止 idle 自动停服，超限直接拒绝新连接
    final pendingCount =
        _connectionManager.connectionCount - _authenticatedSockets.length;
    if (pendingCount >= _maxPendingConnections) {
      webSocket.sink.close(1013, 'Too many pending connections');
      return;
    }
    final deviceId = _generateDeviceId();

    webSocket.stream.listen(
      (message) {
        _resetIdleTimer();
        _handleMessage(deviceId, message as String);
      },
      onDone: () {
        _connectionManager.removeDevice(deviceId);
        _authenticatedSockets.remove(deviceId);
        final clientDeviceId = _clientDeviceIds.remove(deviceId);
        _eventController.add({
          'type': 'device_disconnected',
          'deviceId': clientDeviceId ?? deviceId,
        });
      },
      onError: (error) {
        _connectionManager.removeDevice(deviceId);
        _authenticatedSockets.remove(deviceId);
        _clientDeviceIds.remove(deviceId);
      },
    );

    _connectionManager.addDevice(deviceId, webSocket);

    _eventController.add({'type': 'device_connected', 'deviceId': deviceId});
  }

  void _handleMessage(String deviceId, String rawMessage) {
    try {
      final message = jsonDecode(rawMessage) as Map<String, dynamic>;
      final type = message['type'] as String?;

      // 认证门禁：除 auth 外的业务消息仅允许已通过配对校验的连接处理
      if (type != 'auth' && !_authenticatedSockets.contains(deviceId)) {
        _connectionManager.sendMessage(deviceId, {
          'type': 'auth_error',
          'reason': 'not_authenticated',
          'message': '连接未认证',
        });
        _connectionManager.removeDevice(deviceId);
        return;
      }

      switch (type) {
        case 'auth':
          unawaited(_handleAuth(deviceId, message));
          break;
        case 'sync':
          _handleSync(deviceId, message);
          break;
        case 'sync_check':
          _handleSyncCheck(deviceId, message);
          break;
        case 'new_message':
          _handleNewMessage(deviceId, message);
          break;
        case 'conflict_resolved':
          _handleConflictResolved(deviceId, message);
          break;
        case 'manifest.request':
          _handleManifestRequest(deviceId);
          break;
        case 'pull.request':
          _handlePullRequest(deviceId, message);
          break;
        case 'push.propose':
          _handlePushProposal(deviceId, message);
          break;
        case 'disconnect':
          _handleDisconnect(deviceId, message);
          break;
        case 'ping':
          _connectionManager.sendMessage(deviceId, {'type': 'pong'});
          break;
        default:
          _connectionManager.sendMessage(deviceId, {
            'type': 'error',
            'message': 'Unknown message type: $type',
          });
      }
    } catch (e) {
      _connectionManager.sendMessage(deviceId, {
        'type': 'error',
        'message': 'Invalid message format',
      });
    }
  }

  /// 处理认证消息：校验设备配对状态。
  ///
  /// 设备身份以客户端 auth 消息中的 deviceId 为准（PC 端持久化身份），
  /// 服务器的 socketDeviceId 仅用于连接路由。
  /// - 已配对设备：校验 deviceKey 与撤销状态，通过才放行；
  /// - 未配对设备：当前连接已通过 [_checkAuth] 的 JWT 校验（扫码即授权），
  ///   首次连接自动登记为已配对设备；
  /// - 校验失败：发送 auth_error 并断开连接。
  Future<void> _handleAuth(
    String socketDeviceId,
    Map<String, dynamic> message,
  ) async {
    final clientDeviceId = message['deviceId'] as String?;
    final deviceName = message['deviceName'] as String? ?? 'PC';
    final deviceKey = message['deviceKey'] as String?;

    if (clientDeviceId == null || clientDeviceId.isEmpty) {
      _rejectAuth(socketDeviceId, 'device_id_missing', '缺少设备标识');
      return;
    }

    try {
      final existing = await _pairingStore.getDevice(clientDeviceId);
      if (existing != null) {
        // 已配对设备：校验 deviceKey 与撤销状态
        final verified =
            deviceKey != null &&
            await _pairingStore.verify(clientDeviceId, deviceKey);
        if (!verified) {
          _rejectAuth(socketDeviceId, 'device_not_authorized', '设备未通过授权校验');
          return;
        }
      } else if (deviceKey == null || deviceKey.isEmpty) {
        // 未配对且缺少 deviceKey：拒绝（扫码连接也必须携带设备身份）
        _rejectAuth(socketDeviceId, 'device_key_missing', '缺少设备密钥');
        return;
      } else {
        // 未配对：扫码授权（JWT 已校验）后的首次连接自动登记配对
        await _pairingStore.approve(
          deviceId: clientDeviceId,
          deviceName: deviceName,
          deviceKey: deviceKey,
        );
      }
    } catch (error) {
      _rejectAuth(socketDeviceId, 'pairing_error', '配对校验失败：$error');
      return;
    }

    // 认证期间的异步 IO 窗口内 socket 可能已断开，
    // 避免登记僵尸认证条目（永久占用设备名额）；
    // 同时复查设备数上限（并发认证可能突破 HTTP 阶段的单次检查）
    if (!_connectionManager.isDeviceConnected(socketDeviceId) ||
        _authenticatedSockets.length >= _maxDevices) {
      return;
    }

    _connectionManager.setDeviceName(socketDeviceId, deviceName);

    // 配对通过：标记为已认证（业务消息门禁）
    _authenticatedSockets.add(socketDeviceId);
    _clientDeviceIds[socketDeviceId] = clientDeviceId;

    try {
      _connectionManager.sendMessage(socketDeviceId, {
        'type': 'auth_ok',
        'deviceId': clientDeviceId,
        'serverTime': DateTime.now().toIso8601String(),
      });

      // 发送 API 配置（fire-and-forget；内部已捕获全部异常，
      // 此处再包一层防止未来改动引入未处理异步错误）
      unawaited(
        _apiConfigSender
            .sendConfig(socketDeviceId, _connectionManager)
            .catchError((Object error, StackTrace stackTrace) {
              developer.log(
                'Failed to send api config (unexpected)',
                name: 'WebSocketServer',
                error: error,
                stackTrace: stackTrace,
              );
            }),
      );

      _eventController.add({
        'type': 'device_authenticated',
        'deviceId': clientDeviceId,
        'deviceName': deviceName,
      });
    } catch (error, stackTrace) {
      // 配对已通过，通知类异常不应拒绝已认证设备，仅记录
      developer.log(
        'Failed to finalize device authentication',
        name: 'WebSocketServer',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// 拒绝设备认证：发送 auth_error 并断开连接。
  void _rejectAuth(String deviceId, String reason, String message) {
    _authenticatedSockets.remove(deviceId);
    _clientDeviceIds.remove(deviceId);
    _connectionManager.sendMessage(deviceId, {
      'type': 'auth_error',
      'reason': reason,
      'message': message,
    });
    _connectionManager.removeDevice(deviceId);
  }

  Future<void> _handleSync(
    String deviceId,
    Map<String, dynamic> message,
  ) async {
    // 读入口权限门禁：设备被撤销或无 pull 权限时拒绝拉取
    if (!await _deviceHasPermission(deviceId, 'pull')) return;
    final since = message['since'] as String?;
    // 与 pull.request 一致：limit 钳制到 [1,500]，防止恶意大值
    final rawLimit = message['limit'] as int? ?? 20;
    final limit = rawLimit.clamp(1, 500);

    final data = await _syncHandler.getSyncData(
      since: since != null ? DateTime.tryParse(since) : null,
      limit: limit,
    );

    _connectionManager.sendMessage(deviceId, {
      'type': 'sync_data',
      'data': data,
    });
  }

  Future<void> _handleSyncCheck(
    String deviceId,
    Map<String, dynamic> message,
  ) async {
    // 读入口权限门禁：设备被撤销或无 pull 权限时拒绝
    if (!await _deviceHasPermission(deviceId, 'pull')) return;
    final lastSyncTime = message['lastSyncTime'] as String?;
    if (lastSyncTime == null) return;

    final merkleRoot = await _syncHandler.calculateMerkleRoot(
      since: DateTime.tryParse(lastSyncTime),
    );

    _connectionManager.sendMessage(deviceId, {
      'type': 'sync_check_result',
      'merkleRoot': merkleRoot,
      'serverTime': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _handleNewMessage(
    String deviceId,
    Map<String, dynamic> message,
  ) async {
    // 权限门禁：向其他 PC 广播消息等同写入操作，必须拥有 push 权限；
    // 只读设备（keepPCReadOnly）不得传播任意消息内容。
    if (!await _deviceHasPermission(deviceId, 'push')) {
      _connectionManager.sendMessage(deviceId, {
        'type': 'error',
        'reason': 'no_push_permission',
        'message': '只读模式下不允许广播消息',
      });
      return;
    }
    // 标记来自 PC
    message['fromPC'] = true;
    message['fromDevice'] = deviceId;

    // 广播给其他连接的设备
    for (final device in _connectionManager.connectedDevices) {
      if (device.deviceId != deviceId) {
        _connectionManager.sendMessage(device.deviceId, message);
      }
    }

    _eventController.add({'type': 'new_message', 'message': message});
  }

  Future<void> _handleConflictResolved(
    String deviceId,
    Map<String, dynamic> message,
  ) async {
    // 冲突解决会覆盖 messages 内容：与 push.propose 相同，必须校验 push 权限
    if (!await _deviceHasPermission(deviceId, 'push')) {
      _connectionManager.sendMessage(deviceId, {
        'type': 'error',
        'message': '设备无 push 权限',
      });
      return;
    }
    final resolutions = message['resolutions'] as List<dynamic>?;
    if (resolutions == null) return;

    await _syncHandler.applyResolutions(resolutions);

    // 通知 PC 同步就绪
    _connectionManager.sendMessage(deviceId, {'type': 'sync_ready'});
  }

  Future<void> _handleManifestRequest(String deviceId) async {
    // 读入口权限门禁：设备被撤销或无 pull 权限时拒绝
    if (!await _deviceHasPermission(deviceId, 'pull')) return;
    final manifest = await _manifestBuilder.build();
    _connectionManager.sendMessage(deviceId, {
      'type': 'manifest.response',
      'payload': manifest,
    });
  }

  /// 校验已认证设备是否拥有指定权限（pull/push）。
  /// “PC 只读”等权限设置在此强制生效，不检查的入口等同于无权限门禁。
  Future<bool> _deviceHasPermission(
    String socketDeviceId,
    String permission,
  ) async {
    try {
      final clientDeviceId = _clientDeviceIds[socketDeviceId];
      if (clientDeviceId == null) return false;
      final device = await _pairingStore.getDevice(clientDeviceId);
      if (device == null || device.revoked) return false;
      // 「电脑断联后保持只读模式」：开启时 PC 只允许 pull（查看），
      // push 与 conflict resolution 一律拒绝。
      if (permission == 'push') {
        final prefs = await SharedPreferences.getInstance();
        final keepReadOnly = prefs.getBool('pc_keep_readonly') ?? true;
        if (keepReadOnly) return false;
      }
      return device.permissions.contains(permission);
    } catch (_) {
      return false;
    }
  }

  Future<void> _handlePullRequest(
    String deviceId,
    Map<String, dynamic> message,
  ) async {
    if (!await _deviceHasPermission(deviceId, 'pull')) {
      _connectionManager.sendMessage(deviceId, {
        'type': 'pull.error',
        'message': '设备无 pull 权限',
      });
      return;
    }
    final payload =
        (message['payload'] as Map?)?.cast<String, dynamic>() ?? message;
    final table = payload['table'] as String?;
    if (table == null) {
      _connectionManager.sendMessage(deviceId, {
        'type': 'pull.error',
        'message': 'table is required',
      });
      return;
    }
    final ids = (payload['ids'] as List?)?.cast<String>();
    // 单次同步数量上限：客户端传值不可信，钳制到 [1, 500]，
    // 防止恶意/异常客户端一次拉取全表导致内存与网络滥用。
    final rawLimit = payload['limit'] as int? ?? 500;
    final limit = rawLimit.clamp(1, 500);
    final after = payload['after'] as String?;
    final afterUpdatedAt = payload['afterUpdatedAt'] as String?;
    try {
      final data = await _syncExporter.exportRows(
        table: table,
        ids: ids?.take(500).toList(),
        limit: limit,
        after: after,
        afterUpdatedAt: afterUpdatedAt,
      );
      _connectionManager.sendMessage(deviceId, {
        'type': 'pull.chunk',
        'payload': data,
      });
      // hasMore 为 true 时不下发 pull.complete：PC 端用最后一条 id
      // 作为 after 游标继续拉取，直到收到 complete 为止（避免静默截断）。
      final hasMore = data['hasMore'] == true;
      if (!hasMore) {
        _connectionManager.sendMessage(deviceId, {
          'type': 'pull.complete',
          'payload': {'table': table},
        });
      }
    } catch (error) {
      _connectionManager.sendMessage(deviceId, {
        'type': 'pull.error',
        'message': error.toString(),
      });
    }
  }

  Future<void> _handlePushProposal(
    String deviceId,
    Map<String, dynamic> message,
  ) async {
    // 权限门禁：只有拥有 push 权限的设备才能写入手机数据库
    if (!await _deviceHasPermission(deviceId, 'push')) {
      _connectionManager.sendMessage(deviceId, {
        'type': 'push.result',
        'accepted': false,
        'reason': 'no_push_permission',
        'message': '设备无 push 权限',
      });
      return;
    }
    try {
      // payload 解构也纳入 try：非 Map 类型（int/String/List）会抛
      // TypeError，必须被捕获并返回结果，否则 PC 端收不到响应挂起
      final payload =
          (message['payload'] as Map?)?.cast<String, dynamic>() ?? message;
      // 校验通过后真正应用变更（写库），构成 push 闭环
      final result = await _pushApplier.apply(payload);
      _connectionManager.sendMessage(deviceId, {
        'type': 'push.result',
        'payload': result,
      });
      if (result['applied'] == true) {
        _eventController.add({
          'type': 'push_applied',
          'deviceId': deviceId,
          'payload': payload,
        });
      }
    } catch (error) {
      // 畸形消息/未知异常也返回结果，避免 PC 端永久挂起
      _connectionManager.sendMessage(deviceId, {
        'type': 'push.result',
        'payload': {'accepted': false, 'reason': 'internal_error: $error'},
      });
    }
  }

  void _handleDisconnect(String deviceId, Map<String, dynamic> message) {
    final keepPCAlive = message['keepPCAlive'] as bool? ?? false;
    _connectionManager.removeDevice(deviceId);
    // 主动断开时同步清理认证状态（不等 onDone）
    _authenticatedSockets.remove(deviceId);
    _clientDeviceIds.remove(deviceId);

    _eventController.add({
      'type': 'device_disconnected',
      'deviceId': deviceId,
      'keepPCAlive': keepPCAlive,
    });
  }

  bool _validateToken(String token) {
    try {
      JWT.verify(token, SecretKey(_jwtSecret!));
      return true;
    } catch (e) {
      return false;
    }
  }

  String _generateDeviceId() {
    return 'pc_${_uuid.v4()}';
  }

  void _startIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(_idleTimeout, () {
      if (_connectionManager.connectedDevices.isEmpty) {
        stop();
        _eventController.add({'type': 'idle_shutdown'});
      }
    });
  }

  void _resetIdleTimer() {
    _startIdleTimer();
  }

  void dispose() {
    // 等 stop() 完成（含 server_stopped 事件发出）后再关闭事件控制器，
    // 避免 close 与 stop 内的事件 add 竞态
    unawaited(
      stop().then((_) {
        if (!_eventController.isClosed) {
          _eventController.close();
        }
      }),
    );
  }
}
