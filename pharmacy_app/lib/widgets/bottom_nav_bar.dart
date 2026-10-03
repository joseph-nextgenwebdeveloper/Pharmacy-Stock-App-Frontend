import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../config/app_text_styles.dart';

/// Floating black pill tab bar with a raised green center "Scan" button —
/// mirrors the StockRoom prototype's bottom navigation.
class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const _items = [
    (icon: Icons.home_rounded, label: 'Home'),
    (icon: Icons.menu_rounded, label: 'Inventory'),
    (icon: Icons.qr_code_scanner_rounded, label: ''), // center scan button
    (icon: Icons.warning_amber_rounded, label: 'Alerts'),
    (icon: Icons.person_rounded, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Container(
        height: 66,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: AppColors.dark,
          borderRadius: BorderRadius.circular(100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: List.generate(_items.length, (index) {
            final item = _items[index];
            final active = index == currentIndex;

            if (index == 2) {
              // center scan button, raised
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(index),
                  behavior: HitTestBehavior.opaque,
                  child: Transform.translate(
                    offset: const Offset(0, -14),
                    child: Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: active ? Colors.white : AppColors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.5),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Icon(
                        item.icon,
                        color: const Color(0xFF06170C),
                        size: 22,
                      ),
                    ),
                  ),
                ),
              );
            }

            final color = active ? AppColors.primary : const Color(0xFF8A908A);

            return Expanded(
              child: GestureDetector(
                onTap: () => onTap(index),
                behavior: HitTestBehavior.opaque,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(item.icon, color: color, size: 21),
                    const SizedBox(height: 3),
                    Text(
                      item.label,
                      style: AppTextStyles.label.copyWith(
                        color: color,
                        fontSize: 9.5,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
