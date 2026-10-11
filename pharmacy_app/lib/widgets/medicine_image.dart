import 'package:flutter/material.dart';

import '../config/app_colors.dart';

/// Medicine photo that is ALWAYS the same shape and size.
///
/// * a real photo when the medicine has one and it loads;
/// * otherwise (no photo, still loading, offline, broken link) the same
///   default picture: a white medicine bottle with a green cap and cross.
///
/// That keeps every medicine card in the app uniform.
class MedicineImage extends StatelessWidget {
  final String? url;
  final double size;
  final double radius;
  final Color? background;
  final Color? iconColor;

  const MedicineImage({
    super.key,
    required this.url,
    this.size = 40,
    this.radius = 10,
    this.background,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final bg = background ?? AppColors.successSoft;
    final accent = iconColor ?? AppColors.primaryDeep;

    final fallback = DefaultMedicineArt(size: size, accent: accent);

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: (url == null || url!.isEmpty)
          ? fallback
          : Image.network(
              url!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              cacheWidth: (size * 3).round(),
              // While loading, or if it fails (offline / bad link), show the
              // default picture so the card never looks broken.
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return fallback;
              },
              errorBuilder: (context, error, stack) => fallback,
            ),
    );
  }
}

/// The default medicine picture (drawn in code, so it needs no asset file).
class DefaultMedicineArt extends StatelessWidget {
  final double size;
  final Color accent;

  const DefaultMedicineArt({
    super.key,
    required this.size,
    this.accent = AppColors.primaryDeep,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _BottlePainter(accent)),
    );
  }
}

class _BottlePainter extends CustomPainter {
  final Color accent;

  _BottlePainter(this.accent);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    RRect box(double l, double t, double bw, double bh, double r) =>
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w * l, h * t, w * bw, h * bh),
          Radius.circular(w * r),
        );

    // body
    canvas.drawRRect(box(0.27, 0.30, 0.46, 0.54, 0.09), Paint()..color = Colors.white);
    // cap
    canvas.drawRRect(box(0.30, 0.15, 0.40, 0.17, 0.045), Paint()..color = accent);
    // label
    canvas.drawRRect(
      box(0.31, 0.45, 0.38, 0.27, 0.035),
      Paint()..color = accent.withValues(alpha: 0.16),
    );

    // medical cross
    final cx = w * 0.5;
    final cy = h * 0.585;
    final arm = w * 0.075;
    final thick = w * 0.05;
    final p = Paint()..color = accent;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy), width: arm * 2, height: thick),
        Radius.circular(thick / 2),
      ),
      p,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy), width: thick, height: arm * 2),
        Radius.circular(thick / 2),
      ),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant _BottlePainter oldDelegate) =>
      oldDelegate.accent != accent;
}
