import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/contact.dart';
import '../../models/character_card.dart';
import '../../providers/contacts_provider.dart';
import '../../providers/api_config_provider.dart';
import '../../theme/wechat_colors.dart';
import '../../widgets/avatar_widget.dart';

class ContactDetailPage extends ConsumerWidget {
  final String contactId;
  final Contact? contact;

  const ContactDetailPage({
    super.key,
    required this.contactId,
    this.contact,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactAsync = ref.watch(contactsProvider).whenData(
          (list) => list.where((c) => c.id == contactId).firstOrNull,
        );
    final resolved = contactAsync.value ?? contact;

    if (resolved == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('联系人资料')),
        body: const Center(child: Text('联系人不存在')),
      );
    }

    return _ContactDetailView(contact: resolved);
  }
}

class _ContactDetailView extends ConsumerWidget {
  final Contact contact;
  const _ContactDetailView({required this.contact});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configs = ref.watch(apiConfigProvider).value ?? [];
    final boundConfig = configs.where((c) => c.id == contact.apiConfigId).firstOrNull;

    CharacterCard? card;
    if (contact.characterCardJson != null) {
      try {
        final json = jsonDecode(contact.characterCardJson!) as Map<String, dynamic>;
        card = CharacterCard.fromV2Json(json);
      } catch (_) {}
    }

    return Scaffold(
      backgroundColor: WeChatColors.background,
      appBar: AppBar(
        backgroundColor: WeChatColors.appBarBackground,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('联系人资料'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'edit') await _editContact(context, ref, configs);
              if (!context.mounted) return;
              if (v == 'delete') await _deleteContact(context, ref);
              if (!context.mounted) return;
              if (v == 'chat') {
                context.pop();
                context.push('/chat/${contact.id}', extra: contact);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'chat', child: Text('发消息')),
              PopupMenuItem(value: 'edit', child: Text('编辑')),
              PopupMenuItem(
                  value: 'delete',
                  child: Text('删除', style: TextStyle(color: Colors.red))),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 头部：头像 + 名称
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  AvatarWidget.fromContact(contact, size: 72),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(contact.name,
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w600)),
                        if (contact.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(contact.description,
                              style: const TextStyle(
                                  color: WeChatColors.textSecondary,
                                  fontSize: 13)),
                        ],
                        if (contact.tags.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            children: contact.tags
                                .map((t) => Chip(
                                      label: Text(t,
                                          style:
                                              const TextStyle(fontSize: 11)),
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      padding: EdgeInsets.zero,
                                      backgroundColor:
                                          WeChatColors.primary.withAlpha(26),
                                    ))
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // 自动行为开关
            Container(
              color: Colors.white,
              child: SwitchListTile(
                secondary: const Icon(Icons.auto_mode, color: WeChatColors.primary),
                title: const Text('允许主动联系'),
                subtitle: const Text('AI 会主动发送消息和互动',
                    style: TextStyle(fontSize: 12)),
                value: contact.proactiveEnabled,
                activeThumbColor: WeChatColors.primary,
                onChanged: (v) => ref
                    .read(contactsProvider.notifier)
                    .updateContact(contact.copyWith(proactiveEnabled: v)),
              ),
            ),
            const SizedBox(height: 8),

            // 发消息按钮
            Container(
              color: Colors.white,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.chat_bubble_outline,
                        color: WeChatColors.primary),
                    title: const Text('发消息'),
                    onTap: () {
                      context.pop();
                      context.push('/chat/${contact.id}', extra: contact);
                    },
                  ),
                  const Divider(height: 0, indent: 56),
                  ListTile(
                    leading: const Icon(Icons.psychology_outlined,
                        color: WeChatColors.primary),
                    title: const Text('记忆表格'),
                    subtitle: const Text('查看 AI 记住的关键信息',
                        style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right,
                        color: WeChatColors.textHint),
                    onTap: () {
                      context.push('/memory/${contact.id}', extra: contact);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // 绑定的 API
            Container(
              color: Colors.white,
              child: ListTile(
                leading:
                    const Icon(Icons.api, color: WeChatColors.textSecondary),
                title: const Text('绑定 API'),
                subtitle: Text(boundConfig?.name ?? '未绑定（使用默认）',
                    style: const TextStyle(fontSize: 13)),
                trailing: const Icon(Icons.chevron_right,
                    color: WeChatColors.textHint),
                onTap: () => _showApiPicker(context, ref, configs),
              ),
            ),
            const SizedBox(height: 8),

            // 角色卡信息
            if (card != null) ...[
              _CharacterCardSection(card: card),
              const SizedBox(height: 8),
            ],

            // System Prompt
            if (contact.systemPrompt.isNotEmpty) ...[
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('System Prompt',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: WeChatColors.textSecondary,
                            fontSize: 13)),
                    const SizedBox(height: 8),
                    Text(contact.systemPrompt,
                        style: const TextStyle(fontSize: 14)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showApiPicker(
      BuildContext context, WidgetRef ref, List configs) async {
    final selected = await showModalBottomSheet<String?>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('选择 API 配置',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            ListTile(
              leading: const Icon(Icons.block, color: WeChatColors.textHint),
              title: const Text('不绑定（使用默认）'),
              selected: contact.apiConfigId == null,
              onTap: () => Navigator.of(ctx).pop('__none__'),
            ),
            ...configs.map((c) => ListTile(
                  leading:
                      const Icon(Icons.api, color: WeChatColors.primary),
                  title: Text(c.name),
                  subtitle: Text('${c.model}',
                      style: const TextStyle(fontSize: 12)),
                  selected: contact.apiConfigId == c.id,
                  onTap: () => Navigator.of(ctx).pop(c.id as String),
                )),
            if (configs.isEmpty)
              ListTile(
                leading:
                    const Icon(Icons.add, color: WeChatColors.primary),
                title: const Text('前往添加 API 配置'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  context.push('/settings/api');
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selected == null) return;
    final newConfigId = selected == '__none__' ? null : selected;
    final updated = contact.copyWith(apiConfigId: newConfigId);
    await ref.read(contactsProvider.notifier).updateContact(updated);
  }

  Future<void> _editContact(
      BuildContext context, WidgetRef ref, configs) async {
    final result = await showDialog<Contact>(
      context: context,
      builder: (ctx) => _EditContactInlineDialog(
        contact: contact,
        configs: configs,
      ),
    );
    if (result != null) {
      await ref.read(contactsProvider.notifier).updateContact(result);
    }
  }

  Future<void> _deleteContact(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除联系人'),
        content: Text('确定删除 "${contact.name}"？相关聊天记录将一并删除。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('删除', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(contactsProvider.notifier).remove(contact.id);
      if (context.mounted) context.pop();
    }
  }
}

class _CharacterCardSection extends StatefulWidget {
  final CharacterCard card;
  const _CharacterCardSection({required this.card});

  @override
  State<_CharacterCardSection> createState() => _CharacterCardSectionState();
}

class _CharacterCardSectionState extends State<_CharacterCardSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          ListTile(
            leading:
                const Icon(Icons.person_pin, color: WeChatColors.primary),
            title: const Text('角色卡',
                style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: card.creator.isNotEmpty
                ? Text('作者: ${card.creator}')
                : null,
            trailing: IconButton(
              icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
              onPressed: () => setState(() => _expanded = !_expanded),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (card.description.isNotEmpty)
                    _InfoRow('描述', card.description),
                  if (card.personality.isNotEmpty)
                    _InfoRow('性格', card.personality),
                  if (card.scenario.isNotEmpty)
                    _InfoRow('场景', card.scenario),
                  if (card.firstMes.isNotEmpty)
                    _InfoRow('开场白', card.firstMes),
                  if (card.tags.isNotEmpty)
                    _InfoRow('标签', card.tags.join(', ')),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  color: WeChatColors.textSecondary,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}

class _EditContactInlineDialog extends StatefulWidget {
  final Contact contact;
  final List configs;
  const _EditContactInlineDialog(
      {required this.contact, required this.configs});

  @override
  State<_EditContactInlineDialog> createState() =>
      _EditContactInlineDialogState();
}

class _EditContactInlineDialogState extends State<_EditContactInlineDialog> {
  late final _nameCtrl =
      TextEditingController(text: widget.contact.name);
  late final _descCtrl =
      TextEditingController(text: widget.contact.description);
  late final _promptCtrl =
      TextEditingController(text: widget.contact.systemPrompt);
  late final String? _selectedConfigId = widget.contact.apiConfigId;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _promptCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('编辑联系人'),
      scrollable: true,
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: '名称')),
            const SizedBox(height: 12),
            TextField(
                controller: _descCtrl,
                decoration: const InputDecoration(labelText: '简介'),
                maxLines: 2),
            const SizedBox(height: 12),
            TextField(
                controller: _promptCtrl,
                decoration:
                    const InputDecoration(labelText: 'System Prompt'),
                maxLines: 4),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消')),
        ElevatedButton(
          onPressed: () {
            if (_nameCtrl.text.trim().isEmpty) return;
            Navigator.of(context).pop(
              widget.contact.copyWith(
                name: _nameCtrl.text.trim(),
                description: _descCtrl.text.trim(),
                systemPrompt: _promptCtrl.text.trim(),
                apiConfigId: _selectedConfigId,
              ),
            );
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}
