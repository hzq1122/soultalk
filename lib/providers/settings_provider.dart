import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kGlobalPromptEnabled = 'global_prompt_enabled';
const _kGlobalPromptText = 'global_prompt_text';
const _kMomentsIntervalMinutes = 'moments_interval_minutes';
const _kWalletBalance = 'wallet_balance';
const _kMemoryEnabled = 'memory_enabled';
const _kMemoryInterval = 'memory_interval';
const _kMemoryUseMainApi = 'memory_use_main_api';
const _kCheckUpdateOnStartup = 'check_update_on_startup';

const _defaultGlobalPrompt =
    '你现在是在聊天，并非在现实，请让你的回复更符合聊天时的状态';

class AppSettings {
  final bool globalPromptEnabled;
  final String globalPromptText;
  final int momentsIntervalMinutes;
  final double walletBalance;
  final bool memoryEnabled;
  final int memoryInterval;
  final bool memoryUseMainApi;
  final bool checkUpdateOnStartup;

  const AppSettings({
    this.globalPromptEnabled = false,
    this.globalPromptText = _defaultGlobalPrompt,
    this.momentsIntervalMinutes = 60,
    this.walletBalance = 999.99,
    this.memoryEnabled = false,
    this.memoryInterval = 10,
    this.memoryUseMainApi = true,
    this.checkUpdateOnStartup = false,
  });

  AppSettings copyWith({
    bool? globalPromptEnabled,
    String? globalPromptText,
    int? momentsIntervalMinutes,
    double? walletBalance,
    bool? memoryEnabled,
    int? memoryInterval,
    bool? memoryUseMainApi,
    bool? checkUpdateOnStartup,
  }) =>
      AppSettings(
        globalPromptEnabled: globalPromptEnabled ?? this.globalPromptEnabled,
        globalPromptText: globalPromptText ?? this.globalPromptText,
        momentsIntervalMinutes:
            momentsIntervalMinutes ?? this.momentsIntervalMinutes,
        walletBalance: walletBalance ?? this.walletBalance,
        memoryEnabled: memoryEnabled ?? this.memoryEnabled,
        memoryInterval: memoryInterval ?? this.memoryInterval,
        memoryUseMainApi: memoryUseMainApi ?? this.memoryUseMainApi,
        checkUpdateOnStartup: checkUpdateOnStartup ?? this.checkUpdateOnStartup,
      );
}

class SettingsNotifier extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings(
      globalPromptEnabled: prefs.getBool(_kGlobalPromptEnabled) ?? false,
      globalPromptText:
          prefs.getString(_kGlobalPromptText) ?? _defaultGlobalPrompt,
      momentsIntervalMinutes: prefs.getInt(_kMomentsIntervalMinutes) ?? 60,
      walletBalance: prefs.getDouble(_kWalletBalance) ?? 999.99,
      memoryEnabled: prefs.getBool(_kMemoryEnabled) ?? false,
      memoryInterval: prefs.getInt(_kMemoryInterval) ?? 10,
      memoryUseMainApi: prefs.getBool(_kMemoryUseMainApi) ?? true,
      checkUpdateOnStartup: prefs.getBool(_kCheckUpdateOnStartup) ?? false,
    );
  }

  Future<void> setGlobalPromptEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kGlobalPromptEnabled, enabled);
    state = AsyncData(state.value!.copyWith(globalPromptEnabled: enabled));
  }

  Future<void> setGlobalPromptText(String text) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kGlobalPromptText, text);
    state = AsyncData(state.value!.copyWith(globalPromptText: text));
  }

  Future<void> setMomentsInterval(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kMomentsIntervalMinutes, minutes);
    state =
        AsyncData(state.value!.copyWith(momentsIntervalMinutes: minutes));
  }

  Future<void> setWalletBalance(double balance) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kWalletBalance, balance);
    state = AsyncData(state.value!.copyWith(walletBalance: balance));
  }

  Future<void> deductBalance(double amount) async {
    final current = state.value?.walletBalance ?? 0;
    if (current >= amount) {
      await setWalletBalance(current - amount);
    }
  }

  Future<void> setMemoryEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kMemoryEnabled, enabled);
    state = AsyncData(state.value!.copyWith(memoryEnabled: enabled));
  }

  Future<void> setMemoryInterval(int interval) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kMemoryInterval, interval);
    state = AsyncData(state.value!.copyWith(memoryInterval: interval));
  }

  Future<void> setCheckUpdateOnStartup(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kCheckUpdateOnStartup, enabled);
    state = AsyncData(state.value!.copyWith(checkUpdateOnStartup: enabled));
  }

  Future<void> setMemoryUseMainApi(bool useMain) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kMemoryUseMainApi, useMain);
    state = AsyncData(state.value!.copyWith(memoryUseMainApi: useMain));
  }
}

final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

// Convenience providers
final globalPromptEnabledProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider).value?.globalPromptEnabled ?? false;
});

final globalPromptTextProvider = Provider<String>((ref) {
  return ref.watch(settingsProvider).value?.globalPromptText ??
      _defaultGlobalPrompt;
});
