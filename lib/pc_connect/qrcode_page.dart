import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../providers/pc_connect_provider.dart';
import '../theme/wechat_colors.dart';

/// 二维码展示页面 - 用于 PC 扫码连接
class QRCodePage extends ConsumerWidget {
  const QRCodePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectState = ref.watch(pcConnectProvider);

    return Scaffold(
      backgroundColor: WeChatColors.background,
      appBar: AppBar(
        title: const Text('连接电脑'),
        backgroundColor: WeChatColors.appBarBackground,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildEnableSwitch(context, ref, connectState),
            if (connectState.isServerRunning) ...[
              const SizedBox(height: 24),
              _buildQRCode(context, connectState, ref),
              const SizedBox(height: 16),
              _buildConnectionInfo(connectState),
              const SizedBox(height: 24),
              _buildConnectedDevices(context, ref, connectState),
            ],
            const SizedBox(height: 24),
            _buildSettings(context, ref, connectState),
          ],
        ),
      ),
    );
  }

  Widget _buildEnableSwitch(
    BuildContext context,
    WidgetRef ref,
    PcConnectState state,
  ) {
    return Card(
      child: SwitchListTile(
        title: const Text('允许电脑连接'),
        subtitle: Text(
          state.isServerRunning ? '服务运行中' : '关闭状态',
          style: TextStyle(
            color: state.isServerRunning ? Colors.green : WeChatColors.textHint,
            fontSize: 12,
          ),
        ),
        value: state.isEnabled,
        onChanged: (value) {
          ref.read(pcConnectProvider.notifier).toggleEnabled(value);
        },
        secondary: Icon(
          state.isServerRunning ? Icons.computer : Icons.computer_outlined,
          color: state.isServerRunning ? Colors.green : WeChatColors.textHint,
        ),
      ),
    );
  }

  Widget _buildQRCode(BuildContext context, PcConnectState state, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            if (state.qrData != null) ...[
              QrImageView(
                data: state.qrData!,
                version: QrVersions.auto,
                size: 200,
                backgroundColor: Colors.white,
              ),
              const SizedBox(height: 12),
              Text(
                '使用 PC 端扫描二维码连接',
                style: TextStyle(
                  color: WeChatColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${state.localIp ?? "未知"}:${state.port ?? "未知"}',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ] else ...[
              const SizedBox(
                width: 200,
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () {
                ref.read(pcConnectProvider.notifier).refreshQRCode();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('刷新二维码'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionInfo(PcConnectState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
          const SizedBox(width: 8),
          Text(
            '二维码有效期 2 分钟，请尽快扫描',
            style: TextStyle(
              color: Colors.blue.shade700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectedDevices(
    BuildContext context,
    WidgetRef ref,
    PcConnectState state,
  ) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '已连接设备',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: WeChatColors.textPrimary,
                  ),
                ),
                if (state.connectedDevices.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      _showDisconnectAllDialog(context, ref);
                    },
                    child: const Text(
                      '断开全部',
                      style: TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
          if (state.connectedDevices.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  '暂无设备连接',
                  style: TextStyle(
                    color: WeChatColors.textHint,
                    fontSize: 13,
                  ),
                ),
              ),
            )
          else
            ...state.connectedDevices.map((device) => ListTile(
                  leading: const Icon(Icons.computer, color: Colors.blue),
                  title: Text(device.name),
                  subtitle: Text(
                    '最后活跃: ${_formatTime(device.lastActiveAt)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.link_off, color: Colors.red),
                    onPressed: () {
                      ref
                          .read(pcConnectProvider.notifier)
                          .disconnectDevice(device.deviceId);
                    },
                  ),
                )),
        ],
      ),
    );
  }

  Widget _buildSettings(
    BuildContext context,
    WidgetRef ref,
    PcConnectState state,
  ) {
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            title: const Text('禁止 PC 使用手机 API'),
            subtitle: const Text(
              '开启后 PC 只能使用独立配置',
              style: TextStyle(fontSize: 12),
            ),
            value: !state.allowPCUseApi,
            onChanged: (value) {
              ref.read(pcConnectProvider.notifier).setAllowPCUseApi(!value);
            },
          ),
          const Divider(height: 1),
          SwitchListTile(
            title: const Text('电脑断联后保持只读模式'),
            subtitle: const Text(
              'PC 可查看历史消息但无法发送',
              style: TextStyle(fontSize: 12),
            ),
            value: state.keepPCReadOnly,
            onChanged: (value) {
              ref.read(pcConnectProvider.notifier).setKeepPCReadOnly(value);
            },
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    return '${diff.inDays}天前';
  }

  void _showDisconnectAllDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('断开所有设备'),
        content: const Text('确定要断开所有已连接的 PC 设备吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              ref.read(pcConnectProvider.notifier).disconnectAllDevices();
              Navigator.of(context).pop();
            },
            child: const Text('确定', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
