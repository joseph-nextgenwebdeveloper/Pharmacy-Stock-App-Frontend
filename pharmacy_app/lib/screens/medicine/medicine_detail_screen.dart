import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_colors.dart';
import '../../config/app_text_styles.dart';
import '../../helpers/formatter.dart';
import '../../models/batch.dart';
import '../../models/medicine.dart';
import '../../providers/batch_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/stock_movement_provider.dart';

class MedicineDetailScreen extends StatefulWidget {
  final int medicineId;

  const MedicineDetailScreen({
    super.key,
    required this.medicineId,
  });

  @override
  State<MedicineDetailScreen> createState() => _MedicineDetailScreenState();
}

class _MedicineDetailScreenState extends State<MedicineDetailScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BatchProvider>().loadBatches();
      context.read<StockMovementProvider>().loadMovements();
    });
  }

  Future<void> _openStockSheet(Medicine medicine, {required bool isIn}) async {
    final batches = context.read<BatchProvider>().forMedicine(medicine.id);
    final controller = TextEditingController(text: '1');
    int? selectedBatchId = batches.isNotEmpty ? batches.first.id : null;
    String note = '';

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(22, 10, 22, 26),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    Text(
                      isIn ? 'Stock in' : 'Stock out',
                      style: AppTextStyles.headingSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${medicine.name} · ${medicine.sku}',
                      style: AppTextStyles.bodySmall,
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 28, fontWeight: FontWeight.w800),
                      decoration: const InputDecoration(labelText: 'Quantity'),
                    ),
                    const SizedBox(height: 14),
                    if (batches.isNotEmpty)
                      DropdownButtonFormField<int>(
                        value: selectedBatchId,
                        decoration: const InputDecoration(labelText: 'Batch'),
                        items: batches
                            .map((b) => DropdownMenuItem(
                                  value: b.id,
                                  child: Text(
                                    '${b.batchNumber} · exp ${Formatter.date(b.expiryDate)}',
                                  ),
                                ))
                            .toList(),
                        onChanged: (value) =>
                            setSheetState(() => selectedBatchId = value),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.warningSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'This medicine has no batches yet. Add a batch '
                          'first (below), then come back to record stock '
                          'movements against it.',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.warning),
                        ),
                      ),
                    const SizedBox(height: 14),
                    TextField(
                      onChanged: (value) => note = value,
                      decoration: InputDecoration(
                        labelText: isIn
                            ? 'Reason (delivery, correction...)'
                            : 'Reason (dispensed, damaged...)',
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: selectedBatchId == null
                                ? null
                                : () async {
                              final qty = int.tryParse(controller.text) ?? 0;
                              if (qty <= 0) return;

                              final ok = await context
                                  .read<StockMovementProvider>()
                                  .recordMovement(
                                    medicineId: medicine.id,
                                    batchId: selectedBatchId,
                                    quantity: qty,
                                    movementType: isIn ? 'IN' : 'OUT',
                                    note: note,
                                  );

                              if (!mounted) return;
                              Navigator.pop(sheetContext);

                              if (ok) {
                                context.read<InventoryProvider>().refresh();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      isIn
                                          ? 'Stock in recorded.'
                                          : 'Stock out recorded.',
                                    ),
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Could not save this movement. Try again.',
                                    ),
                                  ),
                                );
                              }
                            },
                            child: const Text('Save'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openAddBatchSheet(Medicine medicine) async {
    final batchNumberController = TextEditingController();
    final quantityController = TextEditingController(text: '1');
    final buyingPriceController = TextEditingController(text: '0');
    DateTime expiryDate = DateTime.now().add(const Duration(days: 365));

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(22, 10, 22, 26),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    Text('Add batch', style: AppTextStyles.headingSmall),
                    const SizedBox(height: 4),
                    Text('${medicine.name} · ${medicine.sku}',
                        style: AppTextStyles.bodySmall),
                    const SizedBox(height: 18),
                    TextField(
                      controller: batchNumberController,
                      decoration: const InputDecoration(labelText: 'Batch number'),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: quantityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Quantity'),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: buyingPriceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Buying price'),
                    ),
                    const SizedBox(height: 14),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: expiryDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 3650)),
                        );
                        if (picked != null) {
                          setSheetState(() => expiryDate = picked);
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Expiry date'),
                        child: Text(Formatter.date(expiryDate.toIso8601String())),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              final qty = int.tryParse(quantityController.text) ?? 0;
                              final price =
                                  double.tryParse(buyingPriceController.text) ?? 0;

                              if (batchNumberController.text.trim().isEmpty ||
                                  qty <= 0) {
                                return;
                              }

                              final now = DateTime.now();

                              final created = await context.read<BatchProvider>().createBatch(
                                    Batch(
                                      id: 0,
                                      medicineId: medicine.id,
                                      batchNumber: batchNumberController.text.trim(),
                                      manufactureDate: now.toIso8601String().split('T').first,
                                      expiryDate: expiryDate.toIso8601String().split('T').first,
                                      quantity: qty,
                                      buyingPrice: price,
                                      receivedDate: now.toIso8601String().split('T').first,
                                    ),
                                  );

                              if (!mounted) return;
                              Navigator.pop(sheetContext);

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    created != null
                                        ? 'Batch added.'
                                        : 'Could not save this batch.',
                                  ),
                                ),
                              );
                            },
                            child: const Text('Save'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<InventoryProvider>(
      builder: (context, provider, child) {
        Medicine? medicine;

        for (final item in provider.medicines) {
          if (item.id == widget.medicineId) {
            medicine = item;
            break;
          }
        }

        if (medicine == null) {
          return const Scaffold(
            body: Center(child: Text('Medicine not found.')),
          );
        }

        final categoryName =
            context.watch<CategoryProvider>().nameFor(medicine.categoryId);
        final movements =
            context.watch<StockMovementProvider>().forMedicine(medicine.id);
        final isOut = medicine.quantity <= 0;
        final isLow = !isOut && medicine.quantity <= medicine.reorderLevel;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 22),
                  decoration: BoxDecoration(
                    color: isOut || isLow
                        ? AppColors.dark
                        : AppColors.primary,
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(30),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _CircleIconButton(
                            icon: Icons.arrow_back_rounded,
                            dark: isOut || isLow,
                            onTap: () => Navigator.of(context).maybePop(),
                          ),
                          if (medicine.imageUrl != null &&
                              medicine.imageUrl!.isNotEmpty)
                            Container(
                              width: 44,
                              height: 44,
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Image.network(
                                medicine.imageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stack) =>
                                    const SizedBox.shrink(),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        '${medicine.quantity}',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          color: isOut || isLow
                              ? Colors.white
                              : const Color(0xFF06170C),
                        ),
                      ),
                      Text(
                        medicine.name,
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: isOut || isLow
                              ? Colors.white
                              : const Color(0xFF06170C),
                        ),
                      ),
                      Text(
                        '${medicine.units} · $categoryName',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                          color: (isOut || isLow
                                  ? Colors.white
                                  : const Color(0xFF06170C))
                              .withValues(alpha: 0.75),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'SKU  ${medicine.sku}',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 12.5,
                                color: isOut || isLow
                                    ? Colors.white
                                    : const Color(0xFF06170C),
                              ),
                            ),
                            Text(
                              'Reorder at ${medicine.reorderLevel}',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 11.5,
                                color: (isOut || isLow
                                        ? Colors.white
                                        : const Color(0xFF06170C))
                                    .withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 110),
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _ActionButton(
                              label: 'Stock in',
                              icon: Icons.add_rounded,
                              color: AppColors.primaryDeep,
                              bg: AppColors.successSoft,
                              onTap: () =>
                                  _openStockSheet(medicine!, isIn: true),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ActionButton(
                              label: 'Stock out',
                              icon: Icons.remove_rounded,
                              color: AppColors.error,
                              bg: AppColors.errorSoft,
                              onTap: () =>
                                  _openStockSheet(medicine!, isIn: false),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () => _openAddBatchSheet(medicine!),
                        icon: const Icon(Icons.inventory_outlined, size: 18),
                        label: const Text('Add batch'),
                      ),
                      const SizedBox(height: 22),
                      Text('Movement history', style: AppTextStyles.headingSmall),
                      const SizedBox(height: 8),
                      if (movements.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            'No movements recorded for this medicine yet.',
                            style: AppTextStyles.bodyMedium,
                          ),
                        )
                      else
                        ...movements.map((m) {
                          final isIn = m.movementType.toUpperCase() == 'IN';

                          return Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: AppColors.border),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: isIn
                                        ? AppColors.successSoft
                                        : AppColors.errorSoft,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isIn
                                        ? Icons.arrow_upward_rounded
                                        : Icons.arrow_downward_rounded,
                                    size: 15,
                                    color: isIn
                                        ? AppColors.primaryDeep
                                        : AppColors.error,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${isIn ? '+' : '-'}${m.quantity} '
                                        '${isIn ? 'restock' : 'dispensed'}',
                                        style: AppTextStyles.bodyMedium
                                            .copyWith(
                                                fontWeight: FontWeight.w800),
                                      ),
                                      Text(
                                        Formatter.timeAgo(
                                          m.movementDate.isNotEmpty
                                              ? m.movementDate
                                              : m.date,
                                        ),
                                        style: AppTextStyles.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      if (medicine.description.isNotEmpty) ...[
                        const SizedBox(height: 22),
                        Text('Description', style: AppTextStyles.headingSmall),
                        const SizedBox(height: 6),
                        Text(medicine.description, style: AppTextStyles.bodyMedium),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final bool dark;
  final VoidCallback onTap;

  const _CircleIconButton({
    required this.icon,
    required this.dark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 18,
          color: dark ? Colors.white : const Color(0xFF06170C),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color bg;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.bg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w800, color: color, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
