import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soultalk/pc_connect/pairing_store.dart';
import 'package:soultalk/pc_connect/websocket_server.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// WebSocketServer 配对授权流程测试：
/// 首次连接自动配对、已配对重连、撤销拒绝、密钥不匹配拒绝、缺密钥拒绝。
void main() {
  late WebSocketServer server;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    server = WebSocketServer();
  });

  tearDown(() async {
    await server.stop();
  });

  test('first connection with valid JWT auto-pairs and gets auth_ok', () async {
    await server.start();
    final channel = WebSocketChannel.connect(Uri.parse(_wsUri(server)));
    final reply = await _sendAuth(channel, 'pc-1', 'key-1');

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
    final reply = await _sendAuth(channel, 'pc-1', 'key-1');

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
    final reply = await _sendAuth(channel, 'pc-1', 'key-1');

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
    final reply = await _sendAuth(channel, 'pc-1', 'wrong-key');

    expect(reply['type'], 'auth_error');
    expect(reply['reason'], 'device_not_authorized');
    await channel.sink.close();
  });

  test('missing device key is rejected', () async {
    await server.start();
    final channel = WebSocketChannel.connect(Uri.parse(_wsUri(server)));
    final reply = await _sendAuth(channel, 'pc-1', '');

    expect(reply['type'], 'auth_error');
    expect(reply['reason'], 'device_key_missing');
    await channel.sink.close();
  });
}

String _wsUri(WebSocketServer server) {
  final token = server.refreshToken();
  return 'ws://127.0.0.1:${server.port}/ws?token=$token&version=1';
}

Future<Map<String, dynamic>> _sendAuth(
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
  final reply = await channel.stream.first.timeout(const Duration(seconds: 5));
  return jsonDecode(reply as String) as Map<String, dynamic>;
}
