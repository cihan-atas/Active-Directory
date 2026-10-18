import 'package:flutter/material.dart';

class AppTheme {
  // Dark Cyber Security Renk Paleti
  static const Color bgDark = Color(0xFF090D16);
  static const Color bgCard = Color(0xFF111827);
  static const Color bgCardHover = Color(0xFF1F2937);
  static const Color bgCode = Color(0xFF0D1117);
  static const Color border = Color(0xFF1E293B);
  static const Color borderHighlight = Color(0xFF334155);

  // Aksan Renkleri
  static const Color redTeam = Color(0xFFEF4444);
  static const Color redTeamGlow = Color(0x33EF4444);
  static const Color blueTeam = Color(0xFF38BDF8);
  static const Color blueTeamGlow = Color(0x3338BDF8);
  static const Color sysAdmin = Color(0xFF10B981);
  static const Color sysAdminGlow = Color(0x3310B981);
  static const Color toolsAmber = Color(0xFFF59E0B);
  static const Color toolsGlow = Color(0x33F59E0B);

  // Metin Renkleri
  static const Color textPrimary = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgDark,
      primaryColor: redTeam,
      colorScheme: const ColorScheme.dark(
        primary: redTeam,
        secondary: blueTeam,
        tertiary: sysAdmin,
        surface: bgCard,
        onSurface: textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bgDark,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      cardTheme: CardTheme(
        color: bgCard,
        elevation: 2,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: border, width: 1),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: bgCard,
        indicatorColor: redTeam.withAlpha(40),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(color: textPrimary, fontSize: 12, fontWeight: FontWeight.w600);
          }
          return const TextStyle(color: textSecondary, fontSize: 12);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: redTeam, size: 24);
          }
          return const IconThemeData(color: textSecondary, size: 22);
        }),
      ),
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
      ),
    );
  }
}
