import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'router.dart';
import 'theme/wechat_theme.dart';
import 'providers/contacts_provider.dart';
import 'providers/settings_provider.dart';
import 'services/proactive/proactive_service.dart';
import 'services/update/update_service.dart';
import 'services/backup/auto_backup_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // sqflite on desktop (Windows/Linux) requires FFI initialization because
  // there is no native platform plugin.
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  final container = ProviderContainer();

  final proactive = ProactiveService();
  proactive.init();
  proactive.checkOnAppOpen();
  proactive.onNewMessage = () => container.read(contactsProvider.notifier).refresh();

  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool('check_update_on_startup') ?? false) {
    UpdateService().checkUpdate();
  }

  AutoBackupService().init();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const TalkAiApp(),
    ),
  );
}

class TalkAiApp extends ConsumerWidget {
  const TalkAiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).value;
    final isDark = settings?.darkMode ?? false;

    return MaterialApp.router(
      title: 'Talk AI',
      theme: WeChatTheme.light,
      darkTheme: WeChatTheme.dark,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
