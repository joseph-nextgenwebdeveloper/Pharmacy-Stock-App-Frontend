import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/app_colors.dart';
import '../../config/app_text_styles.dart';
import '../../helpers/formatter.dart';
import '../../models/batch.dart';
import '../../models/medicine.dart';
import '../../models/notification.dart';
import '../../providers/batch_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/notification_provider.dart';
import '../../routes/route_names.dart';
import '../../widgets/error_widget.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/medicine_image.dart';

enum _AlertTab { stock, expiry, inbox }

/// Alerts, in three tabs:
///  * Stock  — out of stock / running low, straight from the real stock levels
///  * Expiry — expired and soon-to-expire batches
///  * Inbox  — the server's notifications. An out-of-stock alert is repeated
///             every 2 hours (phone notification too) until stock is added.
class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  _AlertTab _tab = _AlertTab.stock;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InventoryProvider>().loadMedicines();
      context.read<BatchProvider>().loadBatches();
      context.read<NotificationProvider>().loadNotifications();
    });
  }

  Future<void> _refresh() async {
    await Future.wait([
      context.read<InventoryProvider>().refresh(),
      context.read<BatchProvider>().refresh(),
      context.read<NotificationProvider>().refresh(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final inventory = context.watch<InventoryProvider>();
    final batches = context.watch<BatchProvider>();
    final inbox = context.watch<NotificationProvider>();

    if (inventory.isLoading && inventory.medicines.isEmpty) {
      return const LoadingWidget();
    }
    if (inventory.error != null && inventory.medicines.isEmpty) {
      return AppErrorWidget(
        message: inventory.error!,
        onRetry: inventory.loadMedicines,
      );
    }

    final outOfStock = inventory.outOfStock;
    final lowStock = inventory.lowStock;
    final flagged = [...outOfStock, ...lowStock];

    final expired = batches.batches.where((b) => b.isExpired).toList()
      ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
    final expiring = batches.batches
        .where((b) => b.isActive && b.isExpiringSoon)
        .toList()
      ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
          children: [
            Text('Alerts', style: AppTextStyles.headingLarge),
            const SizedBox(height: 14),
            _summaryCard(
              flagged: flagged.length,
              total: inventory.medicines.length,
              out: outOfStock.length,
              low: lowStock.length,
              expired: expired.length,
              expiring: expiring.length,
            ),
            const SizedBox(height: 14),
            _tabs(
              stock: flagged.length,
              expiry: expired.length + expiring.length,
              unread: inbox.unreadCount,
            ),
            const SizedBox(height: 14),
            if (_tab == _AlertTab.stock) ..._stockList(inventory, flagged),
            if (_tab == _AlertTab.expiry) ..._expiryList(inventory, expired, expiring),
            if (_tab == _AlertTab.inbox) ..._inboxList(inbox, inventory),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------- header

  Widget _summaryCard({
    required int flagged,
    required int total,
    required int out,
    required int low,
    required int expired,
    required int expiring,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.dark,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Below reorder threshold',
            style: TextStyle(
              color: AppColors.onDarkMuted,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Text.rich(
            TextSpan(
              text: '$flagged ',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w800,
              ),
              children: [
                TextSpan(
                  text: 'of $total SKUs',
                  style: const TextStyle(
                    color: AppColors.onDarkMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip('$out out of stock', const Color(0x33EF4444),
                  const Color(0xFFFF9A9A)),
              _chip('$low running low', Colors.white.withValues(alpha: 0.1),
                  Colors.white),
              if (expired > 0)
                _chip('$expired expired batch${expired == 1 ? '' : 'es'}',
                    const Color(0x33EF4444), const Color(0xFFFF9A9A)),
              if (expiring > 0)
                _chip('$expiring expiring soon', const Color(0x33F5B93E),
                    const Color(0xFFFFD98A)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tabs({required int stock, required int expiry, required int unread}) {
    Widget tab(_AlertTab t, String label, int count) {
      final selected = _tab == t;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _tab = t),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? AppColors.dark : AppColors.surface,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: selected ? AppColors.dark : AppColors.border,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                  ),
                ),
                if (count > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        tab(_AlertTab.stock, 'Stock', stock),
        const SizedBox(width: 8),
        tab(_AlertTab.expiry, 'Expiry', expiry),
        const SizedBox(width: 8),
        tab(_AlertTab.inbox, 'Inbox', unread),
      ],
    );
  }

  // ---------------------------------------------------------- stock tab

  List<Widget> _stockList(InventoryProvider inventory, List<Medicine> flagged) {
    if (flagged.isEmpty) {
      return [_empty('Everything is well stocked right now.')];
    }

    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          'Out-of-stock items send a phone notification now and again every '
          '2 hours until stock is added.',
          style: AppTextStyles.bodySmall,
        ),
      ),
      ...flagged.map((medicine) {
        final isOut = medicine.quantity <= 0;
        return GestureDetector(
          onTap: () => context.push(RouteNames.medicineDetail(medicine.id)),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    MedicineImage(
                      url: medicine.imageUrl,
                      size: 44,
                      radius: 12,
                      background: AppColors.errorSoft,
                      iconColor: AppColors.error,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        medicine.name,
                        style: AppTextStyles.bodyMedium
                            .copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 34),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      onPressed: () => context.push(
                        Uri(
                          path: RouteNames.createBatch,
                          queryParameters: {'medicine': '${medicine.id}'},
                        ).toString(),
                      ),
                      child: const Text('Add stock'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  isOut
                      ? '0 left · out of stock'
                      : '${medicine.quantity} left · reorder at ${medicine.reorderLevel}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isOut ? AppColors.error : AppColors.textSecondary,
                    fontWeight: isOut ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(100),
                  child: LinearProgressIndicator(
                    value: medicine.reorderLevel == 0
                        ? 0
                        : (medicine.quantity / medicine.reorderLevel)
                            .clamp(0, 1)
                            .toDouble(),
                    minHeight: 6,
                    backgroundColor: AppColors.border,
                    valueColor: const AlwaysStoppedAnimation(AppColors.error),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    ];
  }

  // --------------------------------------------------------- expiry tab

  List<Widget> _expiryList(
    InventoryProvider inventory,
    List<Batch> expired,
    List<Batch> expiring,
  ) {
    if (expired.isEmpty && expiring.isEmpty) {
      return [_empty('No expired or expiring batches. 🎉')];
    }

    Widget row(Batch b, {required bool isExpired}) {
      final medicine = inventory.byId(b.medicineId);
      final days = b.daysToExpiry;
      final color = isExpired ? AppColors.error : AppColors.warning;

      return GestureDetector(
        onTap: () => context.push(RouteNames.batchDetail(b.id)),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              MedicineImage(
                url: medicine?.imageUrl,
                size: 44,
                radius: 12,
                background: isExpired ? AppColors.errorSoft : AppColors.warningSoft,
                iconColor: color,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      b.medicineName,
                      style: AppTextStyles.bodyMedium
                          .copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Batch ${b.batchNumber} · ${b.quantity} units',
                      style: AppTextStyles.bodySmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isExpired
                          ? 'Expired ${Formatter.date(b.expiryDate)} — cannot be dispensed'
                          : (days == null
                              ? 'Expires ${Formatter.date(b.expiryDate)}'
                              : 'Expires in $days day${days == 1 ? '' : 's'} (${Formatter.date(b.expiryDate)})'),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
            ],
          ),
        ),
      );
    }

    return [
      if (expired.isNotEmpty) ...[
        _section('Expired (still in stock)'),
        ...expired.map((b) => row(b, isExpired: true)),
      ],
      if (expiring.isNotEmpty) ...[
        _section('Expiring soon'),
        ...expiring.map((b) => row(b, isExpired: false)),
      ],
    ];
  }

  // ---------------------------------------------------------- inbox tab

  List<Widget> _inboxList(NotificationProvider inbox, InventoryProvider inventory) {
    if (inbox.isLoading && inbox.notifications.isEmpty) {
      return [const Padding(padding: EdgeInsets.all(30), child: LoadingWidget())];
    }
    if (inbox.notifications.isEmpty) {
      return [_empty('No notifications yet.')];
    }

    return [
      if (inbox.unreadCount > 0)
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: inbox.markAllAsRead,
            child: const Text('Mark all as read'),
          ),
        ),
      ...inbox.notifications.map((n) => _notificationTile(n, inbox, inventory)),
    ];
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'OUT_OF_STOCK':
        return Icons.remove_shopping_cart_rounded;
      case 'LOW_STOCK':
        return Icons.trending_down_rounded;
      case 'MEDICINE_EXPIRED':
        return Icons.event_busy_rounded;
      case 'MEDICINE_EXPIRING':
        return Icons.hourglass_bottom_rounded;
      case 'PURCHASE_RECEIVED':
        return Icons.local_shipping_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Widget _notificationTile(
    AppNotification n,
    NotificationProvider inbox,
    InventoryProvider inventory,
  ) {
    final urgent = n.notificationType == 'OUT_OF_STOCK' ||
        n.notificationType == 'MEDICINE_EXPIRED';
    final medicine = n.medicineId == null ? null : inventory.byId(n.medicineId!);

    return GestureDetector(
      onTap: () {
        if (!n.isRead) inbox.markAsRead(n.id);
        if (n.medicineId != null) {
          context.push(RouteNames.medicineDetail(n.medicineId!));
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: n.isRead ? AppColors.surface : AppColors.successSoft,
          border: Border.all(
            color: n.isRead ? AppColors.border : AppColors.primary.withValues(alpha: 0.4),
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (medicine != null)
              MedicineImage(
                url: medicine.imageUrl,
                size: 44,
                radius: 12,
                background: urgent ? AppColors.errorSoft : AppColors.successSoft,
                iconColor: urgent ? AppColors.error : AppColors.primaryDeep,
              )
            else
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: urgent ? AppColors.errorSoft : AppColors.successSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _iconFor(n.notificationType),
                  color: urgent ? AppColors.error : AppColors.primaryDeep,
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          n.title.isEmpty ? 'Notification' : n.title,
                          style: AppTextStyles.bodyMedium
                              .copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (!n.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(n.message, style: AppTextStyles.bodySmall),
                  const SizedBox(height: 6),
                  Text(
                    n.reminderCount > 0
                        ? 'Reminder ${n.reminderCount} · ${Formatter.timeAgo(n.createdAt)}'
                        : Formatter.timeAgo(n.createdAt),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------ helpers

  Widget _section(String text) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 10),
        child: Text(text, style: AppTextStyles.headingSmall),
      );

  Widget _empty(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(child: Text(text, style: AppTextStyles.bodyMedium)),
      );

  Widget _chip(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 11.5),
      ),
    );
  }
}
