import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/connection_provider.dart';
import '../websocket_client.dart';
import '../theme/desktop_theme.dart';

class ScanPage extends ConsumerStatefulWidget {
  const ScanPage({super.key});

  @override
  ConsumerState<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends ConsumerState<ScanPage> {
  final TextEditingController _uriController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isConnecting = false;

  @override
  void dispose() {
    _uriController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connState = ref.watch(pcConnectionProvider);

    // 连接成功后跳转
    ref.listen(pcConnectionProvider, (prev, next) {
      if (next.connectionState == WsConnectionState.connected) {
        context.go('/');
      }
      if (next.connectionState == WsConnectionState.authFailed ||
          next.connectionState == WsConnectionState.failed) {
        setState(() {
          _isConnecting = false;
        });
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('连接手机'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.phonelink,
                      size: 64,
                      color: DesktopTheme.primary,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      '连接到手机',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '在手机端打开「我 → 连接电脑」，\n将显示的连接地址粘贴到下方',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: DesktopTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _uriController,
                      decoration: const InputDecoration(
                        labelText: '连接地址',
                        hintText: 'ws://192.168.1.100:12345/ws?token=xxx',
                        prefixIcon: Icon(Icons.link),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '请输入连接地址';
                        }
                        if (!value.trim().startsWith('ws://')) {
                          return '连接地址必须以 ws:// 开头';
                        }
                        return null;
                      },
                      maxLines: 2,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isConnecting ? null : _connect,
                        icon: _isConnecting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.link),
                        label: Text(_isConnecting ? '连接中...' : '连接'),
                      ),
                    ),
                    if (connState.error != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: DesktopTheme.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: DesktopTheme.error.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: DesktopTheme.error,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                connState.error!,
                                style: const TextStyle(
                                  color: DesktopTheme.error,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    _buildHelpSection(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHelpSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '连接步骤',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: DesktopTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        _buildStep(1, '在手机端打开「我 → 连接电脑」'),
        _buildStep(2, '开启「允许电脑连接」开关'),
        _buildStep(3, '复制显示的连接地址'),
        _buildStep(4, '粘贴到上方输入框并点击连接'),
        const SizedBox(height: 16),
        const Text(
          '提示：连接地址有效期为 2 分钟，过期请在手机端刷新',
          style: TextStyle(fontSize: 12, color: DesktopTheme.textHint),
        ),
      ],
    );
  }

  Widget _buildStep(int number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: DesktopTheme.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$number',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  void _connect() {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isConnecting = true;
    });

    final url = _uriController.text.trim();
    ref.read(pcConnectionProvider.notifier).connect(url);
  }
}
