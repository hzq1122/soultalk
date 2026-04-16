import 'package:flutter/material.dart';
import '../../theme/wechat_colors.dart';

class DiscoverPage extends StatelessWidget {
  const DiscoverPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WeChatColors.background,
      appBar: AppBar(
        title: const Text('发现'),
        backgroundColor: WeChatColors.appBarBackground,
      ),
      body: ListView(
        children: const [
          _DiscoverSection(items: [
            _DiscoverItem(icon: Icons.public, label: '朋友圈', color: Color(0xFF07C160), comingSoon: true),
          ]),
          _DiscoverSection(items: [
            _DiscoverItem(icon: Icons.qr_code_scanner, label: '扫一扫', color: Color(0xFF1E90FF)),
            _DiscoverItem(icon: Icons.search, label: '搜一搜', color: Color(0xFF1E90FF)),
          ]),
          _DiscoverSection(items: [
            _DiscoverItem(icon: Icons.shopping_bag_outlined, label: '购物', color: Color(0xFFFF6B35)),
            _DiscoverItem(icon: Icons.games_outlined, label: '游戏', color: Color(0xFF7ED321)),
          ]),
        ],
      ),
    );
  }
}

class _DiscoverSection extends StatelessWidget {
  final List<_DiscoverItem> items;
  const _DiscoverSection({required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          color: Colors.white,
          child: Column(
            children: items.map((item) {
              final isLast = items.last == item;
              return Column(
                children: [
                  item,
                  if (!isLast)
                    const Divider(height: 0, indent: 56),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _DiscoverItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool comingSoon;

  const _DiscoverItem({
    required this.icon,
    required this.label,
    required this.color,
    this.comingSoon = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
      title: Text(label),
      trailing: comingSoon
          ? const Chip(
              label: Text('即将上线', style: TextStyle(fontSize: 10)),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: EdgeInsets.zero,
            )
          : const Icon(Icons.chevron_right, color: WeChatColors.textHint),
      onTap: comingSoon ? null : () {},
    );
  }
}
