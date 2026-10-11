import 'package:flutter/material.dart';

import '../config/app_colors.dart';

/// The JK Pharmacy logo. In dark mode it sits on a white rounded card so the
/// navy letters stay readable. Falls back to a green icon tile if the image
/// asset isn't bundled.
class BrandLogo extends StatelessWidget {
  final double height;

  const BrandLogo({super.key, this.height = 120});

  static const String asset = 'assets/logos/josekiarie_pharmacy_logo.png';

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      asset,
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stack) => Container(
        width: height * 0.6,
        height: height * 0.6,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(height * 0.15),
        ),
        child: Icon(
          Icons.local_pharmacy_rounded,
          color: const Color(0xFF06170C),
          size: height * 0.32,
        ),
      ),
    );

    if (!AppColors.darkMode) return image;

    return Container(
      padding: EdgeInsets.all(height * 0.1),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(height * 0.2),
      ),
      child: image,
    );
  }
}
