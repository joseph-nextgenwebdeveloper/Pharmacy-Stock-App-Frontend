import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_sizes.dart';

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,

    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: AppColors.surface,
      error: AppColors.error,
    ),

    scaffoldBackgroundColor: AppColors.background,

    textTheme: GoogleFonts.manropeTextTheme(),

    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.manrope(
        color: AppColors.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w800,
      ),
    ),

    cardTheme: const CardThemeData(
      color: AppColors.surface,
      elevation: AppSizes.cardElevation,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppSizes.radiusMedium)),
        side: BorderSide(color: AppColors.border),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 52),
        backgroundColor: AppColors.primary,
        foregroundColor: const Color(0xFF06170C),
        textStyle: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(100),
        ),
        elevation: 0,
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 52),
        foregroundColor: AppColors.textPrimary,
        side: const BorderSide(color: AppColors.border, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(100),
        ),
      ),
    ),

    dividerTheme: const DividerThemeData(
      color: AppColors.border,
      thickness: 1,
    ),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.dark,
      indicatorColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => GoogleFonts.manrope(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: states.contains(WidgetState.selected)
              ? AppColors.primary
              : const Color(0xFF8A908A),
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? AppColors.primary
              : const Color(0xFF8A908A),
        ),
      ),
    ),
  );
}
