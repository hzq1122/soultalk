import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/connection_provider.dart';
import '../api_config_manager.dart';
import '../theme/desktop_theme.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connState = ref.watch(pcConnectionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _buildSection('API 配置模式', [
                _buildApiModeCard(context, ref, connState),
              ]),
              const SizedBox(height: 24),
              _buildSection('本地 API 配置', [
                _buildLocalConfigsCard(context, ref, connState),
              ]),
              const SizedBox(height: 24),
              _buildSection('连接设置', [
                _buildConnectionCard(context, ref, connState),
              ]),
              const SizedBox(height: 24),
              _buildSection('关于', [
                _buildAboutCard(context),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: DesktopTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildApiModeCard(
    BuildContext context,
    WidgetRef ref,
    PCConnectionState state,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            RadioListTile<ApiConfigMode>(
              title: const Text('跟随手机'),
              subtitle: const Text('使用手机端下发的 API 配置'),
              value: ApiConfigMode.followPhone,
              groupValue: state.apiMode,
              onChanged: (value) {
                if (value != null) {
                  _showModeSwitchDialog(context, ref, value);
                }
              },
            ),
            const Divider(),
            RadioListTile<ApiConfigMode>(
              title: const Text('独立配置'),
              subtitle: const Text('使用本地存储的 API 配置'),
              value: ApiConfigMode.independent,
              groupValue: state.apiMode,
              onChanged: (value) {
                if (value != null) {
                  _showModeSwitchDialog(context, ref, value);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocalConfigsCard(
    BuildContext context,
    WidgetRef ref,
    PCConnectionState state,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '本地配置仅在「独立配置」模式下使用',
              style: TextStyle(
                fontSize: 12,
                color: DesktopTheme.textHint,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => _showAddConfigDialog(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('添加配置'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionCard(
    BuildContext context,
    WidgetRef ref,
    PCConnectionState state,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ListTile(
              leading: Icon(
                state.connectionState == ConnectionState.connected
                    ? Icons.check_circle
                    : Icons.error_outline,
                color: state.connectionState == ConnectionState.connected
                    ? DesktopTheme.primary
                    : DesktopTheme.error,
              ),
              title: Text(
                state.connectionState == ConnectionState.connected
                    ? '已连接'
                    : '未连接',
              ),
              subtitle: state.deviceId != null
                  ? Text('设备 ID: ${state.deviceId}')
                  : null,
            ),
            if (state.connectionState == ConnectionState.connected)
              ElevatedButton(
                onPressed: () =>
                    ref.read(pcConnectionProvider.notifier).disconnect(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: DesktopTheme.error,
                ),
                child: const Text('断开连接'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('SoulTalk PC'),
              subtitle: Text('v1.0.0'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.code),
              title: const Text('GitHub'),
              subtitle: const Text('github.com/hzq1122/soultalk'),
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }

  void _showModeSwitchDialog(
    BuildContext context,
    WidgetRef ref,
    ApiConfigMode newMode,
  ) {
    final isFollowPhone = newMode == ApiConfigMode.followPhone;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('切换到${isFollowPhone ? "跟随手机" : "独立配置"}模式'),
        content: Text(
          isFollowPhone
              ? '将使用手机的 API 配置，本地独立配置不会删除但暂时禁用。继续？'
              : '将使用本地 API 配置，手机配置将被清除。是否继续？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(pcConnectionProvider.notifier).switchApiMode(newMode);
              Navigator.of(ctx).pop();
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showAddConfigDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final apiKeyController = TextEditingController();
    final modelController = TextEditingController();
    String provider = 'openai';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加 API 配置'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: '配置名称'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: provider,
              decoration: const InputDecoration(labelText: '提供商'),
              items: const [
                DropdownMenuItem(value: 'openai', child: Text('OpenAI')),
                DropdownMenuItem(value: 'anthropic', child: Text('Anthropic')),
                DropdownMenuItem(value: 'custom', child: Text('自定义')),
              ],
              onChanged: (value) {
                if (value != null) provider = value;
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: modelController,
              decoration: const InputDecoration(labelText: '模型'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: apiKeyController,
              decoration: const InputDecoration(labelText: 'API Key'),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final config = ApiConfig(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: nameController.text.trim(),
                provider: provider,
                model: modelController.text.trim(),
                apiKey: apiKeyController.text.trim(),
              );
              ref.read(pcConnectionProvider.notifier).addLocalConfig(config);
              Navigator.of(ctx).pop();
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }
}
