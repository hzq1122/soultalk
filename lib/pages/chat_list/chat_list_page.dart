import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/contacts_provider.dart';
import '../../models/contact.dart';
import '../../theme/wechat_colors.dart';
import '../../widgets/avatar_widget.dart';

class ChatListPage extends ConsumerWidget {
  const ChatListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactsAsync = ref.watch(contactsProvider);

    return Scaffold(
      backgroundColor: WeChatColors.background,
      appBar: AppBar(
        title: const Text('AI Chat'),
        backgroundColor: WeChatColors.appBarBackground,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => _showAddMenu(context),
          ),
        ],
      ),
      body: contactsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        data: (contacts) {
          // 过滤出有消息记录的联系人（显示在会话列表）
          final conversations = contacts
              .where((c) => c.lastMessage != null || c.unreadCount > 0)
              .toList();

          if (conversations.isEmpty) {
            return _buildEmpty(context);
          }

          return RefreshIndicator(
            onRefresh: () async => ref.refresh(contactsProvider),
            child: ListView.builder(
              itemCount: conversations.length,
              itemBuilder: (context, index) {
                return _ConversationTile(contact: conversations[index]);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.chat_bubble_outline,
              size: 64, color: WeChatColors.textHint),
          const SizedBox(height: 12),
          const Text('暂无会话',
              style: TextStyle(color: WeChatColors.textSecondary)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => context.go('/contacts'),
            child: const Text('去通讯录添加联系人'),
          ),
        ],
      ),
    );
  }

  void _showAddMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_add_outlined),
              title: const Text('新建联系人'),
              onTap: () {
                ctx.pop();
                context.go('/contacts');
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('API 设置'),
              onTap: () {
                ctx.pop();
                context.push('/settings/api');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationTile extends ConsumerWidget {
  final Contact contact;
  const _ConversationTile({required this.contact});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: ValueKey(contact.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('删除会话'),
            content: Text('确定删除与 ${contact.name} 的会话记录？'),
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
      },
      onDismissed: (_) {
        // 只清空会话记录，不删除联系人
        final updated = contact.copyWith(
          lastMessage: null,
          lastMessageAt: null,
          unreadCount: 0,
        );
        ref.read(contactsProvider.notifier).updateContact(updated);
      },
      child: InkWell(
        onTap: () {
          ref.read(contactsProvider.notifier).clearUnread(contact.id);
          context.push('/chat/${contact.id}', extra: contact);
        },
        child: Container(
          color: contact.pinned ? const Color(0xFFF0F0F0) : Colors.white,
          child: Row(
            children: [
              if (contact.pinned)
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(Icons.push_pin, size: 14, color: WeChatColors.textHint),
                )
              else
                const SizedBox(width: 10),
              // 头像 + 未读角标
              Stack(
                children: [
                  AvatarWidget.fromContact(contact, size: 48),
                  if (contact.unreadCount > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: WeChatColors.unreadBadge,
                          shape: BoxShape.circle,
                        ),
                        constraints:
                            const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          contact.unreadCount > 99
                              ? '99+'
                              : '${contact.unreadCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              // 名称 + 消息预览
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: WeChatColors.divider, width: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              contact.name,
                              style: const TextStyle(
                                fontSize: 16,
                                color: WeChatColors.textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (contact.lastMessage != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                contact.lastMessage!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: WeChatColors.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (contact.lastMessageAt != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          _formatTime(contact.lastMessageAt!),
                          style: const TextStyle(
                            fontSize: 11,
                            color: WeChatColors.textHint,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    // 用日历日期比较，避免跨午夜边界误判
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(dt.year, dt.month, dt.day);
    final dayDiff = today.difference(msgDay).inDays;

    if (dayDiff == 0) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else if (dayDiff == 1) {
      return '昨天';
    } else if (dayDiff < 7) {
      const weeks = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];
      return weeks[dt.weekday];
    } else {
      return '${dt.month}/${dt.day}';
    }
  }
}
