import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const parchment = Color(0xFFF6F1EA);
  static const paper = Color(0xFFFFFBF7);
  static const ink = Color(0xFF1C1612);
  static const muted = Color(0xFF7A7068);
  static const line = Color(0xFFE4D9CC);
  static const terracotta = Color(0xFFC45C26);
  static const terracottaSoft = Color(0xFFF3E1D4);
  static const sage = Color(0xFF3F5E51);
  static const sageSoft = Color(0xFFDCE6E0);
  static const clay = Color(0xFFD9C7B8);
  static const gold = Color(0xFFB0894F);
}

class AppTheme {
  static ThemeData light() {
    final display = GoogleFonts.playfairDisplayTextTheme();
    final body = GoogleFonts.plusJakartaSansTextTheme();

    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.terracotta,
      brightness: Brightness.light,
      primary: AppColors.terracotta,
      onPrimary: Colors.white,
      secondary: AppColors.sage,
      onSecondary: Colors.white,
      surface: AppColors.paper,
      onSurface: AppColors.ink,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.parchment,
      textTheme: body.copyWith(
        displayLarge: display.displayLarge?.copyWith(
          color: AppColors.ink,
          fontWeight: FontWeight.w600,
        ),
        displayMedium: display.displayMedium?.copyWith(
          color: AppColors.ink,
          fontWeight: FontWeight.w600,
        ),
        displaySmall: display.displaySmall?.copyWith(
          color: AppColors.ink,
          fontWeight: FontWeight.w600,
        ),
        headlineLarge: display.headlineLarge?.copyWith(
          color: AppColors.ink,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.4,
        ),
        headlineMedium: display.headlineMedium?.copyWith(
          color: AppColors.ink,
          fontWeight: FontWeight.w600,
        ),
        headlineSmall: display.headlineSmall?.copyWith(
          color: AppColors.ink,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: body.titleLarge?.copyWith(
          color: AppColors.ink,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: body.titleMedium?.copyWith(
          color: AppColors.ink,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: body.bodyLarge?.copyWith(color: AppColors.ink, height: 1.45),
        bodyMedium: body.bodyMedium?.copyWith(
          color: AppColors.muted,
          height: 1.45,
        ),
        labelLarge: body.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.parchment,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.playfairDisplay(
          color: AppColors.ink,
          fontSize: 28,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.paper,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: AppColors.line),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.paper,
        selectedColor: AppColors.ink,
        labelStyle: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        secondaryLabelStyle: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        side: const BorderSide(color: AppColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.ink,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          side: const BorderSide(color: AppColors.line),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.paper,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.ink, width: 1.4),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.paper,
        indicatorColor: AppColors.terracottaSoft,
        elevation: 0,
        height: 72,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? AppColors.ink
                : AppColors.muted,
          );
        }),
      ),
      dividerColor: AppColors.line,
      splashFactory: InkSparkle.splashFactory,
    );
  }
}
