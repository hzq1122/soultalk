import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soultalk/pc_connect/pairing_store.dart';
import 'package:soultalk/pc_connect/websocket_server.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// WebSocketServer 配对授权流程测试：
/// 首次连接自动配对、已配对重连、撤销拒绝、密钥不匹配拒绝、缺密钥拒绝。
void main() {
  late WebSocketServer server;
  late Directory dbDir;

  setUp(() async {
    sqfliteFfiInit();
    // auth 流程会触达 ApiConfigSender（读取 api_configs），
    // 因此需要可用的 sqlite 环境（独立临时目录，避免污染）。
    dbDir = await Directory.systemTemp.createTemp('ws_auth_db_');
    databaseFactoryFfi.setDatabasesPath(dbDir.path);
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({});
    server = WebSocketServer();
  });

  tearDown(() async {
    await server.stop();
    // sendConfig 是 fire-and-forget：认证成功后它仍在异步初始化 DB/读配置，
    // 若此时删除数据库目录，未决的 Future 会抛异常并落入「测试完成后失败」。
    // 先等待其完成（约一个建库周期），再清理临时目录。
    await Future<void>.delayed(const Duration(milliseconds: 600));
    try {
      if (await dbDir.exists()) await dbDir.delete(recursive: true);
    } catch (_) {
      // Windows 上 sqlite 句柄可能仍占用：忽略，临时目录由系统清理
    }
  });

  test('first connection with valid JWT auto-pairs and gets auth_ok', () async {
    await server.start();
    final channel = WebSocketChannel.connect(Uri.parse(_wsUri(server)));
    final stream = channel.stream.asBroadcastStream();
    final reply = await _sendAuth(stream, channel, 'pc-1', 'key-1');

    expect(reply['type'], 'auth_ok');
    final paired = await PairingStore().getDevice('pc-1');
    expect(paired, isNotNull);
    expect(paired!.revoked, isFalse);
    await channel.sink.close();
  });

  test('already paired device reconnects with matching key', () async {
    await PairingStore().approve(
      deviceId: 'pc-1',
      deviceName: 'PC',
      deviceKey: 'key-1',
    );
    await server.start();
    final channel = WebSocketChannel.connect(Uri.parse(_wsUri(server)));
    final stream = channel.stream.asBroadcastStream();
    final reply = await _sendAuth(stream, channel, 'pc-1', 'key-1');

    expect(reply['type'], 'auth_ok');
    await channel.sink.close();
  });

  test('revoked device is rejected with auth_error', () async {
    await PairingStore().approve(
      deviceId: 'pc-1',
      deviceName: 'PC',
      deviceKey: 'key-1',
    );
    await PairingStore().revoke('pc-1');
    await server.start();
    final channel = WebSocketChannel.connect(Uri.parse(_wsUri(server)));
    final stream = channel.stream.asBroadcastStream();
    final reply = await _sendAuth(stream, channel, 'pc-1', 'key-1');

    expect(reply['type'], 'auth_error');
    expect(reply['reason'], 'device_not_authorized');
    await channel.sink.close();
  });

  test('wrong device key is rejected', () async {
    await PairingStore().approve(
      deviceId: 'pc-1',
      deviceName: 'PC',
      deviceKey: 'key-1',
    );
    await server.start();
    final channel = WebSocketChannel.connect(Uri.parse(_wsUri(server)));
    final stream = channel.stream.asBroadcastStream();
    final reply = await _sendAuth(stream, channel, 'pc-1', 'wrong-key');

    expect(reply['type'], 'auth_error');
    expect(reply['reason'], 'device_not_authorized');
    await channel.sink.close();
  });

  test('missing device key is rejected', () async {
    await server.start();
    final channel = WebSocketChannel.connect(Uri.parse(_wsUri(server)));
    final stream = channel.stream.asBroadcastStream();
    final reply = await _sendAuth(stream, channel, 'pc-1', '');

    expect(reply['type'], 'auth_error');
    expect(reply['reason'], 'device_key_missing');
    await channel.sink.close();
  });

  test('keep read-only mode rejects push even with push permission', () async {
    SharedPreferences.setMockInitialValues({'pc_keep_readonly': true});
    await PairingStore().approve(
      deviceId: 'pc-1',
      deviceName: 'PC',
      deviceKey: 'key-1',
      permissions: ['pull', 'push'],
    );
    await server.start();
    final channel = WebSocketChannel.connect(Uri.parse(_wsUri(server)));
    final stream = channel.stream.asBroadcastStream();
    final auth = await _sendAuth(stream, channel, 'pc-1', 'key-1');
    expect(auth['type'], 'auth_ok');

    channel.sink.add(
      jsonEncode({
        'type': 'push.propose',
        'payload': {'table': 'messages', 'rows': []},
      }),
    );
    final reply = await _waitForType(stream, 'push.result');
    expect(reply['accepted'], isFalse);
    expect(reply['reason'], 'no_push_permission');
    await channel.sink.close();
  });

  test('read-only off lets push pass the permission gate', () async {
    SharedPreferences.setMockInitialValues({'pc_keep_readonly': false});
    await PairingStore().approve(
      deviceId: 'pc-1',
      deviceName: 'PC',
      deviceKey: 'key-1',
      permissions: ['pull', 'push'],
    );
    await server.start();
    final channel = WebSocketChannel.connect(Uri.parse(_wsUri(server)));
    final stream = channel.stream.asBroadcastStream();
    final auth = await _sendAuth(stream, channel, 'pc-1', 'key-1');
    expect(auth['type'], 'auth_ok');

    channel.sink.add(
      jsonEncode({
        'type': 'push.propose',
        'payload': {'table': 'messages', 'rows': []},
      }),
    );
    final reply = await _waitForType(stream, 'push.result');
    // 已通过权限门禁（后续 apply 失败也必须是 internal_error 而非权限拒绝）
    expect(reply['reason'], isNot('no_push_permission'));
    await channel.sink.close();
  });
}

Future<Map<String, dynamic>> _waitForType(
  Stream<dynamic> stream,
  String type,
) async {
  await for (final data in stream.timeout(const Duration(seconds: 5))) {
    final decoded = jsonDecode(data as String) as Map<String, dynamic>;
    if (decoded['type'] == type) return decoded;
  }
  throw StateError('never received $type');
}

String _wsUri(WebSocketServer server) {
  final token = server.refreshToken();
  return 'ws://127.0.0.1:${server.port}/ws?token=$token&version=1';
}

Future<Map<String, dynamic>> _sendAuth(
  Stream<dynamic> stream,
  WebSocketChannel channel,
  String deviceId,
  String deviceKey,
) async {
  channel.sink.add(
    jsonEncode({
      'type': 'auth',
      'deviceId': deviceId,
      'deviceKey': deviceKey,
      'deviceName': 'PC-test',
    }),
  );
  await for (final data in stream.timeout(const Duration(seconds: 5))) {
    final decoded = jsonDecode(data as String) as Map<String, dynamic>;
    final type = decoded['type'];
    if (type == 'auth_ok' || type == 'auth_error') return decoded;
  }
  throw StateError('never received auth reply');
}
