import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/wechat_colors.dart';

class MainScaffold extends StatelessWidget {
  final Widget child;

  const MainScaffold({super.key, required this.child});

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/chats')) return 0;
    if (location.startsWith('/contacts')) return 1;
    if (location.startsWith('/discover')) return 2;
    if (location.startsWith('/profile')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: child, bottomNavigationBar: _buildBottomNav(context));
  }

  Widget _buildBottomNav(BuildContext context) {
    final idx = _currentIndex(context);
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: WeChatColors.divider, width: 0.5),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: idx,
        type: BottomNavigationBarType.fixed,
        backgroundColor: WeChatColors.navigationBarBackground,
        selectedItemColor: WeChatColors.navBarSelected,
        unselectedItemColor: WeChatColors.navBarUnselected,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedFontSize: 10,
        unselectedFontSize: 10,
        elevation: 0,
        onTap: (i) {
          switch (i) {
            case 0:
              context.go('/chats');
              break;
            case 1:
              context.go('/contacts');
              break;
            case 2:
              context.go('/discover');
              break;
            case 3:
              context.go('/profile');
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: Icon(Icons.chat_bubble),
            label: 'SoulTalk',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: '通讯录',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore_outlined),
            activeIcon: Icon(Icons.explore),
            label: '发现',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: '我',
          ),
        ],
      ),
    );
  }
}
