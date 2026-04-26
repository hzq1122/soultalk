import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/update_provider.dart';
import '../../theme/wechat_colors.dart';

class UpdatePage extends ConsumerStatefulWidget {
  const UpdatePage({super.key});

  @override
  ConsumerState<UpdatePage> createState() => _UpdatePageState();
}

class _UpdatePageState extends ConsumerState<UpdatePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(updateProvider.notifier).checkUpdate();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(updateProvider);

    return Scaffold(
      backgroundColor: WeChatColors.background,
      appBar: AppBar(
        backgroundColor: WeChatColors.appBarBackground,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('检查更新'),
      ),
      body: ListView(children: [
        const SizedBox(height: 32),
        Center(
          child: Icon(Icons.system_update,
              size: 64,
              color: state.status == UpdateStatus.updateAvailable
                  ? WeChatColors.primary
                  : WeChatColors.textHint),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text('Talk AI',
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text('版本 ${state.currentVersion}',
              style: const TextStyle(
                  color: WeChatColors.textSecondary, fontSize: 14)),
        ),
        const SizedBox(height: 24),
        _buildStatusArea(state),
      ]),
    );
  }

  Widget _buildStatusArea(UpdateState state) {
    switch (state.status) {
      case UpdateStatus.idle:
      case UpdateStatus.checking:
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('正在检查更新...',
                  style: TextStyle(color: WeChatColors.textSecondary)),
            ]),
          ),
        );
      case UpdateStatus.noUpdate:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(children: [
              const Icon(Icons.check_circle,
                  color: WeChatColors.primary, size: 48),
              const SizedBox(height: 12),
              const Text('已是最新版本',
                  style: TextStyle(color: WeChatColors.textSecondary)),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () =>
                    ref.read(updateProvider.notifier).checkUpdate(),
                child: const Text('重新检查'),
              ),
            ]),
          ),
        );
      case UpdateStatus.updateAvailable:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('发现新版本',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text(
                        state.updateInfo != null
                            ? 'v${state.updateInfo!.version}'
                            : '',
                        style: TextStyle(
                            fontSize: 16,
                            color: WeChatColors.primary,
                            fontWeight: FontWeight.w500)),
                    if (state.updateInfo?.releaseNotes.isNotEmpty == true) ...[
                      const SizedBox(height: 12),
                      const Text('更新内容:',
                          style: TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Text(state.updateInfo!.releaseNotes,
                          style: const TextStyle(
                              fontSize: 13,
                              color: WeChatColors.textSecondary)),
                    ],
                    if (state.updateInfo?.fileSize != null) ...[
                      const SizedBox(height: 8),
                      Text(
                          '大小: ${(state.updateInfo!.fileSize / 1024 / 1024).toStringAsFixed(1)} MB',
                          style: const TextStyle(
                              fontSize: 12,
                              color: WeChatColors.textHint)),
                    ],
                  ]),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: state.status == UpdateStatus.downloading
                    ? null
                    : () => ref.read(updateProvider.notifier).startDownload(),
                style: ElevatedButton.styleFrom(
                    backgroundColor: WeChatColors.primary,
                    foregroundColor: Colors.white),
                child: Text(state.status == UpdateStatus.downloading
                    ? '下载中...'
                    : '立即更新'),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () =>
                  ref.read(updateProvider.notifier).checkUpdate(),
              child: const Text('重新检查'),
            ),
          ]),
        );
      case UpdateStatus.downloading:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(children: [
            LinearProgressIndicator(
                value: state.downloadProgress,
                backgroundColor: const Color(0xFFE0E0E0),
                valueColor:
                    const AlwaysStoppedAnimation(WeChatColors.primary)),
            const SizedBox(height: 12),
            Text('${(state.downloadProgress * 100).toStringAsFixed(0)}%',
                style:
                    const TextStyle(color: WeChatColors.textSecondary)),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () =>
                  ref.read(updateProvider.notifier).cancelDownload(),
              child: const Text('取消下载',
                  style: TextStyle(color: Colors.red)),
            ),
          ]),
        );
      case UpdateStatus.downloadComplete:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(children: [
            const Icon(Icons.check_circle,
                color: WeChatColors.primary, size: 48),
            const SizedBox(height: 12),
            const Text('下载完成',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () async {
                  if (state.downloadPath != null) {
                    await OpenFilex.open(state.downloadPath!);
                  }
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: WeChatColors.primary,
                    foregroundColor: Colors.white),
                child: const Text('安装更新'),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                ref
                    .read(updateProvider.notifier)
                    .deleteDownloadedApk();
              },
              child: const Text('稍后安装'),
            ),
          ]),
        );
      case UpdateStatus.error:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(state.errorMessage ?? '检查更新失败',
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
                onPressed: () =>
                    ref.read(updateProvider.notifier).checkUpdate(),
                style: ElevatedButton.styleFrom(
                    backgroundColor: WeChatColors.primary,
                    foregroundColor: Colors.white),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => launchUrl(
                  Uri.parse(
                      'https://github.com/hzq1122/AI_talk/releases'),
                  mode: LaunchMode.externalApplication),
              child: const Text('前往 GitHub 下载'),
            ),
          ]),
        );
    }
  }
}
