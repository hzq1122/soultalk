import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import '../../../core/app_paths.dart';
import '../../../theme/wechat_colors.dart';
import '../../../models/message.dart';
import '../../../models/regex_script.dart';
import '../../../widgets/avatar_widget.dart';
import '../../../models/contact.dart';
import '../../../providers/regex_script_provider.dart';
import '../../../services/regex/regex_service.dart';

class MessageBubble extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    if (_isSystem || message.type == MessageType.system) {
      return _SystemMessage(content: message.content);
    }
    if (message.type == MessageType.transfer) {
      return _TransferBubble(message: message, isUser: _isUser);
    }
    if (message.type == MessageType.delivery) {
      return _DeliveryBubble(message: message, isUser: _isUser);
    }
    if (message.type == MessageType.image) {
      return _ImageBubble(message: message, isUser: _isUser);
    }
    if (message.type == MessageType.file) {
      return _FileBubble(message: message, isUser: _isUser);
    }

    final scripts = ref.watch(enabledRegexScriptsProvider);
    final displayContent = _applyRegex(message, scripts);

    return _TextBubble(
      message: message,
      contact: contact,
      showAvatar: showAvatar,
      displayContent: displayContent,
    );
  }

  String _applyRegex(Message msg, List<RegexScript> scripts) {
    if (scripts.isEmpty) return msg.content;
    const service = RegexService();
    final placement = msg.role == MessageRole.user
        ? RegexPlacement.userInput
        : RegexPlacement.aiOutput;
    // 注意：promptOnly（ST ephemeral-prompt）脚本只注入 prompt，
    // 不改变 UI 显示文本——UI 路径排除。
    return service.applyScripts(
      msg.content,
      scripts,
      placement,
      includePromptOnly: false,
    );
  }
}

Map<dynamic, dynamic>? _attachmentMetadata(Message message) {
  final attachment = message.metadata?['attachment'];
  return attachment is Map ? attachment : null;
}

String? _nonEmptyString(Object? value) {
  return value is String && value.isNotEmpty ? value : null;
}

int? _intValue(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return null;
}

/// 解析消息附件文件。返回 null 表示路径无效（越界/绝对路径逃逸）。
/// 安全：所有路径必须解析到应用根目录内（canonical 校验，拦截 `../` 与
/// 任意绝对路径），防止恶意备份/同步数据读取应用目录外的文件。
Future<File?> _resolveMessageFile(Message message) async {
  final metadata = message.metadata;
  final attachment = _attachmentMetadata(message);
  final relativePath =
      _nonEmptyString(attachment?['relative_path']) ??
      _nonEmptyString(metadata?['relative_path']);
  if (relativePath != null) {
    final paths = await AppPaths.create();
    final candidate = File(p.join(paths.root.path, relativePath));
    if (await _withinRootCanonical(paths.root, candidate)) return candidate;
    return null;
  }

  final legacyPath = _nonEmptyString(metadata?['path']);
  final fallback = legacyPath ?? message.content;
  if (fallback.isEmpty) return null;
  final paths = await AppPaths.create();
  final direct = File(fallback);
  if (direct.isAbsolute) {
    // 绝对路径：仅允许位于应用目录内的文件
    if (await _withinRootCanonical(paths.root, direct)) return direct;
    return null;
  }
  // 相对路径：解析到应用根目录内后校验
  final resolved = File(p.normalize(p.join(paths.root.path, fallback)));
  if (await _withinRootCanonical(paths.root, resolved)) return resolved;
  return null;
}

/// OS 级 canonical 边界校验：先 resolveSymbolicLinks 解析符号链接/
/// junction，再确认文件真实路径位于应用根目录内（或等于 root），
/// 防止应用目录内的符号链接越界读取目录外文件。
/// 文件不存在/无法解析时回退到字符串级 normalize + isWithin。
Future<bool> _withinRootCanonical(Directory root, File file) async {
  try {
    final rootPath = p.normalize(await root.resolveSymbolicLinks());
    final filePath = p.normalize(await file.resolveSymbolicLinks());
    return filePath == rootPath || p.isWithin(rootPath, filePath);
  } catch (_) {
    final rootPath = p.normalize(p.absolute(root.path));
    final filePath = p.normalize(p.absolute(file.path));
    return filePath == rootPath || p.isWithin(rootPath, filePath);
  }
}

class _TextBubble extends StatelessWidget {
  final Message message;
  final Contact contact;
  final bool showAvatar;
  final String displayContent;

  const _TextBubble({
    required this.message,
    required this.contact,
    required this.showAvatar,
    required this.displayContent,
  });

  bool get _isUser => message.role == MessageRole.user;

  @override
  Widget build(BuildContext context) {
    final reasoningContent = message.metadata?['reasoning_content'] as String?;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisAlignment: _isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
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
                if (reasoningContent != null && reasoningContent.isNotEmpty)
                  _ThinkingSection(content: reasoningContent),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SelectableText(
                        displayContent.isEmpty && message.isFailed
                            ? '（发送失败）'
                            : displayContent,
                        style: const TextStyle(
                          fontSize: 16,
                          color: WeChatColors.textPrimary,
                        ),
                      ),
                      if (message.isFailed && !_isUser)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                size: 14,
                                color: Colors.redAccent,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                displayContent.isEmpty
                                    ? '发送失败，长按消息重试'
                                    : '生成中断，长按消息重新生成',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.redAccent,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
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

class _ThinkingSection extends StatefulWidget {
  final String content;
  const _ThinkingSection({required this.content});

  @override
  State<_ThinkingSection> createState() => _ThinkingSectionState();
}

class _ThinkingSectionState extends State<_ThinkingSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.grey.withAlpha(18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.psychology,
                    size: 14,
                    color: WeChatColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    '思考过程',
                    style: TextStyle(
                      fontSize: 11,
                      color: WeChatColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 14,
                    color: WeChatColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
              child: Text(
                widget.content,
                style: const TextStyle(
                  fontSize: 12,
                  color: WeChatColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ),
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
              fontSize: 12,
              color: WeChatColors.textSecondary,
            ),
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
    final amount = message.metadata?['amount'] ?? '';
    final remark = message.metadata?['remark'] ?? '转账';
    final displayContent = amount.isNotEmpty ? '¥$amount' : message.content;
    return Padding(
      padding: EdgeInsets.only(
        left: isUser ? 60 : 12,
        right: isUser ? 12 : 60,
        top: 4,
        bottom: 4,
      ),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 240,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: const Color(0xFFF89C38),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Icon(
                      Icons.monetization_on,
                      color: Colors.white,
                      size: 36,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayContent,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          if (remark.isNotEmpty)
                            Text(
                              remark,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xAAFFFFFF),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFFF5E3C6),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                ),
                child: const Text(
                  '微信转账',
                  style: TextStyle(fontSize: 11, color: Color(0xFF9B7B4F)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImageBubble extends StatelessWidget {
  final Message message;
  final bool isUser;
  const _ImageBubble({required this.message, required this.isUser});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<File?>(
      future: _resolveMessageFile(message),
      builder: (context, snapshot) {
        final file = snapshot.data;
        final exists = file?.existsSync() ?? false;

        return Padding(
          padding: EdgeInsets.only(
            left: isUser ? 60 : 12,
            right: isUser ? 12 : 60,
            top: 4,
            bottom: 4,
          ),
          child: Align(
            alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: exists
                  ? Image.file(
                      file!,
                      width: 200,
                      height: 200,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _missingImagePlaceholder(Icons.broken_image),
                    )
                  : _missingImagePlaceholder(Icons.image),
            ),
          ),
        );
      },
    );
  }

  Widget _missingImagePlaceholder(IconData icon) {
    return Container(
      width: 200,
      height: 200,
      color: WeChatColors.textHint.withAlpha(50),
      child: Icon(icon, color: WeChatColors.textHint, size: 48),
    );
  }
}

class _FileBubble extends StatelessWidget {
  final Message message;
  final bool isUser;
  const _FileBubble({required this.message, required this.isUser});

  @override
  Widget build(BuildContext context) {
    final attachment = _attachmentMetadata(message);
    final name = _nonEmptyString(attachment?['name']) ?? message.content;
    final size = _intValue(attachment?['size']);
    return Padding(
      padding: EdgeInsets.only(
        left: isUser ? 60 : 12,
        right: isUser ? 12 : 60,
        top: 4,
        bottom: 4,
      ),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _openFile(context),
          child: Container(
            width: 260,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isUser ? WeChatColors.bubbleSent : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: WeChatColors.divider),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.insert_drive_file_outlined,
                  color: WeChatColors.textSecondary,
                  size: 36,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          color: WeChatColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (size != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _formatBytes(size),
                          style: const TextStyle(
                            fontSize: 12,
                            color: WeChatColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openFile(BuildContext context) async {
    final file = await _resolveMessageFile(message);
    if (file == null || !await file.exists()) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(file == null ? '文件路径无效' : '文件不存在')),
      );
      return;
    }
    await OpenFilex.open(file.path);
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
    return '${(mb / 1024).toStringAsFixed(1)} GB';
  }
}

class _DeliveryBubble extends StatelessWidget {
  final Message message;
  final bool isUser;
  const _DeliveryBubble({required this.message, required this.isUser});

  @override
  Widget build(BuildContext context) {
    final shop = message.metadata?['shop'] ?? '外卖店铺';
    final items = message.metadata?['items'] ?? message.content;
    final price = message.metadata?['price'] ?? '';
    return Padding(
      padding: EdgeInsets.only(
        left: isUser ? 60 : 12,
        right: isUser ? 12 : 60,
        top: 4,
        bottom: 4,
      ),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 240,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: WeChatColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Color(0xFF00B578),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(7),
                    topRight: Radius.circular(7),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.fastfood, color: Colors.white, size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        shop,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(items, style: const TextStyle(fontSize: 13)),
                    if (price.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        '¥$price',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFFF6B35),
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    const Text(
                      '美团外卖',
                      style: TextStyle(
                        fontSize: 11,
                        color: WeChatColors.textHint,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
