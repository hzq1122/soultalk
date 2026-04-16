import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/api_config_provider.dart';
import '../../theme/wechat_colors.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apiConfigs = ref.watch(apiConfigProvider).value ?? [];

    return Scaffold(
      backgroundColor: WeChatColors.background,
      appBar: AppBar(
        title: const Text('我'),
        backgroundColor: WeChatColors.appBarBackground,
      ),
      body: ListView(
        children: [
          // 用户信息
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: WeChatColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.person, color: Colors.white, size: 36),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Talk AI 用户',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text('已配置 ${apiConfigs.length} 个 API',
                          style: const TextStyle(
                              color: WeChatColors.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: WeChatColors.textHint),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // 功能列表
          Container(
            color: Colors.white,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.api, color: WeChatColors.primary),
                  title: const Text('API 配置'),
                  subtitle: Text(
                    apiConfigs.isEmpty
                        ? '点击添加 API 配置'
                        : apiConfigs.map((c) => c.name).join('、'),
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: apiConfigs.isEmpty
                      ? const Icon(Icons.warning_amber,
                          color: Colors.orange)
                      : const Icon(Icons.chevron_right,
                          color: WeChatColors.textHint),
                  onTap: () => context.push('/settings/api'),
                ),
                const Divider(height: 0, indent: 56),
                ListTile(
                  leading: const Icon(Icons.star_border,
                      color: WeChatColors.primary),
                  title: const Text('收藏'),
                  trailing: const Icon(Icons.chevron_right,
                      color: WeChatColors.textHint),
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            color: Colors.white,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline,
                      color: WeChatColors.textSecondary),
                  title: const Text('关于 Talk AI'),
                  trailing: const Icon(Icons.chevron_right,
                      color: WeChatColors.textHint),
                  onTap: () => _showAbout(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Talk AI',
      applicationVersion: '1.0.0',
      applicationLegalese: 'AI 驱动的微信风格社交应用\n支持 OpenAI、Anthropic 等多种 LLM',
    );
  }
}
