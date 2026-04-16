import 'package:flutter/material.dart';
import '../../../theme/wechat_colors.dart';

class InputBar extends StatefulWidget {
  final void Function(String text) onSend;
  final bool enabled;

  const InputBar({
    super.key,
    required this.onSend,
    this.enabled = true,
  });

  @override
  State<InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<InputBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final has = _controller.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty || !widget.enabled) return;
    _controller.clear();
    setState(() => _hasText = false);
    widget.onSend(text);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF7F7F7),
        border: Border(top: BorderSide(color: WeChatColors.divider, width: 0.5)),
      ),
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
        top: 8,
        bottom: 8 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // 语音按钮（占位）
            IconButton(
              icon: const Icon(Icons.mic_none, color: WeChatColors.textSecondary),
              onPressed: widget.enabled ? () {} : null,
            ),
            // 文本输入框
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 120),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: WeChatColors.inputBorder),
                ),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  enabled: widget.enabled,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  style: const TextStyle(fontSize: 16),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    hintText: '发消息...',
                    hintStyle: TextStyle(color: WeChatColors.textHint),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            // 表情按钮（占位）
            IconButton(
              icon: const Icon(Icons.emoji_emotions_outlined,
                  color: WeChatColors.textSecondary),
              onPressed: widget.enabled ? () {} : null,
            ),
            // 发送/加号按钮
            if (_hasText)
              _SendButton(onSend: _send, enabled: widget.enabled)
            else
              IconButton(
                icon: const Icon(Icons.add_circle_outline,
                    color: WeChatColors.textSecondary),
                onPressed: widget.enabled ? () {} : null,
              ),
          ],
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final VoidCallback onSend;
  final bool enabled;

  const _SendButton({required this.onSend, required this.enabled});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onSend : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: enabled ? WeChatColors.primary : WeChatColors.textHint,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          '发送',
          style: TextStyle(
              color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}
