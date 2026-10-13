// lib/theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color cream = Color(0xFFF7F5F0);
  static const Color creamDeep = Color(0xFFEFEAE0);
  static const Color mossGreen = Color(0xFF374936);
  static const Color mossLight = Color(0xFF5E7A5C);
  static const Color terracotta = Color(0xFFC9705B);
  static const Color sage = Color(0xFF7E9A86);
  static const Color amber = Color(0xFFE5A93D);
  static const Color red = Color(0xFFD95D5D);

  static const Color textDark = Color(0xFF2C2A28);
  static const Color textLight = Color(0xFF7A756D);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color hairline = Color(0x1A7A756D);

  /// Мягкий кремовый градиент фона (из дизайн-системы).
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFAF8F3), cream, creamDeep],
  );

  /// Цвет прогресса бюджета: зелёный -> янтарный (>=80%) -> красный (>100%).
  static Color budgetColor(double spent, double limit) {
    if (limit <= 0) return spent > 0 ? red : mossGreen;
    final ratio = spent / limit;
    if (ratio > 1.0) return red;
    if (ratio >= 0.8) return amber;
    return mossGreen;
  }

  static TextStyle get eyebrow => GoogleFonts.instrumentSans(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.4,
        color: textLight,
      );

  static TextStyle mono({double size = 14, Color color = textDark, FontWeight weight = FontWeight.w400}) =>
      GoogleFonts.dmMono(fontSize: size, color: color, fontWeight: weight);

  static TextStyle serif({double size = 24, Color color = textDark, FontStyle style = FontStyle.normal}) =>
      GoogleFonts.libreBaskerville(fontSize: size, color: color, fontStyle: style, height: 1.25);

  static ThemeData get lightTheme {
    final base = ThemeData.light(useMaterial3: true);
    final textTheme = GoogleFonts.instrumentSansTextTheme(base.textTheme)
        .copyWith(
          displayLarge: GoogleFonts.libreBaskerville(color: textDark),
          displayMedium: GoogleFonts.libreBaskerville(color: textDark),
          headlineLarge: GoogleFonts.libreBaskerville(color: textDark),
          headlineMedium: GoogleFonts.libreBaskerville(color: textDark),
          headlineSmall: GoogleFonts.libreBaskerville(color: textDark),
          titleLarge: GoogleFonts.libreBaskerville(color: textDark, fontSize: 20),
          displaySmall: GoogleFonts.dmMono(color: textDark),
        )
        .apply(bodyColor: textDark, displayColor: textDark);

    final inputBorder = OutlineInputBorder(
      borderSide: const BorderSide(color: hairline),
      borderRadius: BorderRadius.circular(12),
    );

    return base.copyWith(
      scaffoldBackgroundColor: cream,
      primaryColor: mossGreen,
      colorScheme: const ColorScheme.light(
        primary: mossGreen,
        secondary: sage,
        surface: cardBackground,
        error: red,
        onPrimary: Colors.white,
        onSurface: textDark,
      ),
      textTheme: textTheme,
      dividerTheme: const DividerThemeData(color: hairline, thickness: 1, space: 1),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: mossGreen,
          textStyle: GoogleFonts.instrumentSans(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: mossGreen,
          side: BorderSide(color: mossGreen.withValues(alpha: 0.35)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: GoogleFonts.instrumentSans(fontWeight: FontWeight.w600),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: mossGreen,
          foregroundColor: Colors.white,
          disabledBackgroundColor: mossGreen.withValues(alpha: 0.3),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.instrumentSans(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          side: const WidgetStatePropertyAll(BorderSide(color: hairline)),
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? mossGreen : Colors.transparent,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? Colors.white : textLight,
          ),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: const BorderSide(color: textLight, width: 1.2),
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? mossGreen : Colors.transparent,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardBackground,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: hairline),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: GoogleFonts.libreBaskerville(fontSize: 20, color: textDark),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: textDark,
        contentTextStyle: GoogleFonts.instrumentSans(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cardBackground,
        indicatorColor: mossGreen.withValues(alpha: 0.12),
        labelTextStyle: WidgetStatePropertyAll(GoogleFonts.instrumentSans(fontSize: 11, fontWeight: FontWeight.w600)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: mossGreen),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardBackground,
        isDense: true,
        hintStyle: TextStyle(color: textLight.withValues(alpha: 0.7), fontSize: 14),
        labelStyle: const TextStyle(color: textLight, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(borderSide: const BorderSide(color: mossGreen, width: 1.5)),
      ),
    );
  }
}
