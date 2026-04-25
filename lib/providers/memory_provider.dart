import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/memory_entry.dart';
import '../models/api_config.dart';
import '../services/database/database_service.dart';
import '../services/database/memory_entry_dao.dart';
import '../services/database/message_dao.dart';
import '../services/memory/memory_service.dart';

final memoryEntryDaoProvider = Provider<MemoryEntryDao>((ref) {
  return MemoryEntryDao(DatabaseService());
});

final memoryServiceProvider = Provider<MemoryService>((ref) {
  return MemoryService(
    ref.read(memoryEntryDaoProvider),
    MessageDao(DatabaseService()),
  );
});

class MemoryNotifier
    extends FamilyAsyncNotifier<List<MemoryEntry>, String> {
  @override
  Future<List<MemoryEntry>> build(String contactId) async {
    return ref.read(memoryEntryDaoProvider).getByContact(contactId);
  }

  Future<void> extractMemories(ApiConfig apiConfig) async {
    final service = ref.read(memoryServiceProvider);
    await service.extractMemories(
      contactId: arg,
      apiConfig: apiConfig,
    );
    state = AsyncData(
        await ref.read(memoryEntryDaoProvider).getByContact(arg));
  }

  Future<void> deleteEntry(String entryId) async {
    await ref.read(memoryEntryDaoProvider).delete(entryId);
    state = AsyncData(
      state.value?.where((e) => e.id != entryId).toList() ?? [],
    );
  }

  Future<void> clearAll() async {
    await ref.read(memoryEntryDaoProvider).deleteByContact(arg);
    state = const AsyncData([]);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
        () => ref.read(memoryEntryDaoProvider).getByContact(arg));
  }
}

final memoryProvider =
    AsyncNotifierProviderFamily<MemoryNotifier, List<MemoryEntry>, String>(
        MemoryNotifier.new);
