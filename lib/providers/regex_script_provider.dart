import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/regex_script.dart';
import '../services/database/database_service.dart';
import '../services/database/regex_script_dao.dart';

final regexScriptDaoProvider = Provider<RegexScriptDao>((ref) {
  return RegexScriptDao(DatabaseService());
});

class RegexScriptNotifier extends AsyncNotifier<List<RegexScript>> {
  @override
  Future<List<RegexScript>> build() async {
    return ref.read(regexScriptDaoProvider).getAll();
  }

  Future<void> importScripts(List<RegexScript> scripts) async {
    await ref.read(regexScriptDaoProvider).insertAll(scripts);
    state = AsyncData(await ref.read(regexScriptDaoProvider).getAll());
  }

  Future<void> toggle(String id) async {
    await ref.read(regexScriptDaoProvider).toggleDisabled(id);
    state = AsyncData(await ref.read(regexScriptDaoProvider).getAll());
  }

  Future<void> remove(String id) async {
    await ref.read(regexScriptDaoProvider).delete(id);
    state = AsyncData(state.value?.where((s) => s.id != id).toList() ?? []);
  }

  Future<void> removeAll() async {
    await ref.read(regexScriptDaoProvider).deleteAll();
    state = const AsyncData([]);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(regexScriptDaoProvider).getAll(),
    );
  }
}

final regexScriptProvider =
    AsyncNotifierProvider<RegexScriptNotifier, List<RegexScript>>(
      RegexScriptNotifier.new,
    );

final enabledRegexScriptsProvider = Provider<List<RegexScript>>((ref) {
  final scripts = ref.watch(regexScriptProvider).value ?? [];
  return scripts.where((s) => !s.disabled).toList();
});
