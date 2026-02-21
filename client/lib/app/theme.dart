import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ═══════════════════════════════════════════════════════════════════
  // V1 Design System — Colors
  // ═══════════════════════════════════════════════════════════════════
  static const Color primary = Color(0xFFE91E63);
  static const Color secondary = Color(0xFF9C27B0);
  static const Color bgDark = Color(0xFF1A1A2E);
  static const Color surfaceDark = Color(0xFF16213E);
  static const Color deepDark = Color(0xFF0F0F1E);
  static const Color cyan = Color(0xFF00BCD4);
  static const Color success = Color(0xFF4CAF50);
  static const Color gold = Color(0xFFFFD700);
  static const Color warning = Color(0xFFFFA726);

  // Light theme colors
  static const Color bgLight = Color(0xFFF5F5FA);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF1A1A2E);
  static const Color textSecondaryLight = Color(0xFF666680);

  // Gradient
  static const LinearGradient accentGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient accentGradientVertical = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ═══════════════════════════════════════════════════════════════════
  // Helpers
  // ═══════════════════════════════════════════════════════════════════
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color surfaceColor(BuildContext context) =>
      isDark(context) ? surfaceDark : surfaceLight;

  static Color backgroundColor(BuildContext context) =>
      isDark(context) ? bgDark : bgLight;

  static Color textMuted(BuildContext context) =>
      isDark(context) ? Colors.white38 : const Color(0xFF999999);

  static Color textSecondary(BuildContext context) =>
      isDark(context) ? Colors.white70 : textSecondaryLight;

  // Glassmorphism decoration
  static BoxDecoration glassmorphism({double opacity = 0.7}) => BoxDecoration(
        color: Colors.black.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(20),
      );

  // ═══════════════════════════════════════════════════════════════════
  // Typography — Nunito (body/UI) + Playfair Display (logo/headlines)
  // ═══════════════════════════════════════════════════════════════════
  static TextTheme _buildTextTheme(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final base = isLight ? Colors.black87 : Colors.white;
    final muted = isLight ? const Color(0xFF666680) : Colors.white70;

    return TextTheme(
      displayLarge: GoogleFonts.playfairDisplay(
        fontSize: 32, fontWeight: FontWeight.bold, color: base,
      ),
      displayMedium: GoogleFonts.playfairDisplay(
        fontSize: 28, fontWeight: FontWeight.bold, color: base,
      ),
      headlineLarge: GoogleFonts.nunito(
        fontSize: 28, fontWeight: FontWeight.bold, color: base,
      ),
      headlineMedium: GoogleFonts.nunito(
        fontSize: 24, fontWeight: FontWeight.bold, color: base,
      ),
      headlineSmall: GoogleFonts.nunito(
        fontSize: 20, fontWeight: FontWeight.w700, color: base,
      ),
      titleLarge: GoogleFonts.nunito(
        fontSize: 18, fontWeight: FontWeight.w600, color: base,
      ),
      titleMedium: GoogleFonts.nunito(
        fontSize: 16, fontWeight: FontWeight.w600, color: base,
      ),
      titleSmall: GoogleFonts.nunito(
        fontSize: 14, fontWeight: FontWeight.w600, color: base,
      ),
      bodyLarge: GoogleFonts.nunito(
        fontSize: 18, color: base, height: 1.5,
      ),
      bodyMedium: GoogleFonts.nunito(
        fontSize: 16, color: muted,
      ),
      bodySmall: GoogleFonts.nunito(
        fontSize: 14, color: muted,
      ),
      labelLarge: GoogleFonts.nunito(
        fontSize: 16, fontWeight: FontWeight.w600, color: base,
      ),
      labelMedium: GoogleFonts.nunito(
        fontSize: 14, fontWeight: FontWeight.w500, color: base,
      ),
      labelSmall: GoogleFonts.nunito(
        fontSize: 12, fontWeight: FontWeight.w500, color: muted,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // Dark Theme
  // ═══════════════════════════════════════════════════════════════════
  static ThemeData get darkTheme => ThemeData(
        brightness: Brightness.dark,
        primaryColor: primary,
        scaffoldBackgroundColor: bgDark,
        colorScheme: const ColorScheme.dark(
          primary: primary,
          secondary: secondary,
          surface: surfaceDark,
          onSurface: Colors.white,
          onPrimary: Colors.white,
          error: Color(0xFFCF6679),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
        ),
        textTheme: _buildTextTheme(Brightness.dark),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: deepDark,
          selectedItemColor: primary,
          unselectedItemColor: Colors.white38,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          unselectedLabelStyle: TextStyle(fontSize: 12),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: surfaceDark,
          selectedColor: primary,
          labelStyle: GoogleFonts.nunito(fontSize: 14, color: Colors.white),
          side: const BorderSide(color: Colors.white12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surfaceDark,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          hintStyle: const TextStyle(color: Colors.white38),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            textStyle: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white60,
            side: const BorderSide(color: Colors.white24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
        ),
        cardTheme: CardThemeData(
          color: surfaceDark,
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        dividerTheme: const DividerThemeData(
          color: Colors.white10,
          thickness: 0.5,
        ),
      );

  // ═══════════════════════════════════════════════════════════════════
  // Light Theme
  // ═══════════════════════════════════════════════════════════════════
  static ThemeData get lightTheme => ThemeData(
        brightness: Brightness.light,
        primaryColor: primary,
        scaffoldBackgroundColor: bgLight,
        colorScheme: const ColorScheme.light(
          primary: primary,
          secondary: secondary,
          surface: surfaceLight,
          onSurface: textDark,
          onPrimary: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: textDark),
        ),
        textTheme: _buildTextTheme(Brightness.light),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: surfaceLight,
          selectedItemColor: primary,
          unselectedItemColor: Color(0xFF999999),
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          unselectedLabelStyle: TextStyle(fontSize: 12),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: bgLight,
          selectedColor: primary,
          labelStyle: GoogleFonts.nunito(fontSize: 14, color: textDark),
          side: const BorderSide(color: Color(0xFFDDDDDD)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surfaceLight,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
          ),
          hintStyle: const TextStyle(color: Color(0xFF999999)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            textStyle: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: textDark,
            side: const BorderSide(color: Color(0xFFDDDDDD)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
        ),
        cardTheme: CardThemeData(
          color: surfaceLight,
          elevation: 2,
          shadowColor: Colors.black12,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFFEEEEEE),
          thickness: 0.5,
        ),
      );
}
