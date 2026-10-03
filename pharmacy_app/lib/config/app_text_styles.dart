import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

class AppTextStyles {
  static TextStyle get headingLarge => GoogleFonts.manrope(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      );

  static TextStyle get headingMedium => GoogleFonts.manrope(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      );

  static TextStyle get headingSmall => GoogleFonts.manrope(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      );

  static TextStyle get bodyLarge => GoogleFonts.manrope(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      );

  static TextStyle get bodyMedium => GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      );

  static TextStyle get bodySmall => GoogleFonts.manrope(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      );

  static TextStyle get button => GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      );

  static TextStyle get label => GoogleFonts.manrope(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
      );
}
