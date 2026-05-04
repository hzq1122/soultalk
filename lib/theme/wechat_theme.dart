import 'package:flutter/material.dart';
import 'wechat_colors.dart';

class WeChatTheme {
  WeChatTheme._();

  static ThemeData get light => _buildTheme(Brightness.light);

  static ThemeData get dark => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    const primary = WeChatColors.primary;
    final bg = isDark ? const Color(0xFF111111) : WeChatColors.background;
    final surface = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final appBarBg = isDark
        ? const Color(0xFF1E1E1E)
        : WeChatColors.appBarBackground;
    final navBg = isDark
        ? const Color(0xFF1E1E1E)
        : WeChatColors.navigationBarBackground;
    final textPrimary = isDark
        ? const Color(0xFFE5E5E5)
        : WeChatColors.textPrimary;
    final textSecondary = isDark
        ? const Color(0xFF999999)
        : WeChatColors.textSecondary;
    final textHint = isDark ? const Color(0xFF666666) : WeChatColors.textHint;
    final divider = isDark ? const Color(0xFF2C2C2C) : WeChatColors.divider;
    final inputBg = isDark
        ? const Color(0xFF2C2C2C)
        : WeChatColors.inputBackground;
    final inputBorder = isDark
        ? const Color(0xFF3A3A3A)
        : WeChatColors.inputBorder;
    final cardBg = isDark
        ? const Color(0xFF1E1E1E)
        : WeChatColors.cardBackground;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: brightness,
        primary: primary,
        surface: cardBg,
        onSurface: textPrimary,
      ),
      scaffoldBackgroundColor: bg,
      appBarTheme: AppBarTheme(
        backgroundColor: appBarBg,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: navBg,
        indicatorColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(
              color: WeChatColors.navBarSelected,
              size: 24,
            );
          }
          return const IconThemeData(
            color: WeChatColors.navBarUnselected,
            size: 24,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: WeChatColors.navBarSelected,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            );
          }
          return const TextStyle(
            color: WeChatColors.navBarUnselected,
            fontSize: 10,
          );
        }),
      ),
      dividerTheme: DividerThemeData(color: divider, thickness: 0.5, space: 0),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        titleTextStyle: TextStyle(color: textPrimary, fontSize: 16),
        subtitleTextStyle: TextStyle(color: textSecondary, fontSize: 13),
      ),
      cardColor: surface,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: primary),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        hintStyle: TextStyle(color: textHint, fontSize: 15),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}
