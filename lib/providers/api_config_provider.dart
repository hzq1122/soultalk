import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/api_config.dart';
import '../services/chat/chat_service.dart';

final chatServiceProvider = Provider<ChatService>((ref) => ChatService());

// ─── API 配置 Provider ────────────────────────────────────────────────────────

class ApiConfigNotifier extends AsyncNotifier<List<ApiConfig>> {
  @override
  Future<List<ApiConfig>> build() async {
    return ref.read(chatServiceProvider).getApiConfigs();
  }

  Future<void> add(ApiConfig config) async {
    final service = ref.read(chatServiceProvider);
    final created = await service.createApiConfig(config);
    state = AsyncData([...?state.value, created]);
  }

  Future<void> updateConfig(ApiConfig config) async {
    final service = ref.read(chatServiceProvider);
    await service.updateApiConfig(config);
    state = AsyncData(
      state.value?.map((c) => c.id == config.id ? config : c).toList() ?? [],
    );
  }

  Future<void> remove(String id) async {
    final service = ref.read(chatServiceProvider);
    await service.deleteApiConfig(id);
    state = AsyncData(state.value?.where((c) => c.id != id).toList() ?? []);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(chatServiceProvider).getApiConfigs(),
    );
  }
}

final apiConfigProvider =
    AsyncNotifierProvider<ApiConfigNotifier, List<ApiConfig>>(
      ApiConfigNotifier.new,
    );
