import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/app_colors.dart';
import '../config/app_text_styles.dart';
import '../models/stock_movement.dart';
import '../models/user.dart';
import 'user_avatar.dart';

/// The complete record of one stock movement: what, which batch, how many,
/// balance before and after, why, the reference, and WHO did it and when.
Future<void> showMovementDetails(BuildContext context, StockMovement m) {
  final color = m.isIn ? AppColors.primaryDeep : AppColors.error;
  final when = m.when;

  Widget row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 112, child: Text(label, style: AppTextStyles.bodySmall)),
            Expanded(
              child: Text(
                value,
                style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    m.medicineName.isEmpty ? 'Medicine #${m.medicineId}' : m.medicineName,
                    style: AppTextStyles.headingSmall,
                  ),
                ),
                Text(
                  '${m.isIn ? '+' : '−'}${m.quantity}',
                  style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 24),
                ),
              ],
            ),
            Text(m.label, style: AppTextStyles.bodySmall.copyWith(color: color)),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  UserAvatar(
                    url: m.performedByAvatar,
                    initials: m.who.isEmpty ? '?' : m.who[0].toUpperCase(),
                    radius: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.who,
                            style: AppTextStyles.bodyMedium
                                .copyWith(fontWeight: FontWeight.w800)),
                        Text(
                          '${User.prettyRoleName(m.performedByRole)}'
                          '${when == null ? '' : ' · ${DateFormat('EEE d MMM y, HH:mm').format(when)}'}',
                          style: AppTextStyles.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (m.batchNumber.isNotEmpty) row('Batch', m.batchNumber),
            if (m.quantityBefore != null && m.quantityAfter != null)
              row('Batch balance', '${m.quantityBefore}  →  ${m.quantityAfter}'),
            row('Reason', m.label),
            if (m.reference.isNotEmpty) row('Reference', m.reference),
            if (m.note.isNotEmpty) row('Note', m.note),
            row('Record #', '${m.id}'),
          ],
        ),
      ),
    ),
  );
}
