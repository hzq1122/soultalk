import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/update_provider.dart';
import '../../services/update/update_service.dart';
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
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 16),
          // App icon
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: WeChatColors.primary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.chat_bubble_outline,
                  size: 36, color: Colors.white),
            ),
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text('SoulTalk',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              '版本 ${state.currentVersion}',
              style: const TextStyle(color: WeChatColors.textSecondary, fontSize: 14),
            ),
          ),
          const SizedBox(height: 32),
          _buildBody(state),
        ],
      ),
    );
  }

  Widget _buildBody(UpdateState state) {
    switch (state.status) {
      case UpdateStatus.idle:
      case UpdateStatus.checking:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Column(children: [
            SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5)),
            SizedBox(height: 16),
            Text('正在检查更新...',
                style: TextStyle(color: WeChatColors.textSecondary)),
          ]),
        );

      case UpdateStatus.noUpdate:
        return Column(children: [
          const Icon(Icons.check_circle, color: WeChatColors.primary, size: 48),
          const SizedBox(height: 16),
          const Text('已是最新版本',
              style: TextStyle(color: WeChatColors.textSecondary, fontSize: 15)),
          const SizedBox(height: 32),
          OutlinedButton(
            onPressed: () => ref.read(updateProvider.notifier).checkUpdate(),
            child: const Text('重新检查'),
          ),
        ]);

      case UpdateStatus.updateAvailable:
        return _buildUpdateAvailable(state);

      case UpdateStatus.downloading:
        return _buildDownloading(state);

      case UpdateStatus.downloadComplete:
        return _buildDownloadComplete(state);

      case UpdateStatus.error:
        return _buildError(state);
    }
  }

  Widget _buildUpdateAvailable(UpdateState state) {
    final info = state.updateInfo;
    final changelog = info?.changelog ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // New version card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: WeChatColors.primary.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.new_releases, color: WeChatColors.primary, size: 20),
                  const SizedBox(width: 8),
                  const Text('发现新版本',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  if (info != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: WeChatColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('v${info.version}',
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
              if (info?.fileSize != null) ...[
                const SizedBox(height: 8),
                Text('安装包大小: ${(info!.fileSize / 1024 / 1024).toStringAsFixed(1)} MB',
                    style: const TextStyle(fontSize: 12, color: WeChatColors.textHint)),
              ],
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Changelog
        if (changelog.isNotEmpty) ...[
          const Text('更新日志',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ...changelog.map((release) => _buildChangelogEntry(release)),
          const SizedBox(height: 8),
        ] else if (info?.releaseNotes.isNotEmpty == true) ...[
          const Text('更新内容',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _buildSimpleNotes(info!.releaseNotes),
        ],

        const SizedBox(height: 24),

        // Action buttons
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () {
              if (info?.downloadUrl.isNotEmpty == true) {
                ref.read(updateProvider.notifier).startDownload();
              } else {
                _openGitHubReleases();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: WeChatColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(info?.downloadUrl.isNotEmpty == true ? '立即下载更新' : '前往 GitHub 下载'),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => context.pop(),
          child: const Text('以后再说', style: TextStyle(color: WeChatColors.textSecondary)),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildChangelogEntry(ReleaseEntry release) {
    final date = _formatDate(release.publishedAt);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('v${release.version}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: WeChatColors.primary)),
              const Spacer(),
              if (date.isNotEmpty)
                Text(date, style: const TextStyle(fontSize: 11, color: WeChatColors.textHint)),
            ],
          ),
          if (release.title.isNotEmpty && release.title != 'v${release.version}') ...[
            const SizedBox(height: 4),
            Text(release.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ],
          if (release.body.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(release.body,
                style: const TextStyle(fontSize: 12, color: WeChatColors.textSecondary, height: 1.5),
                maxLines: 20,
                overflow: TextOverflow.ellipsis),
          ],
        ],
      ),
    );
  }

  Widget _buildSimpleNotes(String notes) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(notes,
          style: const TextStyle(fontSize: 12, color: WeChatColors.textSecondary, height: 1.5)),
    );
  }

  Widget _buildDownloading(UpdateState state) {
    return Column(children: [
      const SizedBox(height: 16),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: state.downloadProgress,
          minHeight: 6,
          backgroundColor: const Color(0xFFE0E0E0),
          valueColor: const AlwaysStoppedAnimation(WeChatColors.primary),
        ),
      ),
      const SizedBox(height: 12),
      Text('${(state.downloadProgress * 100).toStringAsFixed(0)}%',
          style: const TextStyle(color: WeChatColors.textSecondary)),
      const SizedBox(height: 24),
      OutlinedButton(
        onPressed: () => ref.read(updateProvider.notifier).cancelDownload(),
        child: const Text('取消下载', style: TextStyle(color: Colors.red)),
      ),
    ]);
  }

  Widget _buildDownloadComplete(UpdateState state) {
    return Column(children: [
      const Icon(Icons.check_circle, color: WeChatColors.primary, size: 48),
      const SizedBox(height: 12),
      const Text('下载完成', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
      const SizedBox(height: 24),
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
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('安装更新'),
        ),
      ),
      const SizedBox(height: 12),
      TextButton(
        onPressed: () => ref.read(updateProvider.notifier).deleteDownloadedApk(),
        child: const Text('稍后安装', style: TextStyle(color: WeChatColors.textSecondary)),
      ),
    ]);
  }

  Widget _buildError(UpdateState state) {
    return Column(children: [
      const Icon(Icons.error_outline, color: Colors.red, size: 48),
      const SizedBox(height: 12),
      Text(state.errorMessage ?? '检查更新失败',
          style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
      const SizedBox(height: 24),
      SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton.icon(
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('重试'),
          onPressed: () => ref.read(updateProvider.notifier).checkUpdate(),
          style: ElevatedButton.styleFrom(
            backgroundColor: WeChatColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
      const SizedBox(height: 12),
      TextButton(
        onPressed: _openGitHubReleases,
        child: const Text('前往 GitHub 下载'),
      ),
    ]);
  }

  void _openGitHubReleases() {
    launchUrl(
      Uri.parse('https://github.com/hzq1122/soultalk/releases'),
      mode: LaunchMode.externalApplication,
    );
  }

  String _formatDate(String iso) {
    if (iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}
