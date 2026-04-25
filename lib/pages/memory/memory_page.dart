import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/memory_entry.dart';
import '../../models/contact.dart';
import '../../providers/memory_provider.dart';
import '../../providers/api_config_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/wechat_colors.dart';

class MemoryPage extends ConsumerStatefulWidget {
  final String contactId;
  final Contact? contact;

  const MemoryPage({
    super.key,
    required this.contactId,
    this.contact,
  });

  @override
  ConsumerState<MemoryPage> createState() => _MemoryPageState();
}

class _MemoryPageState extends ConsumerState<MemoryPage> {
  bool _isExtracting = false;

  @override
  Widget build(BuildContext context) {
    final memoriesAsync = ref.watch(memoryProvider(widget.contactId));
    final settings = ref.watch(settingsProvider).value;

    return Scaffold(
      backgroundColor: WeChatColors.background,
      appBar: AppBar(
        backgroundColor: WeChatColors.appBarBackground,
        title: Text('${widget.contact?.name ?? ""}的记忆'),
        actions: [
          if (_isExtracting)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: '立即提取记忆',
              onPressed: () => _extractNow(context),
            ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'clear') _clearMemories(context);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'clear',
                child: Text('清空记忆', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ],
      ),
      body: memoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        data: (entries) {
          if (entries.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.psychology_outlined,
                      size: 64, color: WeChatColors.textHint),
                  const SizedBox(height: 12),
                  const Text('暂无记忆',
                      style: TextStyle(color: WeChatColors.textSecondary)),
                  const SizedBox(height: 8),
                  Text(
                    settings?.memoryEnabled == true
                        ? '聊天时将自动提取记忆'
                        : '请在通用设置中启用记忆表格',
                    style: const TextStyle(
                        fontSize: 12, color: WeChatColors.textHint),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('立即提取'),
                    onPressed: () => _extractNow(context),
                  ),
                ],
              ),
            );
          }
          return _buildMemoryTable(entries);
        },
      ),
    );
  }

  Widget _buildMemoryTable(List<MemoryEntry> entries) {
    final categories = <String, List<MemoryEntry>>{};
    for (final entry in entries) {
      categories.putIfAbsent(entry.category, () => []).add(entry);
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        for (final cat in categories.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              cat.key,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: WeChatColors.primary,
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                for (var i = 0; i < cat.value.length; i++) ...[
                  if (i > 0) const Divider(height: 0, indent: 16),
                  _MemoryEntryTile(
                    entry: cat.value[i],
                    onDelete: () {
                      ref
                          .read(memoryProvider(widget.contactId).notifier)
                          .deleteEntry(cat.value[i].id);
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _extractNow(BuildContext context) async {
    final configs = ref.read(apiConfigProvider).value ?? [];
    if (configs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先配置 API')),
      );
      return;
    }

    final settings = ref.read(settingsProvider).value;
    final apiConfig = configs.first;

    if (settings?.memoryUseMainApi == false && configs.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('副 API 未配置，将使用主 API')),
      );
    }

    final selectedConfig =
        (settings?.memoryUseMainApi == false && configs.length >= 2)
            ? configs[1]
            : apiConfig;

    setState(() => _isExtracting = true);
    try {
      await ref
          .read(memoryProvider(widget.contactId).notifier)
          .extractMemories(selectedConfig);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('记忆提取完成')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('提取失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExtracting = false);
    }
  }

  Future<void> _clearMemories(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空记忆'),
        content: const Text('确定清空该联系人的所有记忆？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('清空', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      await ref
          .read(memoryProvider(widget.contactId).notifier)
          .clearAll();
    }
  }
}

class _MemoryEntryTile extends StatelessWidget {
  final MemoryEntry entry;
  final VoidCallback onDelete;

  const _MemoryEntryTile({
    required this.entry,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(entry.key,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      subtitle: Text(entry.value,
          style: const TextStyle(fontSize: 13)),
      trailing: IconButton(
        icon: const Icon(Icons.close, size: 16, color: WeChatColors.textHint),
        onPressed: onDelete,
      ),
      dense: true,
    );
  }
}
