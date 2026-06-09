import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Light Theme Colors
  static const Color textLight = Color(0xFF6b6375);
  static const Color textHLight = Color(0xFF08060d);
  static const Color bgLight = Color(0xFFffffff);
  static const Color borderLight = Color(0xFFe5e4e7);
  static const Color codeBgLight = Color(0xFFf4f3ec);
  static const Color accentLight = Color(0xFFf08232);
  static const Color accentBgLight = Color(0x19f08232); // 0.1 opacity
  static const Color socialBgLight = Color(0x7ff4f3ec); // 0.5 opacity

  // Dark Theme Colors
  static const Color textDark = Color(0xFF9ca3af);
  static const Color textHDark = Color(0xFFf3f4f6);
  static const Color bgDark = Color(0xFF16171d);
  static const Color borderDark = Color(0xFF2e303a);
  static const Color codeBgDark = Color(0xFF1f2028);
  static const Color accentDark = Color(0xFFf59e0b);
  static const Color accentBgDark = Color(0x26f59e0b); // 0.15 opacity
  static const Color socialBgDark = Color(0x7f2f303a); // 0.5 opacity

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: accentLight,
      scaffoldBackgroundColor: bgLight,
      useMaterial3: true,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      textTheme: GoogleFonts.interTextTheme().copyWith(
        headlineLarge: GoogleFonts.inter(color: textHLight, fontSize: 20, fontWeight: FontWeight.w600), // Header
        headlineMedium: GoogleFonts.inter(color: textHLight, fontSize: 20, fontWeight: FontWeight.w600), // Amounts
        titleLarge: GoogleFonts.inter(color: textHLight, fontSize: 18, fontWeight: FontWeight.w600), // Card titles
        bodyMedium: GoogleFonts.inter(color: textLight, fontSize: 14, fontWeight: FontWeight.w400), // Body text
        labelSmall: GoogleFonts.inter(color: textLight, fontSize: 12, fontWeight: FontWeight.w500), // Bottom navigation
      ),
      colorScheme: const ColorScheme.light(
        primary: accentLight,
        secondary: accentLight,
        surface: bgLight,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textLight,
      ),
      dividerColor: borderLight,
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide(color: accentLight, width: 2),
        ),
        floatingLabelStyle: TextStyle(color: accentLight),
        labelStyle: TextStyle(color: Color(0xFF888888)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentLight,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accentLight,
          side: BorderSide(color: accentLight),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: accentLight),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: accentLight),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? accentLight : null),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? accentLight : null),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? accentLight.withAlpha(100) : null),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: accentDark,
      scaffoldBackgroundColor: bgDark,
      textTheme: GoogleFonts.interTextTheme().copyWith(
        headlineLarge: GoogleFonts.inter(color: textHDark, fontSize: 20, fontWeight: FontWeight.w600), // Header
        headlineMedium: GoogleFonts.inter(color: textHDark, fontSize: 20, fontWeight: FontWeight.w600), // Amounts
        titleLarge: GoogleFonts.inter(color: textHDark, fontSize: 18, fontWeight: FontWeight.w600), // Card titles
        bodyMedium: GoogleFonts.inter(color: textDark, fontSize: 14, fontWeight: FontWeight.w400), // Body text
        labelSmall: GoogleFonts.inter(color: textDark, fontSize: 12, fontWeight: FontWeight.w500), // Bottom navigation
      ),
      colorScheme: const ColorScheme.dark(
        primary: accentDark,
        secondary: accentDark,
        surface: bgDark,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textDark,
      ),
      dividerColor: borderDark,
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide(color: accentDark, width: 2),
        ),
        floatingLabelStyle: TextStyle(color: accentDark),
        labelStyle: TextStyle(color: Color(0xFF9ca3af)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentDark,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accentDark,
          side: BorderSide(color: accentDark),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: accentDark),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: accentDark),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? accentDark : null),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? accentDark : null),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? accentDark.withAlpha(100) : null),
      ),
    );
  }
}
