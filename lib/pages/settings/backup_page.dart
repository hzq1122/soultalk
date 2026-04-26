import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/wechat_colors.dart';

class BackupPage extends ConsumerWidget {
  const BackupPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: WeChatColors.background,
      appBar: AppBar(
        backgroundColor: WeChatColors.appBarBackground,
        title: const Text('备份与恢复'),
      ),
      body: const Center(
        child: Text('备份功能开发中...',
            style: TextStyle(color: WeChatColors.textSecondary)),
      ),
    );
  }
}
