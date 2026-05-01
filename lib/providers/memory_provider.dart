import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/memory_card.dart';
import '../models/memory_entry.dart';
import '../models/memory_state.dart';
import '../models/api_config.dart';
import '../services/database/database_service.dart';
import '../services/database/memory_card_dao.dart';
import '../services/database/memory_entry_dao.dart';
import '../services/database/memory_state_dao.dart';
import '../services/memory/memory_service.dart';

final memoryEntryDaoProvider = Provider<MemoryEntryDao>((ref) {
  return MemoryEntryDao(DatabaseService());
});

final memoryStateDaoProvider = Provider<MemoryStateDao>((ref) {
  return MemoryStateDao(DatabaseService());
});

final memoryCardDaoProvider = Provider<MemoryCardDao>((ref) {
  return MemoryCardDao(DatabaseService());
});

final memoryServiceProvider = Provider<MemoryService>((ref) {
  return MemoryService(
    ref.read(memoryEntryDaoProvider),
    ref.read(memoryStateDaoProvider),
    ref.read(memoryCardDaoProvider),
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

// ── State board provider ───────────────────────────────────────────

class MemoryStateNotifier
    extends FamilyAsyncNotifier<List<MemoryState>, String> {
  @override
  Future<List<MemoryState>> build(String contactId) async {
    return ref.read(memoryStateDaoProvider).getByContact(contactId);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
        () => ref.read(memoryStateDaoProvider).getByContact(arg));
  }
}

final memoryStateProvider =
    AsyncNotifierProviderFamily<MemoryStateNotifier, List<MemoryState>, String>(
        MemoryStateNotifier.new);

// ── Memory card provider ───────────────────────────────────────────

class MemoryCardNotifier
    extends FamilyAsyncNotifier<List<MemoryCard>, String> {
  @override
  Future<List<MemoryCard>> build(String contactId) async {
    return ref.read(memoryCardDaoProvider).getActiveByContact(contactId);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
        () => ref.read(memoryCardDaoProvider).getActiveByContact(arg));
  }
}

final memoryCardProvider =
    AsyncNotifierProviderFamily<MemoryCardNotifier, List<MemoryCard>, String>(
        MemoryCardNotifier.new);
