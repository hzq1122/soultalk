import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:just_audio/just_audio.dart';
import '../../models/contact.dart';
import '../../models/message.dart';
import '../../models/api_config.dart';
import '../../providers/contacts_provider.dart';
import '../../providers/messages_provider.dart';
import '../../providers/api_config_provider.dart';
import '../../theme/wechat_colors.dart';
import '../../models/voice_config.dart';
import '../../widgets/avatar_widget.dart';
import '../../models/extension_event.dart';
import '../../services/chat/typing_simulator.dart';
import '../../services/extensions/extension_event_bus.dart';
import '../../services/tts/tts_service.dart';
import '../../services/stt/stt_service.dart';
import '../../services/file_send/attachment_service.dart';
import '../../services/database/attachment_index_dao.dart';
import 'widgets/message_bubble.dart';
import 'widgets/input_bar.dart';
import 'widgets/typing_indicator.dart';

class ChatPage extends ConsumerStatefulWidget {
  final String contactId;
  final Contact? contact;

  const ChatPage({super.key, required this.contactId, this.contact});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _scrollController = ScrollController();
  final _audioRecorder = AudioRecorder();
  AudioPlayer? _currentTtsPlayer;
  String? _currentTtsFilePath;
  String? _recordingPath;
  StreamSubscription<ExtensionEvent>? _eventSubscription;
  bool _isSending = false;
  bool _isTyping = false;
  bool _isRecording = false;
  bool _isTranscribing = false;
  bool _hasReceivedFirstChunk = false;
  bool _ttsEnabled = false;
  String? _lastUserText;
  String? _lastUserMessageId;

  /// 最近一次发送是否失败（用于跳过 TTS 等成功动作）。
  bool _lastSendFailed = false;

  /// 进行中请求的取消令牌：停止生成按钮 / dispose 时取消。
  CancelToken? _activeCancelToken;

  /// 单调递增的请求序号：旧请求（已停止/已取消）的迟到回调
  /// 携带的 generationId 与当前活跃请求不一致时直接丢弃，
  /// 防止“停止 → 立即发送新消息”时旧回复串写进新消息。
  int _generationCounter = 0;

  void _stopGeneration() {
    // 递增请求序号：所有旧请求（含仍在 simulateDelay 窗口内的）
    // 的回调与延迟路径立即失效，防止停止后旧请求重新夺权
    _generationCounter++;
    _activeCancelToken?.cancel();
    _activeCancelToken = null;
    setState(() {
      _isSending = false;
      _isTyping = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.atEdge &&
          _scrollController.position.pixels <= 0) {
        _loadMore();
      }
    });
    // 主动消息/后台生成写入后刷新本页：已打开的聊天页也能看到新消息。
    // 本页正在流式生成时不刷新（refresh 清空列表会与 chunk 更新竞争）。
    _eventSubscription = ExtensionEventBus.instance.events.listen((event) {
      if (event.type != 'proactive_message_sent' &&
          event.type != 'message_received') {
        return;
      }
      if (event.contactId != widget.contactId) return;
      if (_isSending) return;
      final notifier = ref.read(messagesProvider(widget.contactId).notifier);
      unawaited(notifier.refresh());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
      ref.read(contactsProvider.notifier).clearUnread(widget.contactId);
    });
    _loadTtsSetting();
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    // 页面销毁时取消进行中的生成请求：回调已由 mounted 保护，
    // 取消后 ChatService 保留已生成内容并标记完成，不写已销毁的 State。
    _activeCancelToken?.cancel();
    _stopRecording(deleteFile: true);
    _audioRecorder.dispose();
    _disposeTtsPlayer(deleteFile: true);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool animated = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final target = _scrollController.position.maxScrollExtent;
        if (animated) {
          _scrollController.animateTo(
            target,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        } else {
          _scrollController.jumpTo(target);
        }
      }
    });
  }

  Future<void> _sendMessage(
    Contact contact,
    String text, {
    String? existingUserMessageId,
  }) async {
    if (_isSending) return;
    _lastUserText = text;
    _lastSendFailed = false;
    setState(() {
      _isSending = true;
      _isTyping = true;
      _hasReceivedFirstChunk = false;
    });

    final messagesNotifier = ref.read(
      messagesProvider(widget.contactId).notifier,
    );

    // 请求身份在延迟前分配：停止按钮可在 simulateDelay 窗口内
    // 递增 _generationCounter，使本请求在延迟结束后直接失效，
    // 不会重新夺权 _activeCancelToken 造成双请求并发。
    final token = CancelToken();
    _activeCancelToken = token;
    final generationId = ++_generationCounter;

    await TypingSimulator.simulateDelay(text);
    if (!mounted ||
        !identical(token, _activeCancelToken) ||
        generationId != _generationCounter) {
      return;
    }

    // 保持 _isTyping = true，在 API 返回第一个 chunk 时再隐藏

    // 本次请求的上下文：onMessagesCreated 中赋值，chunk/error 回调
    // 捕获自己的 id，不再读取全局 _lastAiMsgId（旧请求回调不会串写）。
    String? requestUserMsgId;
    String? requestAiMsgId;

    try {
      await ref
          .read(chatServiceProvider)
          .sendMessage(
            contact: contact,
            userText: text,
            existingUserMessageId: existingUserMessageId,
            cancelToken: token,
            onMessagesCreated: (userMsg, aiMsg) {
              // 旧请求（停止后仍可能到达）不得插入消息
              if (!identical(token, _activeCancelToken) ||
                  generationId != _generationCounter) {
                return;
              }
              requestUserMsgId = userMsg.id;
              requestAiMsgId = aiMsg.id;
              // 重试入口仍读取全局字段（仅最新一次发送），
              // 与回调数据隔离，避免竞态。
              _lastUserMessageId = userMsg.id;
              messagesNotifier.addMessage(userMsg);
              messagesNotifier.addMessage(aiMsg);
              _scrollToBottom(animated: true);
            },
            onAiChunk: (content, isDone) {
              // 旧请求（已停止/已取消）的迟到回调一律忽略：
              // 既不更新新消息，也不重置发送状态。
              if (!identical(token, _activeCancelToken) ||
                  generationId != _generationCounter) {
                return;
              }
              if (!_hasReceivedFirstChunk && mounted) {
                setState(() => _hasReceivedFirstChunk = true);
                _delayedHideTyping(token: token, generationId: generationId);
              }

              final aiMsgId = requestAiMsgId;
              if (aiMsgId != null) {
                messagesNotifier.updateLastMessage(
                  aiMsgId,
                  content,
                  isStreaming: !isDone,
                );
                _scrollToBottom(animated: false);
              }
              if (isDone) {
                if (mounted) setState(() => _isSending = false);
                ref.read(contactsProvider.notifier).refresh();
                if (_ttsEnabled && !_lastSendFailed) {
                  _speakAiResponse(content);
                }
              }
            },
            onError: (error) {
              if (!identical(token, _activeCancelToken) ||
                  generationId != _generationCounter) {
                return;
              }
              _lastSendFailed = true;
              if (mounted) {
                // 失败消息保留并标记 failed（UI 显示失败样式与重试入口）
                final aiMsgId = requestAiMsgId;
                if (aiMsgId != null) {
                  messagesNotifier.markFailed(aiMsgId);
                }
                setState(() {
                  _isSending = false;
                  _isTyping = false;
                  _hasReceivedFirstChunk = true;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('发送失败: $error'),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 4),
                    behavior: SnackBarBehavior.floating,
                    action: SnackBarAction(
                      label: '重试',
                      textColor: Colors.white,
                      onPressed: () {
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        // 移除失败的 assistant 消息后重试：
                        // 复用原用户消息 ID，避免重复插入用户消息。
                        if (aiMsgId != null) {
                          messagesNotifier.removeMessage(aiMsgId);
                        }
                        if (_lastUserText != null) {
                          _sendMessage(
                            contact,
                            _lastUserText!,
                            existingUserMessageId: requestUserMsgId,
                          );
                        }
                      },
                    ),
                  ),
                );
              }
            },
          );
    } finally {
      if (identical(_activeCancelToken, token)) {
        _activeCancelToken = null;
        // 仅当仍是本请求持有发送状态时才复位：
        // 避免被停止的旧请求把新请求的 _isSending 提前置 false
        if (mounted && generationId == _generationCounter) {
          setState(() => _isSending = false);
        }
      }
    }
  }

  void _delayedHideTyping({CancelToken? token, int? generationId}) {
    Future.delayed(const Duration(seconds: 3), () {
      // 旧请求（已停止/已取消）启动的定时器不得隐藏新请求的输入状态。
      // 仅在“存在新的活跃请求且身份不匹配”时拦截；
      // 请求正常完成（_activeCancelToken 已置 null）时允许隐藏。
      if (!mounted) return;
      if (token != null &&
          _activeCancelToken != null &&
          (!identical(token, _activeCancelToken) ||
              generationId != _generationCounter)) {
        return;
      }
      setState(() => _isTyping = false);
    });
  }

  Future<void> _loadTtsSetting() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _ttsEnabled = prefs.getBool('tts_enabled_${widget.contactId}') ?? false;
      });
    }
  }

  Future<void> _toggleTts(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tts_enabled_${widget.contactId}', value);
    setState(() => _ttsEnabled = value);
  }

  Future<void> _speakAiResponse(String text) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ttsConfig = await TtsConfig.load(prefs);
      if (ttsConfig.apiKey.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('TTS 未配置 API Key，请在通用设置中设置'),
              duration: Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      final cleanText = TtsService.stripMemoryMarkers(text);
      if (cleanText.isEmpty) return;

      await _disposeTtsPlayer(deleteFile: true);
      final service = TtsService();
      final filePath = await service.synthesize(ttsConfig, cleanText);
      if (filePath == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('TTS 合成失败，请检查 API 配置和网络'),
              duration: Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
      if (!mounted) {
        _deleteFile(filePath);
        return;
      }

      final player = AudioPlayer();
      _currentTtsPlayer = player;
      _currentTtsFilePath = filePath;
      await player.setFilePath(filePath);
      await player.play();
      player.processingStateStream
          .where((s) => s == ProcessingState.completed)
          .first
          .then((_) => _disposeTtsPlayer(deleteFile: true));
    } catch (e) {
      await _disposeTtsPlayer(deleteFile: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('TTS 播放失败: $e'),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _disposeTtsPlayer({required bool deleteFile}) async {
    final player = _currentTtsPlayer;
    final filePath = _currentTtsFilePath;
    _currentTtsPlayer = null;
    _currentTtsFilePath = null;
    await player?.dispose();
    if (deleteFile && filePath != null) {
      _deleteFile(filePath);
    }
  }

  void _deleteFile(String path) {
    try {
      final file = File(path);
      if (file.existsSync()) file.deleteSync();
    } catch (_) {}
  }

  Future<void> _loadMore() async {
    final notifier = ref.read(messagesProvider(widget.contactId).notifier);
    await notifier.loadMore();
  }

  Future<void> _onMicTap() async {
    if (_isTranscribing) return;
    if (_isRecording) {
      await _finishRecording();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final sttConfig = await SttConfig.load(prefs);
    if (sttConfig.apiKey.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('请先在通用设置中配置语音识别（STT）API'),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: '去设置',
              onPressed: () => context.push('/settings/general'),
            ),
          ),
        );
      }
      return;
    }

    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status.isPermanentlyDenied
                ? '麦克风权限已被永久拒绝，请在系统设置中开启'
                : '需要麦克风权限才能录音',
          ),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          action: status.isPermanentlyDenied
              ? SnackBarAction(label: '去设置', onPressed: openAppSettings)
              : null,
        ),
      );
      return;
    }

    try {
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/stt_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );
      if (!mounted) {
        await _stopRecording(deleteFile: true);
        return;
      }
      setState(() {
        _isRecording = true;
        _recordingPath = path;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('开始录音，再次点击麦克风停止'),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: '取消',
            onPressed: () => _cancelRecording(showMessage: true),
          ),
        ),
      );
    } catch (e) {
      await _stopRecording(deleteFile: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('录音启动失败: $e'),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _finishRecording() async {
    final prefs = await SharedPreferences.getInstance();
    final sttConfig = await SttConfig.load(prefs);
    final path = await _stopRecording(deleteFile: false);
    if (path == null) return;
    if (!mounted) {
      _deleteFile(path);
      return;
    }

    setState(() => _isTranscribing = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('录音已停止，正在识别...'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );

    try {
      final text = await SttService().transcribe(sttConfig, path);
      if (!mounted) return;
      final contact = ref
          .read(contactsProvider)
          .value
          ?.where((c) => c.id == widget.contactId)
          .firstOrNull;
      if (contact == null) {
        throw StateError('联系人不存在');
      }
      await _sendMessage(contact, text);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('语音识别失败: $e'),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      _deleteFile(path);
      if (mounted) setState(() => _isTranscribing = false);
    }
  }

  Future<String?> _stopRecording({required bool deleteFile}) async {
    String? path;
    try {
      path = await _audioRecorder.stop();
    } catch (_) {
      path = _recordingPath;
    }
    path ??= _recordingPath;
    _recordingPath = null;
    if (mounted) setState(() => _isRecording = false);
    if (deleteFile && path != null) {
      _deleteFile(path);
    }
    return path;
  }

  Future<void> _cancelRecording({required bool showMessage}) async {
    await _stopRecording(deleteFile: true);
    if (mounted && showMessage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已取消录音'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showMessageActions(BuildContext context, Message message) {
    final isUser = message.role == MessageRole.user;
    final isAiError =
        message.role == MessageRole.assistant &&
        !message.isStreaming &&
        (message.isFailed || message.content.isEmpty);

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isAiError)
              ListTile(
                leading: const Icon(Icons.refresh, color: WeChatColors.primary),
                title: const Text('重新生成'),
                subtitle: const Text(
                  '使用当前配置重新发送上一条消息',
                  style: TextStyle(
                    fontSize: 12,
                    color: WeChatColors.textSecondary,
                  ),
                ),
                onTap: () {
                  ctx.pop();
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ref
                      .read(messagesProvider(widget.contactId).notifier)
                      .removeMessage(message.id);
                  final contact = ref
                      .read(contactsProvider)
                      .value
                      ?.where((c) => c.id == widget.contactId)
                      .firstOrNull;
                  if (contact != null && _lastUserText != null) {
                    // 重新生成复用原用户消息 ID，避免重复插入用户消息
                    _sendMessage(
                      contact,
                      _lastUserText!,
                      existingUserMessageId: _lastUserMessageId,
                    );
                  }
                },
              ),
            if (isUser)
              ListTile(
                leading: const Icon(
                  Icons.edit_outlined,
                  color: WeChatColors.primary,
                ),
                title: const Text('编辑消息'),
                subtitle: const Text(
                  '修改内容后重新生成 AI 回复',
                  style: TextStyle(
                    fontSize: 12,
                    color: WeChatColors.textSecondary,
                  ),
                ),
                onTap: () {
                  ctx.pop();
                  _editMessage(message);
                },
              ),
            if (isUser)
              ListTile(
                leading: const Icon(Icons.undo, color: WeChatColors.primary),
                title: const Text('撤回消息'),
                subtitle: const Text(
                  'AI 会知道此消息被撤回',
                  style: TextStyle(
                    fontSize: 12,
                    color: WeChatColors.textSecondary,
                  ),
                ),
                onTap: () {
                  ctx.pop();
                  ref
                      .read(messagesProvider(widget.contactId).notifier)
                      .retractMessage(message.id);
                },
              ),
            if (!isUser && !message.isStreaming && message.content.isNotEmpty)
              ListTile(
                leading: const Icon(
                  Icons.play_arrow,
                  color: WeChatColors.primary,
                ),
                title: const Text('继续生成'),
                subtitle: const Text(
                  '从这条消息的末尾继续续写',
                  style: TextStyle(
                    fontSize: 12,
                    color: WeChatColors.textSecondary,
                  ),
                ),
                onTap: () {
                  ctx.pop();
                  final contact = ref
                      .read(contactsProvider)
                      .value
                      ?.where((c) => c.id == widget.contactId)
                      .firstOrNull;
                  if (contact != null) {
                    _continueFromMessage(contact, message);
                  }
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('删除消息'),
              subtitle: const Text(
                'AI 不会知道此消息被删除',
                style: TextStyle(
                  fontSize: 12,
                  color: WeChatColors.textSecondary,
                ),
              ),
              onTap: () {
                ctx.pop();
                ref
                    .read(messagesProvider(widget.contactId).notifier)
                    .removeMessage(message.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPromptPreview(Contact contact) async {
    final service = ref.read(chatServiceProvider);
    String systemPrompt;
    List<Message> requestMessages;
    try {
      final preview = await service.previewPrompt(contact);
      systemPrompt = preview.systemPrompt;
      requestMessages = preview.requestMessages;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('预览失败: $e')));
      }
      return;
    }
    if (!mounted) return;

    final sections = <String>[
      '═══ System Prompt（系统提示，注入位置：消息列表之前）═══\n${systemPrompt.isEmpty ? '（空）' : systemPrompt}',
      ...requestMessages.map(
        (m) =>
            '─── ${m.role.name.toUpperCase()} ───\n${m.content.isEmpty ? '（空）' : m.content}',
      ),
    ];

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Prompt 预览'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              sections.join('\n\n'),
              style: const TextStyle(
                fontSize: 13,
                fontFamily: 'monospace',
                height: 1.4,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Future<void> _editMessage(Message message) async {
    final controller = TextEditingController(text: message.content);
    final newText = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑消息'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          minLines: 2,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: '修改消息内容',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (newText == null || newText.isEmpty || newText == message.content) {
      return;
    }

    final notifier = ref.read(messagesProvider(widget.contactId).notifier);
    final service = ref.read(chatServiceProvider);
    // 删除该消息之后的所有旧消息（旧 AI 回复等），保持语义一致
    await service.deleteMessagesAfter(widget.contactId, message.id);
    notifier.removeMessagesAfter(message.id);
    // 更新消息文本并重新生成（复用原用户消息 ID，不重复插入）
    await service.updateMessageContent(message.id, newText);
    notifier.updateMessageContent(message.id, newText);

    final contact = ref
        .read(contactsProvider)
        .value
        ?.where((c) => c.id == widget.contactId)
        .firstOrNull;
    if (contact != null) {
      _lastUserText = newText;
      _lastUserMessageId = message.id;
      _sendMessage(contact, newText, existingUserMessageId: message.id);
    }
  }

  Future<void> _continueFromMessage(Contact contact, Message message) async {
    if (_isSending) return;
    _lastSendFailed = false;
    setState(() {
      _isSending = true;
      _isTyping = true;
      _hasReceivedFirstChunk = false;
    });

    final messagesNotifier = ref.read(
      messagesProvider(widget.contactId).notifier,
    );
    final token = CancelToken();
    _activeCancelToken = token;
    final generationId = ++_generationCounter;

    try {
      await ref
          .read(chatServiceProvider)
          .continueFromAiMessage(
            contact: contact,
            aiMessageId: message.id,
            cancelToken: token,
            onAiChunk: (content, isDone) {
              // 旧请求（已停止）的迟到回调不更新状态
              if (!identical(token, _activeCancelToken) ||
                  generationId != _generationCounter) {
                return;
              }
              if (!_hasReceivedFirstChunk && mounted) {
                setState(() => _hasReceivedFirstChunk = true);
                _delayedHideTyping(token: token, generationId: generationId);
              }
              messagesNotifier.updateLastMessage(
                message.id,
                content,
                isStreaming: !isDone,
              );
              _scrollToBottom(animated: false);
              if (isDone) {
                if (mounted) setState(() => _isSending = false);
                ref.read(contactsProvider.notifier).refresh();
              }
            },
            onError: (error) {
              // 旧请求（已停止）的迟到错误回调不标记消息、不复位状态
              if (!identical(token, _activeCancelToken) ||
                  generationId != _generationCounter) {
                return;
              }
              _lastSendFailed = true;
              if (mounted) {
                messagesNotifier.markFailed(message.id);
                setState(() {
                  _isSending = false;
                  _isTyping = false;
                  _hasReceivedFirstChunk = true;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('继续生成失败: $error'),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 4),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          );
    } finally {
      if (identical(_activeCancelToken, token)) {
        _activeCancelToken = null;
        // 仅当仍是本请求持有发送状态时才复位：
        // 避免被停止的旧请求把新请求的 _isSending 提前置 false
        if (mounted && generationId == _generationCounter) {
          setState(() => _isSending = false);
        }
      }
    }
  }

  Future<void> _sendImageMessage(String imagePath) {
    return _sendAttachmentMessage(
      sourcePath: imagePath,
      type: MessageType.image,
      failureMessage: '图片发送失败',
    );
  }

  Future<void> _sendFileMessage(String filePath) {
    return _sendAttachmentMessage(
      sourcePath: filePath,
      type: MessageType.file,
      failureMessage: '文件发送失败',
    );
  }

  Future<void> _sendAttachmentMessage({
    required String sourcePath,
    required MessageType type,
    required String failureMessage,
  }) async {
    final messagesNotifier = ref.read(
      messagesProvider(widget.contactId).notifier,
    );
    AttachmentIndexRecord? record;

    try {
      final attachmentService = await AttachmentService.create();
      record = await attachmentService.importFile(
        chatId: widget.contactId,
        source: File(sourcePath),
        mimeType: AttachmentService.inferMimeType(sourcePath),
      );
      final userMsg = Message(
        id: '',
        contactId: widget.contactId,
        role: MessageRole.user,
        content: type == MessageType.image
            ? record.relativePath
            : record.originalName,
        type: type,
        metadata: {
          'attachment': attachmentService.toChatExtra(record),
          'relative_path': record.relativePath,
        },
        createdAt: DateTime.now(),
      );
      final service = ref.read(chatServiceProvider);
      final saved = await service.saveMessage(userMsg);
      try {
        await attachmentService.attachToMessage(
          attachmentId: record.id,
          messageId: saved.id,
        );
      } catch (_) {
        // 关联失败：消息已保存但附件未关联，回滚消息避免不一致
        await service.deleteMessage(saved.id);
        rethrow;
      }
      messagesNotifier.addMessage(saved);
      _scrollToBottom(animated: true);
      ref.read(contactsProvider.notifier).refresh();
    } catch (e) {
      // 补偿清理：saveMessage/attachToMessage 失败时删除已导入的
      // 附件文件与 attachment_index 记录，避免孤儿文件。
      if (record != null) {
        try {
          final attachmentService = await AttachmentService.create();
          await attachmentService.deleteAttachment(record.id);
        } catch (_) {}
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$failureMessage: $e'),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _sendSpecialMessage(
    Contact contact,
    String type,
    Map<String, dynamic> metadata,
  ) async {
    final messagesNotifier = ref.read(
      messagesProvider(widget.contactId).notifier,
    );
    final msgType = type == 'transfer'
        ? MessageType.transfer
        : MessageType.delivery;
    String content;
    if (type == 'transfer') {
      content = '¥${metadata['amount']}';
    } else {
      content = '${metadata['shop']} - ${metadata['items']}';
    }

    final userMsg = Message(
      id: '',
      contactId: widget.contactId,
      role: MessageRole.user,
      content: content,
      type: msgType,
      metadata: metadata,
      createdAt: DateTime.now(),
    );

    final service = ref.read(chatServiceProvider);
    final saved = await service.saveMessage(userMsg);
    messagesNotifier.addMessage(saved);
    _scrollToBottom(animated: true);
    ref.read(contactsProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final contactAsync = ref
        .watch(contactsProvider)
        .whenData(
          (contacts) =>
              contacts.where((c) => c.id == widget.contactId).firstOrNull,
        );
    final contact = contactAsync.value ?? widget.contact;

    if (contact == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('聊天')),
        body: const Center(child: Text('联系人不存在')),
      );
    }

    final messagesAsync = ref.watch(messagesProvider(widget.contactId));

    return Scaffold(
      backgroundColor: WeChatColors.background,
      appBar: AppBar(
        backgroundColor: WeChatColors.appBarBackground,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AvatarWidget.fromContact(contact, size: 32),
                const SizedBox(width: 8),
                Text(contact.name),
              ],
            ),
            if (_isTyping)
              const Text(
                '对方正在输入...',
                style: TextStyle(
                  fontSize: 11,
                  color: WeChatColors.textSecondary,
                ),
              ),
          ],
        ),
        actions: [
          if (_isSending)
            IconButton(
              tooltip: '停止生成',
              icon: const Icon(Icons.stop_circle_outlined),
              onPressed: _stopGeneration,
            ),
          IconButton(
            icon: const Icon(Icons.more_horiz),
            onPressed: () => _showChatMenu(context, contact),
          ),
        ],
      ),
      body: Column(
        children: [
          // 消息列表
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('加载失败: $e')),
              data: (messages) {
                if (messages.isEmpty && !_isTyping) {
                  return _buildEmptyChat(contact);
                }
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: messages.length + (_isTyping ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index < messages.length) {
                      final msg = messages[index];
                      return GestureDetector(
                        onLongPress: () => _showMessageActions(context, msg),
                        child: MessageBubble(message: msg, contact: contact),
                      );
                    }
                    return const TypingIndicator();
                  },
                );
              },
            ),
          ),
          // 输入栏
          InputBar(
            onSend: (text) => _sendMessage(contact, text),
            onSendSpecial: (type, metadata) =>
                _sendSpecialMessage(contact, type, metadata),
            onSendImage: _sendImageMessage,
            onSendFile: _sendFileMessage,
            onMicTap: _onMicTap,
            enabled: !_isSending && !_isTranscribing,
            isRecording: _isRecording,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChat(Contact contact) {
    final hasFirstMes = contact.characterCardJson != null;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AvatarWidget.fromContact(contact, size: 64),
          const SizedBox(height: 12),
          Text(
            contact.name,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          if (contact.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                contact.description,
                style: const TextStyle(
                  fontSize: 13,
                  color: WeChatColors.textSecondary,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          const SizedBox(height: 24),
          Text(
            hasFirstMes ? '开始对话' : '发送一条消息开始聊天',
            style: const TextStyle(color: WeChatColors.textHint, fontSize: 13),
          ),
        ],
      ),
    );
  }

  void _showChatMenu(BuildContext context, Contact contact) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.article_outlined),
              title: const Text('Prompt 预览'),
              subtitle: const Text(
                '查看发送给模型的最终 system prompt 与消息列表',
                style: TextStyle(
                  fontSize: 12,
                  color: WeChatColors.textSecondary,
                ),
              ),
              onTap: () {
                ctx.pop();
                _showPromptPreview(contact);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('联系人资料'),
              onTap: () {
                ctx.pop();
                context.push('/contact/detail/${contact.id}', extra: contact);
              },
            ),
            SwitchListTile(
              secondary: const Icon(Icons.push_pin_outlined),
              title: const Text('置顶会话'),
              value: contact.pinned,
              activeThumbColor: WeChatColors.primary,
              onChanged: (v) {
                ctx.pop();
                ref
                    .read(contactsProvider.notifier)
                    .updateContact(contact.copyWith(pinned: v));
              },
            ),
            SwitchListTile(
              secondary: const Icon(Icons.auto_mode),
              title: const Text('允许主动联系'),
              value: contact.proactiveEnabled,
              activeThumbColor: WeChatColors.primary,
              onChanged: (v) {
                ctx.pop();
                ref
                    .read(contactsProvider.notifier)
                    .updateContact(contact.copyWith(proactiveEnabled: v));
              },
            ),
            SwitchListTile(
              secondary: const Icon(Icons.volume_up_outlined),
              title: const Text('语音回复'),
              subtitle: const Text('使用 TTS 朗读 AI 回复'),
              value: _ttsEnabled,
              activeThumbColor: WeChatColors.primary,
              onChanged: (v) {
                ctx.pop();
                _toggleTts(v);
              },
            ),
            ListTile(
              leading: const Icon(Icons.psychology_outlined),
              title: const Text('记忆表格'),
              onTap: () {
                ctx.pop();
                context.push('/memory/${contact.id}', extra: contact);
              },
            ),
            ListTile(
              leading: const Icon(Icons.api_outlined),
              title: const Text('API 配置'),
              onTap: () {
                ctx.pop();
                context.push('/settings/api');
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('编辑联系人'),
              onTap: () {
                ctx.pop();
                _editContact(context, contact);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_sweep_outlined),
              title: const Text('清空聊天记录'),
              onTap: () async {
                ctx.pop();
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (d) => AlertDialog(
                    title: const Text('清空记录'),
                    content: const Text('确定清空所有聊天记录？'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(d).pop(false),
                        child: const Text('取消'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(d).pop(true),
                        child: const Text(
                          '清空',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await ref
                      .read(messagesProvider(widget.contactId).notifier)
                      .clearMessages();
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('删除联系人', style: TextStyle(color: Colors.red)),
              onTap: () {
                ctx.pop();
                _deleteContact(context, contact);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editContact(BuildContext context, Contact contact) async {
    final configs = ref.read(apiConfigProvider).value ?? [];
    final result = await showDialog<Contact>(
      context: context,
      builder: (ctx) =>
          _ChatEditContactDialog(contact: contact, configs: configs),
    );
    if (result != null) {
      await ref.read(contactsProvider.notifier).updateContact(result);
    }
  }

  Future<void> _deleteContact(BuildContext context, Contact contact) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除联系人'),
        content: Text('确定删除 "${contact.name}"？相关聊天记录将一并删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(contactsProvider.notifier).remove(contact.id);
      if (mounted) GoRouter.of(this.context).pop();
    }
  }
}

class _ChatEditContactDialog extends StatefulWidget {
  final Contact contact;
  final List<ApiConfig> configs;
  const _ChatEditContactDialog({required this.contact, required this.configs});

  @override
  State<_ChatEditContactDialog> createState() => _ChatEditContactDialogState();
}

class _ChatEditContactDialogState extends State<_ChatEditContactDialog> {
  late final _nameCtrl = TextEditingController(text: widget.contact.name);
  late final _descCtrl = TextEditingController(
    text: widget.contact.description,
  );
  late final _promptCtrl = TextEditingController(
    text: widget.contact.systemPrompt,
  );
  late String? _selectedConfigId = widget.contact.apiConfigId;

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
              decoration: const InputDecoration(labelText: '名称'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              decoration: const InputDecoration(labelText: '简介'),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _promptCtrl,
              decoration: const InputDecoration(labelText: 'System Prompt'),
              maxLines: 4,
            ),
            if (widget.configs.isNotEmpty) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _selectedConfigId,
                decoration: const InputDecoration(labelText: '绑定 API'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('不绑定')),
                  ...widget.configs.map(
                    (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                  ),
                ],
                onChanged: (v) => setState(() => _selectedConfigId = v),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
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
