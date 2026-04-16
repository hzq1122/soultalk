import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/message.dart';
import 'api_config_provider.dart';

// ─── 消息列表 Provider ────────────────────────────────────────────────────────

class MessagesNotifier extends FamilyAsyncNotifier<List<Message>, String> {
  @override
  Future<List<Message>> build(String contactId) async {
    return ref.read(chatServiceProvider).getMessages(contactId);
  }

  void addMessage(Message message) {
    final current = state.value ?? [];
    state = AsyncData([...current, message]);
  }

  void updateLastMessage(String id, String content, {bool isStreaming = false}) {
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

  Future<void> clearMessages() async {
    final contactId = arg;
    await ref.read(chatServiceProvider).deleteMessages(contactId);
    state = const AsyncData([]);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
        () => ref.read(chatServiceProvider).getMessages(arg));
  }
}

final messagesProvider =
    AsyncNotifierProviderFamily<MessagesNotifier, List<Message>, String>(
        MessagesNotifier.new);

// ─── 当前发送状态 ─────────────────────────────────────────────────────────────

final isSendingProvider = StateProvider.family<bool, String>((ref, contactId) => false);
