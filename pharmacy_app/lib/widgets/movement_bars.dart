import 'package:flutter/material.dart';

import '../config/app_colors.dart';

/// One column of the bar chart: units in (green) and units out (red).
class BarDatum {
  final String label;
  final int unitsIn;
  final int unitsOut;
  final bool highlight;

  const BarDatum({
    required this.label,
    required this.unitsIn,
    required this.unitsOut,
    this.highlight = false,
  });
}

/// Small paired-bar chart (received vs dispensed per day). Works for 7 days
/// or a whole month; labels are only drawn when there is room for them.
class MovementBars extends StatelessWidget {
  final List<BarDatum> data;
  final double height;
  final bool showEveryLabel;

  const MovementBars({
    super.key,
    required this.data,
    this.height = 96,
    this.showEveryLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    var peak = 1;
    for (final d in data) {
      if (d.unitsIn > peak) peak = d.unitsIn;
      if (d.unitsOut > peak) peak = d.unitsOut;
    }

    final dense = data.length > 14;

    return Column(
      children: [
        SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final d in data)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: dense ? 0.6 : 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: _bar(
                            d.unitsIn / peak,
                            AppColors.primary,
                          ),
                        ),
                        SizedBox(width: dense ? 0.5 : 2),
                        Expanded(
                          child: _bar(
                            d.unitsOut / peak,
                            AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (var i = 0; i < data.length; i++)
              Expanded(
                child: Center(
                  child: (showEveryLabel && !dense) ||
                          (dense && (i == 0 || i == data.length - 1 || i % 5 == 0))
                      ? Text(
                          data[i].label,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.visible,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: data[i].highlight
                                ? FontWeight.w900
                                : FontWeight.w700,
                            color: data[i].highlight
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _bar(double fraction, Color color) {
    final f = fraction.clamp(0.0, 1.0).toDouble();

    return FractionallySizedBox(
      heightFactor: f == 0 ? 0.03 : (f < 0.05 ? 0.05 : f),
      alignment: Alignment.bottomCenter,
      child: Container(
        decoration: BoxDecoration(
          color: f == 0 ? color.withValues(alpha: 0.25) : color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}
