import 'dart:io';
import 'package:flutter/material.dart';
import '../models/contact.dart';

/// 通用头像组件：支持本地文件路径 + 首字母 fallback
class AvatarWidget extends StatelessWidget {
  final String? imagePath;
  final String name;
  final double size;
  final BorderRadius? borderRadius;

  const AvatarWidget({
    super.key,
    this.imagePath,
    required this.name,
    this.size = 48,
    this.borderRadius,
  });

  factory AvatarWidget.fromContact(Contact contact, {double size = 48}) {
    return AvatarWidget(
      imagePath: contact.avatar,
      name: contact.name,
      size: size,
    );
  }

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(6);
    Widget avatar;

    if (imagePath != null && imagePath!.isNotEmpty) {
      final file = File(imagePath!);
      if (file.existsSync()) {
        avatar = Image.file(
          file,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) => _letterAvatar(),
        );
      } else {
        avatar = _letterAvatar();
      }
    } else {
      avatar = _letterAvatar();
    }

    return ClipRRect(borderRadius: radius, child: avatar);
  }

  Widget _letterAvatar() {
    final letter = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final color = _colorFromName(name);
    return Container(
      width: size,
      height: size,
      color: color,
      child: Center(
        child: Text(
          letter,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.44,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Color _colorFromName(String name) {
    const colors = [
      Color(0xFF5BA4CF),
      Color(0xFF8A6BC5),
      Color(0xFFE67C3C),
      Color(0xFF3DAA72),
      Color(0xFFD64E4E),
      Color(0xFF4EACD6),
      Color(0xFFC45AB3),
      Color(0xFF7D9F6C),
    ];
    if (name.isEmpty) return colors[0];
    return colors[name.codeUnitAt(0) % colors.length];
  }
}
