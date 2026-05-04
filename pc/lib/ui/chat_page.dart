import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/connection_provider.dart';
import '../websocket_client.dart';
import '../theme/desktop_theme.dart';

class ChatPage extends ConsumerStatefulWidget {
  final String contactId;

  const ChatPage({super.key, required this.contactId});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connState = ref.watch(pcConnectionProvider);
    final messages = connState.messages
        .where((m) => m['contactId'] == widget.contactId)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('聊天 - ${widget.contactId}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () =>
                ref.read(pcConnectionProvider.notifier).requestSync(),
          ),
        ],
      ),
      body: Column(
        children: [
          // 连接状态提示
          if (connState.connectionState != WsConnectionState.connected)
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.orange.shade100,
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber,
                    size: 16,
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    connState.connectionState == WsConnectionState.reconnecting
                        ? '正在重连...'
                        : '未连接到手机',
                    style: const TextStyle(fontSize: 12, color: Colors.orange),
                  ),
                ],
              ),
            ),

          // 消息列表
          Expanded(
            child: messages.isEmpty
                ? const Center(
                    child: Text(
                      '暂无消息',
                      style: TextStyle(color: DesktopTheme.textHint),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final isFromPC = msg['fromPC'] == true;
                      return _MessageBubble(
                        content: msg['content'] as String? ?? '',
                        isFromPC: isFromPC,
                        timestamp: msg['timestamp'] as String?,
                      );
                    },
                  ),
          ),

          // 输入框
          if (connState.connectionState == WsConnectionState.connected)
            _buildInputBar(ref),
        ],
      ),
    );
  }

  Widget _buildInputBar(WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: DesktopTheme.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                hintText: '输入消息...',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              maxLines: null,
              onSubmitted: (_) => _send(ref),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(onPressed: () => _send(ref), child: const Text('发送')),
        ],
      ),
    );
  }

  void _send(WidgetRef ref) {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    ref
        .read(pcConnectionProvider.notifier)
        .sendMessage(widget.contactId, content);
    _messageController.clear();

    // 滚动到底部
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }
}

class _MessageBubble extends StatelessWidget {
  final String content;
  final bool isFromPC;
  final String? timestamp;

  const _MessageBubble({
    required this.content,
    required this.isFromPC,
    this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isFromPC ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        decoration: BoxDecoration(
          color: isFromPC ? DesktopTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: isFromPC ? null : Border.all(color: DesktopTheme.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              content,
              style: TextStyle(
                color: isFromPC ? Colors.white : DesktopTheme.textPrimary,
                fontSize: 14,
              ),
            ),
            if (timestamp != null) ...[
              const SizedBox(height: 4),
              Text(
                _formatTime(timestamp!),
                style: TextStyle(
                  fontSize: 10,
                  color: isFromPC
                      ? Colors.white.withValues(alpha: 0.7)
                      : DesktopTheme.textHint,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTime(String timestamp) {
    try {
      final dt = DateTime.parse(timestamp);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }
}
