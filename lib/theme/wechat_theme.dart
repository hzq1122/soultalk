import 'package:flutter/material.dart';
import 'wechat_colors.dart';

class WeChatTheme {
  WeChatTheme._();

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: WeChatColors.primary,
        brightness: Brightness.light,
        primary: WeChatColors.primary,
        surface: WeChatColors.cardBackground,
        onSurface: WeChatColors.textPrimary,
      ),
      scaffoldBackgroundColor: WeChatColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: WeChatColors.appBarBackground,
        foregroundColor: WeChatColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: WeChatColors.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: WeChatColors.navigationBarBackground,
        indicatorColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: WeChatColors.navBarSelected, size: 24);
          }
          return const IconThemeData(color: WeChatColors.navBarUnselected, size: 24);
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
      dividerTheme: const DividerThemeData(
        color: WeChatColors.divider,
        thickness: 0.5,
        space: 0,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        titleTextStyle: TextStyle(
          color: WeChatColors.textPrimary,
          fontSize: 16,
        ),
        subtitleTextStyle: TextStyle(
          color: WeChatColors.textSecondary,
          fontSize: 13,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: WeChatColors.inputBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: WeChatColors.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: WeChatColors.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: WeChatColors.primary),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        hintStyle: const TextStyle(color: WeChatColors.textHint, fontSize: 15),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: WeChatColors.primary,
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
