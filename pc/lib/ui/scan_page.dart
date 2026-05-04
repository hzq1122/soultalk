import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../providers/connection_provider.dart';
import '../theme/desktop_theme.dart';

class ScanPage extends ConsumerStatefulWidget {
  const ScanPage({super.key});

  @override
  ConsumerState<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends ConsumerState<ScanPage> {
  MobileScannerController? _controller;
  bool _isScanning = true;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connState = ref.watch(pcConnectionProvider);

    // 连接成功后跳转
    ref.listen(pcConnectionProvider, (prev, next) {
      if (next.connectionState == ConnectionState.connected) {
        context.go('/');
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('扫描二维码'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Text(
                    '扫描手机端二维码',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '在手机端打开「连接电脑」页面，扫描显示的二维码',
                    style: TextStyle(
                      fontSize: 13,
                      color: DesktopTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _buildScanner(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (connState.connectionState == ConnectionState.connecting)
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(strokeWidth: 2),
                        SizedBox(width: 12),
                        Text('连接中...'),
                      ],
                    ),
                  if (connState.error != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: DesktopTheme.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: DesktopTheme.error, size: 20),
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
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScanner() {
    if (!_isScanning) {
      return const Center(
        child: Text('扫码已暂停'),
      );
    }

    try {
      return MobileScanner(
        controller: _controller,
        onDetect: _onDetect,
      );
    } catch (e) {
      // 移动扫描器不可用时显示提示
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.qr_code_scanner, size: 64, color: DesktopTheme.textHint),
            const SizedBox(height: 16),
            const Text(
              '摄像头不可用',
              style: TextStyle(color: DesktopTheme.textSecondary),
            ),
            const SizedBox(height: 8),
            const Text(
              '请使用手动输入方式连接',
              style: TextStyle(fontSize: 12, color: DesktopTheme.textHint),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/'),
              child: const Text('返回'),
            ),
          ],
        ),
      );
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (!_isScanning) return;

    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null) return;

    final url = barcode.rawValue;
    if (url == null || !url.startsWith('ws://')) {
      return;
    }

    setState(() {
      _isScanning = false;
    });

    // 连接
    ref.read(pcConnectionProvider.notifier).connect(url);
  }
}
