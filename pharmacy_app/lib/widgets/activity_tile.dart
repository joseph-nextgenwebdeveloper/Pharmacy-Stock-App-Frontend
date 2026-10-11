import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/app_colors.dart';
import '../config/app_text_styles.dart';
import '../models/activity_log.dart';
import '../models/user.dart';
import 'user_avatar.dart';

IconData activityIcon(String action) {
  switch (action) {
    case 'STOCK_IN':
    case 'GOODS_RECEIVED':
      return Icons.south_west_rounded;
    case 'STOCK_OUT':
    case 'SALE_CREATED':
      return Icons.north_east_rounded;
    case 'LOGIN':
      return Icons.login_rounded;
    case 'LOGOUT':
      return Icons.logout_rounded;
    case 'PROFILE_UPDATED':
      return Icons.person_rounded;
    case 'MEDICINE_CREATED':
    case 'BATCH_CREATED':
    case 'CATEGORY_CREATED':
    case 'SUPPLIER_CREATED':
      return Icons.add_circle_outline_rounded;
    case 'MEDICINE_DELETED':
    case 'BATCH_DELETED':
      return Icons.delete_outline_rounded;
    default:
      return Icons.edit_rounded;
  }
}

String formatWhen(DateTime? t) {
  if (t == null) return '';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(t.year, t.month, t.day);
  final time = DateFormat('HH:mm').format(t);

  if (day == today) return 'Today $time';
  if (day == today.subtract(const Duration(days: 1))) return 'Yesterday $time';
  return '${DateFormat('d MMM').format(t)} $time';
}

/// One line of the activity feed. With [showUser] it also says WHO did it.
class ActivityTile extends StatelessWidget {
  final ActivityLog log;
  final bool showUser;

  const ActivityTile({super.key, required this.log, this.showUser = false});

  @override
  Widget build(BuildContext context) {
    final qty = log.quantity;
    final isIn = (qty ?? 0) > 0;

    final tint = qty == null
        ? AppColors.surface
        : (isIn ? AppColors.successSoft : AppColors.errorSoft);
    final ink = qty == null
        ? AppColors.textSecondary
        : (isIn ? AppColors.primaryDeep : AppColors.error);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => showActivityDetails(context, log),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(11),
                border: qty == null ? Border.all(color: AppColors.border) : null,
              ),
              child: Icon(activityIcon(log.action), size: 19, color: ink),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    log.summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMedium
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    showUser
                        ? '${log.who} · ${User.prettyRoleName(log.userRole)} · ${formatWhen(log.when)}'
                        : '${log.actionLabel.isEmpty ? log.action : log.actionLabel} · ${formatWhen(log.when)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
            ),
            if (qty != null)
              Text(
                '${qty > 0 ? '+' : ''}$qty',
                style: TextStyle(
                  color: ink,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _pretty(String key) {
  final spaced = key.replaceAll('_', ' ');
  return spaced.isEmpty ? key : '${spaced[0].toUpperCase()}${spaced.substring(1)}';
}

/// Full detail of one activity entry: who, when, what, and every value
/// that changed (before → after).
Future<void> showActivityDetails(BuildContext context, ActivityLog log) {
  final rows = <MapEntry<String, String>>[];

  log.changes.forEach((key, value) {
    if (value is Map && value.containsKey('from') && value.containsKey('to')) {
      String show(dynamic v) => (v == null || '$v'.isEmpty) ? '—' : '$v';
      rows.add(MapEntry(_pretty(key), '${show(value['from'])}  →  ${show(value['to'])}'));
    } else if (value != null && '$value'.isNotEmpty) {
      rows.add(MapEntry(_pretty(key), '$value'));
    }
  });

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(sheetContext).size.height * 0.8,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(log.summary, style: AppTextStyles.headingSmall),
              const SizedBox(height: 14),
              Row(
                children: [
                  UserAvatar(
                    url: log.userAvatar,
                    initials: log.who.isEmpty ? '?' : log.who[0].toUpperCase(),
                    radius: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(log.who,
                            style: AppTextStyles.bodyMedium
                                .copyWith(fontWeight: FontWeight.w800)),
                        Text(
                          '${User.prettyRoleName(log.userRole)} · ${log.when == null ? '' : DateFormat('EEE d MMM y, HH:mm').format(log.when!)}',
                          style: AppTextStyles.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _detailRow('Action', log.actionLabel.isEmpty ? log.action : log.actionLabel),
              if (log.targetLabel.isNotEmpty) _detailRow('Item', log.targetLabel),
              if (log.quantity != null)
                _detailRow('Units', '${log.quantity! > 0 ? '+' : ''}${log.quantity}'),
              ...rows.map((e) => _detailRow(e.key, e.value)),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _detailRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(label, style: AppTextStyles.bodySmall),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}
