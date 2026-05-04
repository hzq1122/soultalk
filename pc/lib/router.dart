import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'ui/home_page.dart';
import 'ui/scan_page.dart';
import 'ui/chat_page.dart';
import 'ui/settings_page.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomePage()),
    GoRoute(path: '/scan', builder: (context, state) => const ScanPage()),
    GoRoute(
      path: '/chat/:contactId',
      builder: (context, state) {
        final contactId = state.pathParameters['contactId']!;
        return ChatPage(contactId: contactId);
      },
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsPage(),
    ),
  ],
);
