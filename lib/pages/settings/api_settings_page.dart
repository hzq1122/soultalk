import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../models/api_config.dart';
import '../../providers/api_config_provider.dart';
import '../../theme/wechat_colors.dart';

class ApiSettingsPage extends ConsumerWidget {
  const ApiSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configsAsync = ref.watch(apiConfigProvider);

    return Scaffold(
      backgroundColor: WeChatColors.background,
      appBar: AppBar(
        title: const Text('API 配置'),
        backgroundColor: WeChatColors.appBarBackground,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showConfigDialog(context, ref, null),
          ),
        ],
      ),
      body: configsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        data: (configs) {
          if (configs.isEmpty) {
            return _buildEmpty(context, ref);
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: configs.length,
            itemBuilder: (context, index) {
              return _ConfigTile(
                config: configs[index],
                onEdit: () => _showConfigDialog(context, ref, configs[index]),
                onDelete: () => _deleteConfig(context, ref, configs[index]),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.api, size: 64, color: WeChatColors.textHint),
          const SizedBox(height: 12),
          const Text('还没有 API 配置',
              style: TextStyle(color: WeChatColors.textSecondary)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('添加配置'),
            onPressed: () => _showConfigDialog(context, ref, null),
          ),
        ],
      ),
    );
  }

  Future<void> _showConfigDialog(
      BuildContext context, WidgetRef ref, ApiConfig? existing) async {
    final result = await showDialog<ApiConfig>(
      context: context,
      builder: (ctx) => _ConfigDialog(existing: existing),
    );
    if (result != null) {
      if (existing == null) {
        await ref.read(apiConfigProvider.notifier).add(result);
      } else {
        await ref.read(apiConfigProvider.notifier).updateConfig(result);
      }
    }
  }

  Future<void> _deleteConfig(
      BuildContext context, WidgetRef ref, ApiConfig config) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除配置'),
        content: Text('确定删除 "${config.name}"？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child:
                  const Text('删除', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(apiConfigProvider.notifier).remove(config.id);
    }
  }
}

class _ConfigTile extends StatelessWidget {
  final ApiConfig config;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ConfigTile({
    required this.config,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: _providerIcon(config.provider),
        title: Text(config.name),
        subtitle: Text(
          '${config.model} · ${config.provider.name.toUpperCase()}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.edit_outlined, size: 20), onPressed: onEdit),
            IconButton(icon: const Icon(Icons.delete_outlined, size: 20, color: Colors.red), onPressed: onDelete),
          ],
        ),
      ),
    );
  }

  Widget _providerIcon(LlmProvider provider) {
    final color = switch (provider) {
      LlmProvider.openai => Colors.green,
      LlmProvider.anthropic => Colors.orange,
      LlmProvider.custom => Colors.blue,
    };
    final label = switch (provider) {
      LlmProvider.openai => 'GPT',
      LlmProvider.anthropic => 'ANT',
      LlmProvider.custom => 'API',
    };
    return CircleAvatar(
      backgroundColor: color,
      radius: 20,
      child: Text(label,
          style: const TextStyle(
              color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}

class _ConfigDialog extends StatefulWidget {
  final ApiConfig? existing;
  const _ConfigDialog({this.existing});

  @override
  State<_ConfigDialog> createState() => _ConfigDialogState();
}

class _ConfigDialogState extends State<_ConfigDialog> {
  late final _nameCtrl =
      TextEditingController(text: widget.existing?.name ?? '');
  late final _baseUrlCtrl =
      TextEditingController(text: widget.existing?.baseUrl ?? '');
  late final _apiKeyCtrl =
      TextEditingController(text: widget.existing?.apiKey ?? '');
  late final _modelCtrl =
      TextEditingController(text: widget.existing?.model ?? 'gpt-4o-mini');
  late LlmProvider _provider =
      widget.existing?.provider ?? LlmProvider.openai;
  bool _showKey = false;

  // 模型列表相关状态
  List<String> _availableModels = [];
  bool _isFetchingModels = false;
  String? _fetchModelError;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _baseUrlCtrl.dispose();
    _apiKeyCtrl.dispose();
    _modelCtrl.dispose();
    super.dispose();
  }

  String get _defaultBaseUrl => switch (_provider) {
        LlmProvider.openai => 'https://api.openai.com/v1',
        LlmProvider.anthropic => 'https://api.anthropic.com',
        LlmProvider.custom => '',
      };

  /// 向 API 站点请求可用模型列表
  Future<void> _fetchModels() async {
    final baseUrl = _baseUrlCtrl.text.trim().isEmpty
        ? _defaultBaseUrl
        : _baseUrlCtrl.text.trim();
    final apiKey = _apiKeyCtrl.text.trim();

    if (apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先填写 API Key')),
      );
      return;
    }

    setState(() {
      _isFetchingModels = true;
      _fetchModelError = null;
    });

    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ));

      List<String> models;

      if (_provider == LlmProvider.anthropic) {
        // Anthropic: GET {baseUrl}/v1/models
        final resp = await dio.get(
          '$baseUrl/v1/models',
          options: Options(headers: {
            'x-api-key': apiKey,
            'anthropic-version': '2023-06-01',
          }),
        );
        final list = (resp.data['data'] as List?) ?? [];
        models = list
            .map((m) => m['id'] as String)
            .toList()
          ..sort();
      } else {
        // OpenAI 兼容协议: GET {baseUrl}/models
        final resp = await dio.get(
          '$baseUrl/models',
          options: Options(headers: {
            'Authorization': 'Bearer $apiKey',
          }),
        );
        final list = (resp.data['data'] as List?) ?? [];
        models = list
            .map((m) => m['id'] as String)
            .toList()
          ..sort();
      }

      if (!mounted) return;
      setState(() {
        _availableModels = models;
        _isFetchingModels = false;
        // 若当前填写的模型不在列表里，自动选第一个
        if (models.isNotEmpty && !models.contains(_modelCtrl.text)) {
          _modelCtrl.text = models.first;
        }
      });
    } on DioException catch (e) {
      if (!mounted) return;
      String msg;
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        msg = '连接超时，请检查 URL 是否正确';
      } else if (e.type == DioExceptionType.connectionError) {
        msg = '无法连接到服务器，请检查 URL 和网络';
      } else if (e.response != null) {
        msg = 'HTTP ${e.response!.statusCode}：${e.response!.statusMessage}';
      } else {
        msg = '请求失败：${e.message}';
      }
      setState(() {
        _isFetchingModels = false;
        _fetchModelError = msg;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isFetchingModels = false;
        _fetchModelError = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 确保 dropdown 当前值在列表里（避免 Flutter 断言）
    final dropdownModels = {
      ..._availableModels,
      if (_modelCtrl.text.isNotEmpty) _modelCtrl.text,
    }.toList()
      ..sort();

    return AlertDialog(
      title: Text(widget.existing == null ? '添加 API 配置' : '编辑 API 配置'),
      scrollable: true,
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 名称
            TextField(
              controller: _nameCtrl,
              decoration:
                  const InputDecoration(labelText: '名称', hintText: 'My API'),
            ),
            const SizedBox(height: 12),
            // Provider
            DropdownButtonFormField<LlmProvider>(
              initialValue: _provider,
              decoration: const InputDecoration(labelText: '类型'),
              items: LlmProvider.values
                  .map((p) => DropdownMenuItem(
                        value: p,
                        child: Text(p.name.toUpperCase()),
                      ))
                  .toList(),
              onChanged: (p) {
                if (p == null) return;
                setState(() {
                  _provider = p;
                  // 切换 Provider 时重置模型列表
                  _availableModels = [];
                  _fetchModelError = null;
                  if (_baseUrlCtrl.text.isEmpty) {
                    _baseUrlCtrl.text = _defaultBaseUrl;
                  }
                });
              },
            ),
            const SizedBox(height: 12),
            // Base URL
            TextField(
              controller: _baseUrlCtrl,
              decoration: InputDecoration(
                labelText: 'Base URL',
                hintText: _defaultBaseUrl,
              ),
            ),
            const SizedBox(height: 12),
            // API Key
            TextField(
              controller: _apiKeyCtrl,
              obscureText: !_showKey,
              decoration: InputDecoration(
                labelText: 'API Key',
                hintText: 'sk-...',
                suffixIcon: IconButton(
                  icon: Icon(
                      _showKey ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _showKey = !_showKey),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // 模型（手动输入 + 自动获取）
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: _availableModels.isEmpty
                      // 未获取时：手动输入框
                      ? TextField(
                          controller: _modelCtrl,
                          decoration: InputDecoration(
                            labelText: '模型',
                            hintText: 'gpt-4o-mini',
                            errorText: _fetchModelError,
                            errorMaxLines: 2,
                          ),
                        )
                      // 已获取时：下拉选择
                      : DropdownButtonFormField<String>(
                          key: ValueKey(_availableModels.join(',')),
                          initialValue: _modelCtrl.text.isNotEmpty &&
                                  dropdownModels.contains(_modelCtrl.text)
                              ? _modelCtrl.text
                              : dropdownModels.first,
                          decoration: const InputDecoration(labelText: '模型'),
                          isExpanded: true,
                          items: dropdownModels
                              .map((m) => DropdownMenuItem(
                                    value: m,
                                    child: Text(
                                      m,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setState(() => _modelCtrl.text = v);
                            }
                          },
                        ),
                ),
                const SizedBox(width: 4),
                // 获取模型按钮
                SizedBox(
                  height: 48,
                  child: _isFetchingModels
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          icon: Icon(
                            _availableModels.isEmpty
                                ? Icons.cloud_download_outlined
                                : Icons.refresh,
                            color: WeChatColors.primary,
                          ),
                          tooltip: '从 API 获取模型列表',
                          onPressed: _fetchModels,
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消')),
        ElevatedButton(
          onPressed: () {
            if (_nameCtrl.text.trim().isEmpty ||
                _apiKeyCtrl.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('名称和 API Key 不能为空')));
              return;
            }
            final config = ApiConfig(
              id: widget.existing?.id ?? '',
              name: _nameCtrl.text.trim(),
              provider: _provider,
              baseUrl: _baseUrlCtrl.text.trim().isEmpty
                  ? _defaultBaseUrl
                  : _baseUrlCtrl.text.trim(),
              apiKey: _apiKeyCtrl.text.trim(),
              model: _modelCtrl.text.trim().isEmpty
                  ? 'gpt-4o-mini'
                  : _modelCtrl.text.trim(),
            );
            Navigator.of(context).pop(config);
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}
