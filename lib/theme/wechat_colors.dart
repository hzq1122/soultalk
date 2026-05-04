import 'package:flutter/material.dart';

/// 微信风格颜色常量
class WeChatColors {
  WeChatColors._();

  /// 主色（微信绿）
  static const Color primary = Color(0xFF07C160);
  static const Color primaryDark = Color(0xFF06AD56);
  static const Color primaryLight = Color(0xFF39D57D);

  /// 背景色
  static const Color background = Color(0xFFF7F7F7);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color navigationBarBackground = Color(0xFFF7F7F7);

  /// 导航栏/AppBar
  static const Color appBarBackground = Color(0xFFEBEBEB);

  /// 文字色
  static const Color textPrimary = Color(0xFF191919);
  static const Color textSecondary = Color(0xFF888888);
  static const Color textHint = Color(0xFFB2B2B2);

  /// 分割线
  static const Color divider = Color(0xFFE5E5E5);

  /// 消息气泡
  static const Color bubbleSent = Color(0xFF95EC69); // 发送（绿色）
  static const Color bubbleReceived = Color(0xFFFFFFFF); // 接收（白色）

  /// 未读角标
  static const Color unreadBadge = Color(0xFFFF3B30);

  /// 搜索框
  static const Color searchBackground = Color(0xFFEFEFEF);

  /// 底部导航
  static const Color navBarSelected = Color(0xFF07C160);
  static const Color navBarUnselected = Color(0xFF000000);

  /// 输入框
  static const Color inputBackground = Color(0xFFFFFFFF);
  static const Color inputBorder = Color(0xFFD9D9D9);
}
