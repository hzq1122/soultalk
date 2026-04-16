import 'package:flutter/material.dart';
import '../../../theme/wechat_colors.dart';
import '../../../models/message.dart';
import '../../../widgets/avatar_widget.dart';
import '../../../models/contact.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final Contact contact;
  final bool showAvatar;

  const MessageBubble({
    super.key,
    required this.message,
    required this.contact,
    this.showAvatar = true,
  });

  bool get _isUser => message.role == MessageRole.user;
  bool get _isSystem => message.role == MessageRole.system;

  @override
  Widget build(BuildContext context) {
    if (_isSystem || message.type == MessageType.system) {
      return _SystemMessage(content: message.content);
    }
    if (message.type == MessageType.transfer) {
      return _TransferBubble(message: message, isUser: _isUser);
    }
    return _TextBubble(message: message, contact: contact, showAvatar: showAvatar);
  }
}

class _TextBubble extends StatelessWidget {
  final Message message;
  final Contact contact;
  final bool showAvatar;

  const _TextBubble({
    required this.message,
    required this.contact,
    required this.showAvatar,
  });

  bool get _isUser => message.role == MessageRole.user;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisAlignment:
            _isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_isUser && showAvatar) ...[
            AvatarWidget.fromContact(contact, size: 40),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: _isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: _isUser
                        ? WeChatColors.bubbleSent
                        : WeChatColors.bubbleReceived,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(_isUser ? 12 : 2),
                      topRight: Radius.circular(_isUser ? 2 : 12),
                      bottomLeft: const Radius.circular(12),
                      bottomRight: const Radius.circular(12),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(13),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.65,
                  ),
                  child: message.isStreaming
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                message.content,
                                style: const TextStyle(
                                    fontSize: 16,
                                    color: WeChatColors.textPrimary),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(strokeWidth: 1.5),
                            ),
                          ],
                        )
                      : SelectableText(
                          message.content,
                          style: const TextStyle(
                              fontSize: 16, color: WeChatColors.textPrimary),
                        ),
                ),
              ],
            ),
          ),
          if (_isUser && showAvatar) ...[
            const SizedBox(width: 8),
            const CircleAvatar(
              radius: 20,
              backgroundColor: WeChatColors.primary,
              child: Icon(Icons.person, color: Colors.white, size: 20),
            ),
          ],
        ],
      ),
    );
  }
}

class _SystemMessage extends StatelessWidget {
  final String content;
  const _SystemMessage({required this.content});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFE5E5E5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            content,
            style: const TextStyle(
                fontSize: 12, color: WeChatColors.textSecondary),
          ),
        ),
      ),
    );
  }
}

class _TransferBubble extends StatelessWidget {
  final Message message;
  final bool isUser;
  const _TransferBubble({required this.message, required this.isUser});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: isUser ? 60 : 12,
        right: isUser ? 12 : 60,
        top: 4,
        bottom: 4,
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: WeChatColors.divider),
        ),
        child: Row(
          children: [
            const Icon(Icons.account_balance_wallet,
                color: WeChatColors.primary, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message.content,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w500)),
                  const Text('微信转账',
                      style: TextStyle(
                          fontSize: 12, color: WeChatColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
