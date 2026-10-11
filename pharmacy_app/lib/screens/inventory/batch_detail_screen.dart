import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/app_colors.dart';
import '../../config/app_text_styles.dart';
import '../../helpers/formatter.dart';
import '../../models/batch.dart';
import '../../models/medicine.dart';
import '../../providers/batch_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/stock_movement_provider.dart';
import '../../routes/route_names.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/medicine_image.dart';
import '../../widgets/movement_details.dart';

/// Complete details of a single batch, plus every movement recorded on it.
class BatchDetailScreen extends StatefulWidget {
  final int batchId;

  const BatchDetailScreen({super.key, required this.batchId});

  @override
  State<BatchDetailScreen> createState() => _BatchDetailScreenState();
}

class _BatchDetailScreenState extends State<BatchDetailScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BatchProvider>().loadBatches();
      context.read<InventoryProvider>().loadMedicines();
      context.read<StockMovementProvider>().loadMovements();
    });
  }

  @override
  Widget build(BuildContext context) {
    final batchProvider = context.watch<BatchProvider>();
    final inventory = context.watch<InventoryProvider>();
    final movements = context.watch<StockMovementProvider>();

    final batch = batchProvider.byId(widget.batchId);

    if (batch == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Batch')),
        body: batchProvider.isLoading
            ? const LoadingWidget()
            : const Center(child: Text('Batch not found.')),
      );
    }

    Medicine? med;
    for (final m in inventory.medicines) {
      if (m.id == batch.medicineId) med = m;
    }

    final history = movements.movements
        .where((m) => m.batchId == batch.id)
        .toList()
      ..sort((a, b) => b.movementDate.compareTo(a.movementDate));

    final received = batch.originalQuantity > 0
        ? batch.originalQuantity
        : batch.quantity;
    final used = (received - batch.quantity).clamp(0, received);
    final margin = batch.sellingPrice - batch.buyingPrice;

    final statusColor = batch.isExpired
        ? AppColors.error
        : batch.isDepleted
            ? AppColors.textSecondary
            : batch.isExpiringSoon
                ? AppColors.warning
                : AppColors.primaryDeep;

    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            children: [
              Expanded(child: Text(label, style: AppTextStyles.bodySmall)),
              Text(value,
                  style: AppTextStyles.bodyMedium
                      .copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
        );

    Widget card(String title, List<Widget> children) => Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.headingSmall),
              const SizedBox(height: 6),
              ...children,
            ],
          ),
        );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text('Batch ${batch.batchNumber}')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          GestureDetector(
            onTap: () => context.push(RouteNames.medicineDetail(batch.medicineId)),
            child: Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  MedicineImage(url: med?.imageUrl, size: 54, radius: 14),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          batch.medicineName.isNotEmpty
                              ? batch.medicineName
                              : (med?.name ?? 'Medicine #${batch.medicineId}'),
                          style: AppTextStyles.headingSmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'SKU ${batch.medicineSku.isNotEmpty ? batch.medicineSku : (med?.sku ?? '-')}',
                          style: AppTextStyles.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      batch.isExpiringSoon ? 'Expiring soon' : batch.statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Row(
            children: [
              _bigStat('Available', '${batch.quantity}', statusColor),
              const SizedBox(width: 10),
              _bigStat('Received', '$received', AppColors.textPrimary),
              const SizedBox(width: 10),
              _bigStat('Used', '$used', AppColors.textPrimary),
            ],
          ),
          const SizedBox(height: 14),
          card('Dates', [
            row('Manufactured', Formatter.date(batch.manufactureDate)),
            row('Expires', Formatter.date(batch.expiryDate)),
            row('Received on', Formatter.date(batch.receivedDate)),
            if (batch.daysToExpiry != null && !batch.isDepleted)
              row(
                'Time left',
                batch.daysToExpiry! < 0
                    ? 'Expired ${-batch.daysToExpiry!} days ago'
                    : '${batch.daysToExpiry} days',
              ),
          ]),
          card('Supplier & pricing', [
            row('Supplier',
                batch.supplierName.isEmpty ? '-' : batch.supplierName),
            row('Purchase price', Formatter.number(batch.buyingPrice)),
            row('Selling price', Formatter.number(batch.sellingPrice)),
            row('Margin per unit', Formatter.number(margin)),
            row('Stock value (cost)',
                Formatter.number(batch.quantity * batch.buyingPrice)),
          ]),
          card('Movements on this batch (${history.length})', [
            if (history.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child:
                    Text('No movements yet.', style: AppTextStyles.bodySmall),
              )
            else
              ...history.map((m) {
                final color = m.isIn ? AppColors.primaryDeep : AppColors.error;
                return InkWell(
                  onTap: () => showMovementDetails(context, m),
                  child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    children: [
                      Icon(
                        m.isIn
                            ? Icons.south_west_rounded
                            : Icons.north_east_rounded,
                        size: 16,
                        color: color,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m.label,
                              style: AppTextStyles.bodyMedium
                                  .copyWith(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              '${Formatter.dateTime(m.movementDate)}'
                              '  ·  ${m.who}'
                              '${m.reference.isEmpty ? '' : '  ·  ${m.reference}'}'
                              '${m.quantityBefore == null ? '' : '\nBalance ${m.quantityBefore} → ${m.quantityAfter}'}',
                              style: AppTextStyles.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${m.isIn ? '+' : '-'}${m.quantity}',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, color: color),
                      ),
                    ],
                  ),
                  ),
                );
              }),
          ]),
        ],
      ),
    );
  }

  Widget _bigStat(String label, String value, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800, color: color)),
              const SizedBox(height: 2),
              Text(label, style: AppTextStyles.bodySmall),
            ],
          ),
        ),
      );
}
