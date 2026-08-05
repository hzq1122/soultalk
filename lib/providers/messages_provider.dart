import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/message.dart';
import 'api_config_provider.dart';

const _kPageSize = 50;

// ─── 消息列表 Provider ────────────────────────────────────────────────────────

class MessagesNotifier extends FamilyAsyncNotifier<List<Message>, String> {
  /// 上一页最旧一条消息的游标（created_at + id），null 表示无更多。
  DateTime? _cursorCreatedAt;
  String? _cursorId;
  bool _hasMore = true;
  bool _loadingMore = false;

  @override
  Future<List<Message>> build(String contactId) async {
    _cursorCreatedAt = null;
    _cursorId = null;
    final msgs = await ref
        .read(chatServiceProvider)
        .getMessagePageByCursor(contactId, limit: _kPageSize);
    _updateCursor(msgs);
    // DESC（新→旧）转为 ASC（旧→新），最新在列表末尾
    return msgs.reversed.toList();
  }

  bool get hasMore => _hasMore;

  void _updateCursor(List<Message> descPage) {
    if (descPage.isEmpty) {
      _hasMore = false;
      return;
    }
    // DESC 分页结果最后一条 = 最旧一条，作为下一页 before 游标
    final oldest = descPage.last;
    _cursorCreatedAt = oldest.createdAt;
    _cursorId = oldest.id;
    _hasMore = descPage.length == _kPageSize;
  }

  Future<void> loadMore() async {
    if (!_hasMore || _loadingMore) return;
    _loadingMore = true;
    try {
      final older = await ref
          .read(chatServiceProvider)
          .getMessagePageByCursor(
            arg,
            limit: _kPageSize,
            beforeCreatedAt: _cursorCreatedAt,
            beforeId: _cursorId,
          );
      if (older.isEmpty) {
        _hasMore = false;
        return;
      }
      _updateCursor(older);
      final current = state.value ?? [];
      state = AsyncData([...older.reversed, ...current]);
    } finally {
      _loadingMore = false;
    }
  }

  void addMessage(Message message) {
    final current = state.value ?? [];
    state = AsyncData([...current, message]);
  }

  void updateLastMessage(
    String id,
    String content, {
    bool isStreaming = false,
  }) {
    final list = state.value ?? [];
    final idx = list.indexWhere((m) => m.id == id);
    if (idx >= 0) {
      final newList = List<Message>.from(list);
      newList[idx] = newList[idx].copyWith(
        content: content,
        isStreaming: isStreaming,
      );
      state = AsyncData(newList);
    }
  }

  /// 标记消息生成失败（消息保留，UI 显示失败样式与重试入口）。
  void markFailed(String id) {
    final list = state.value ?? [];
    final idx = list.indexWhere((m) => m.id == id);
    if (idx >= 0) {
      final newList = List<Message>.from(list);
      newList[idx] = newList[idx].copyWith(isStreaming: false, isFailed: true);
      state = AsyncData(newList);
    }
  }

  /// 更新本地消息内容（编辑用户消息）。
  void updateMessageContent(String id, String content) {
    final list = state.value ?? [];
    final idx = list.indexWhere((m) => m.id == id);
    if (idx >= 0) {
      final newList = List<Message>.from(list);
      newList[idx] = newList[idx].copyWith(
        content: content,
        isStreaming: false,
        isFailed: false,
      );
      state = AsyncData(newList);
    }
  }

  /// 删除某条消息之后的所有本地消息（编辑后重发前的清理）。
  void removeMessagesAfter(String id) {
    final list = state.value ?? [];
    final idx = list.indexWhere((m) => m.id == id);
    if (idx < 0) return;
    state = AsyncData(list.sublist(0, idx + 1));
  }

  void updateLastMessageMetadata(String id, Map<String, dynamic> metadata) {
    final list = state.value ?? [];
    final idx = list.indexWhere((m) => m.id == id);
    if (idx >= 0) {
      final newList = List<Message>.from(list);
      newList[idx] = newList[idx].copyWith(metadata: metadata);
      state = AsyncData(newList);
    }
  }

  Future<void> removeMessage(String messageId) async {
    final previous = state;
    state = await AsyncValue.guard(() async {
      final service = ref.read(chatServiceProvider);
      await service.deleteMessage(messageId);
      final list = previous.value ?? [];
      return list.where((m) => m.id != messageId).toList();
    });
  }

  Future<void> retractMessage(String messageId) async {
    final previous = state;
    state = await AsyncValue.guard(() async {
      final list = previous.value ?? [];
      final idx = list.indexWhere((m) => m.id == messageId);
      if (idx < 0) return list;
      final original = list[idx];
      await ref
          .read(chatServiceProvider)
          .retractMessage(messageId, '[用户撤回了一条消息：${original.content}]');
      final newList = List<Message>.from(list);
      newList[idx] = newList[idx].copyWith(
        type: MessageType.system,
        content: '你撤回了一条消息',
      );
      return newList;
    });
  }

  Future<void> clearMessages() async {
    final contactId = arg;
    _loadingMore = false;
    state = await AsyncValue.guard(() async {
      await ref.read(chatServiceProvider).deleteMessages(contactId);
      _cursorCreatedAt = null;
      _cursorId = null;
      _hasMore = false;
      return <Message>[];
    });
  }

  Future<void> refresh() async {
    _loadingMore = false;
    state = const AsyncLoading();
    _cursorCreatedAt = null;
    _cursorId = null;
    state = await AsyncValue.guard(() async {
      final msgs = await ref
          .read(chatServiceProvider)
          .getMessagePageByCursor(arg, limit: _kPageSize);
      _updateCursor(msgs);
      return msgs.reversed.toList();
    });
  }
}

final messagesProvider =
    AsyncNotifierProviderFamily<MessagesNotifier, List<Message>, String>(
      MessagesNotifier.new,
    );

// ─── 当前发送状态 ─────────────────────────────────────────────────────────────

final isSendingProvider = StateProvider.family<bool, String>(
  (ref, contactId) => false,
);
