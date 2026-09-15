import 'package:flutter/material.dart';

class StockBadge extends StatelessWidget {
  final int quantity;
  final int reorderLevel;

  const StockBadge({
    super.key,
    required this.quantity,
    required this.reorderLevel,
  });

  @override
  Widget build(BuildContext context) {
    late final String text;
    late final Color color;

    if (quantity <= 0) {
      text = "Out of Stock";
      color = Colors.red;
    } else if (quantity <= reorderLevel) {
      text = "Low Stock";
      color = Colors.orange;
    } else {
      text = "In Stock";
      color = Colors.green;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}