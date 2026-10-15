import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/app_colors.dart';
import '../../config/app_text_styles.dart';
import '../../helpers/formatter.dart';
import '../../models/batch.dart';
import '../../widgets/medicine_image.dart';
import '../../models/medicine.dart';
import '../../providers/batch_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/stock_movement_provider.dart';
import '../../routes/route_names.dart';
import '../../widgets/movement_details.dart';

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
                decoration: BoxDecoration(
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
                decoration: BoxDecoration(
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

  void _openPhoto(Medicine medicine) {
    final url = medicine.imageUrl;
    if (url == null || url.isEmpty) return;

    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            InteractiveViewer(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Padding(
                  padding: EdgeInsets.all(40),
                  child: Icon(Icons.broken_image_outlined,
                      color: Colors.white, size: 48),
                ),
              ),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<InventoryProvider>(
      builder: (context, provider, child) {
        Medicine? found;
        for (final item in provider.medicines) {
          if (item.id == widget.medicineId) {
            found = item;
            break;
          }
        }

        if (found == null) {
          return const Scaffold(
            body: Center(child: Text('Medicine not found.')),
          );
        }
        final Medicine medicine = found;

        final categoryName =
            context.watch<CategoryProvider>().nameFor(medicine.categoryId);
        final movements =
            context.watch<StockMovementProvider>().forMedicine(medicine.id);
        final batches = context.watch<BatchProvider>().forMedicine(medicine.id);

        final isOut = medicine.quantity <= 0;
        final isLow = !isOut && medicine.quantity <= medicine.reorderLevel;
        final warn = isOut || isLow;

        const onGreen = Color(0xFF06170C);
        final fg = warn ? Colors.white : onGreen;

        // ---- facts worked out from the batches ----
        final live = batches.where((b) => b.quantity > 0).toList();
        final expiredLive = live.where((b) => b.isExpired).toList();
        final usable = live.where((b) => !b.isExpired).toList()
          ..sort((a, b) => (a.daysToExpiry ?? 99999)
              .compareTo(b.daysToExpiry ?? 99999));
        final nearest = usable.isNotEmpty ? usable.first : null;
        final stockValue = live.fold<double>(
            0, (sum, b) => sum + b.quantity * b.buyingPrice);
        final retailValue = live.fold<double>(
            0, (sum, b) => sum + b.quantity * b.sellingPrice);

        final topPad = MediaQuery.of(context).padding.top;

        String money(double v) => 'KES ${Formatter.number(v.round())}';

        final (statusText, statusBg, statusFg) = isOut
            ? ('Out of stock', AppColors.error, Colors.white)
            : isLow
                ? ('Low', AppColors.error, Colors.white)
                : ('In stock', Colors.black.withValues(alpha: 0.14), fg);

        return Scaffold(
          backgroundColor: AppColors.background,
          body: ListView(
            padding: EdgeInsets.zero,
            children: [
              // ============================================ hero
              Container(
                padding: EdgeInsets.fromLTRB(16, topPad + 8, 16, 20),
                decoration: BoxDecoration(
                  color: warn ? AppColors.dark : AppColors.primary,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(32),
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
                          dark: warn,
                          onTap: () => Navigator.of(context).maybePop(),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              color: statusFg,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // ---- the big photo ----
                    GestureDetector(
                      onTap: () => _openPhoto(medicine),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(26),
                        child: Container(
                          width: double.infinity,
                          height: 240,
                          color: Colors.white.withValues(alpha: 0.9),
                          alignment: Alignment.center,
                          child: (medicine.imageUrl == null ||
                                  medicine.imageUrl!.isEmpty)
                              ? const DefaultMedicineArt(size: 150)
                              : Image.network(
                                  medicine.imageUrl!,
                                  width: double.infinity,
                                  height: 240,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (c, child, progress) =>
                                      progress == null
                                          ? child
                                          : const DefaultMedicineArt(size: 150),
                                  errorBuilder: (c, e, st) =>
                                      const DefaultMedicineArt(size: 150),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text.rich(
                          TextSpan(
                            text: Formatter.number(medicine.quantity),
                            style: TextStyle(
                              fontSize: 46,
                              fontWeight: FontWeight.w800,
                              height: 1,
                              color: fg,
                            ),
                            children: [
                              TextSpan(
                                text: ' units',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: fg.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                medicine.name,
                                textAlign: TextAlign.right,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  color: fg,
                                ),
                              ),
                              Text(
                                categoryName,
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: fg.withValues(alpha: 0.75),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.dark,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Text(
                            'SKU',
                            style: TextStyle(
                              color: AppColors.onDarkMuted,
                              fontWeight: FontWeight.w700,
                              fontSize: 11.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              medicine.sku,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              medicine.units,
                              style: const TextStyle(
                                color: onGreen,
                                fontWeight: FontWeight.w800,
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 110),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ======================================= actions
                    Row(
                      children: [
                        Expanded(
                          child: _BigAction(
                            label: 'Stock in',
                            hint: 'Add on restock',
                            icon: Icons.add_rounded,
                            bg: AppColors.primary,
                            fg: onGreen,
                            iconBg: Colors.black.withValues(alpha: 0.14),
                            iconColor: onGreen,
                            onTap: () => _openStockSheet(medicine, isIn: true),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _BigAction(
                            label: 'Stock out',
                            hint: 'Dispense / usage',
                            icon: Icons.remove_rounded,
                            bg: AppColors.dark,
                            fg: Colors.white,
                            iconBg: AppColors.error,
                            iconColor: Colors.white,
                            onTap: () => _openStockSheet(medicine, isIn: false),
                          ),
                        ),
                      ],
                    ),

                    // ================================ warnings
                    if (expiredLive.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _Notice(
                        color: AppColors.error,
                        bg: AppColors.errorSoft,
                        icon: Icons.event_busy_rounded,
                        text:
                            '${expiredLive.length} expired batch${expiredLive.length == 1 ? '' : 'es'} '
                            'still hold ${expiredLive.fold<int>(0, (s, b) => s + b.quantity)} units. '
                            'They cannot be dispensed - write them off.',
                      ),
                    ],
                    if (isOut || isLow) ...[
                      const SizedBox(height: 10),
                      _Notice(
                        color: AppColors.error,
                        bg: AppColors.errorSoft,
                        icon: Icons.warning_amber_rounded,
                        text: isOut
                            ? 'Out of stock. Reorder level is ${medicine.reorderLevel}.'
                            : 'Only ${medicine.quantity} left - reorder at ${medicine.reorderLevel}.',
                      ),
                    ],

                    // ================================ details
                    const SizedBox(height: 22),
                    Text('Details', style: AppTextStyles.headingSmall),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Wrap(
                        runSpacing: 16,
                        children: [
                          _Fact('Generic name',
                              medicine.genericName.isEmpty ? '-' : medicine.genericName),
                          _Fact('Category', categoryName),
                          _Fact('SKU', medicine.sku),
                          _Fact('Barcode',
                              (medicine.barcode == null || medicine.barcode!.isEmpty)
                                  ? 'Not set'
                                  : medicine.barcode!),
                          _Fact('Unit / pack', medicine.units),
                          _Fact('Reorder level', '${medicine.reorderLevel} units'),
                          _Fact('Expiry warning',
                              '${medicine.expiryAlertDays} days before'),
                          _Fact('Batches in stock', '${live.length}'),
                          _Fact(
                            'Nearest expiry',
                            nearest == null
                                ? '-'
                                : '${Formatter.date(nearest.expiryDate)}'
                                    '${nearest.daysToExpiry == null ? '' : ' (${nearest.daysToExpiry}d)'}',
                          ),
                          _Fact('Stock value (cost)',
                              live.isEmpty ? '-' : money(stockValue)),
                          if (retailValue > 0)
                            _Fact('Stock value (retail)', money(retailValue)),
                        ],
                      ),
                    ),

                    if (medicine.description.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      Text('Description', style: AppTextStyles.headingSmall),
                      const SizedBox(height: 6),
                      Text(medicine.description,
                          style: AppTextStyles.bodyMedium),
                    ],

                    // ================================ batches
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: Text('Batches (${batches.length})',
                              style: AppTextStyles.headingSmall),
                        ),
                        TextButton.icon(
                          onPressed: () => _openAddBatchSheet(medicine),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Add batch'),
                        ),
                      ],
                    ),
                    if (batches.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'No batches yet. Add one to start recording stock.',
                          style: AppTextStyles.bodyMedium,
                        ),
                      )
                    else
                      ...batches.map((b) => _BatchTile(batch: b)),

                    // ================================ movements
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: Text('Movement history',
                              style: AppTextStyles.headingSmall),
                        ),
                        if (movements.length > 8)
                          TextButton(
                            onPressed: () =>
                                context.push(RouteNames.movementHistory),
                            child: const Text('See all'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (movements.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'No movements recorded for this medicine yet.',
                          style: AppTextStyles.bodyMedium,
                        ),
                      )
                    else
                      ...movements.take(8).map((m) {
                        final isIn = m.isIn;
                        final color =
                            isIn ? AppColors.primaryDeep : AppColors.error;

                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => showMovementDetails(context, m),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: AppColors.border),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
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
                                    size: 16,
                                    color: color,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${isIn ? '+' : '-'}${m.quantity} ${m.label.toLowerCase()}',
                                        style: AppTextStyles.bodyMedium
                                            .copyWith(
                                                fontWeight: FontWeight.w800),
                                      ),
                                      Text(
                                        '${m.who}'
                                        '${m.batchNumber.isEmpty ? '' : ' · ${m.batchNumber}'}'
                                        ' · ${Formatter.timeAgo(m.movementDate.isNotEmpty ? m.movementDate : m.date)}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTextStyles.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  isIn ? 'IN' : 'OUT',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                    color: color,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ],
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
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.14),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 19,
          color: dark ? Colors.white : const Color(0xFF06170C),
        ),
      ),
    );
  }
}

class _BigAction extends StatelessWidget {
  final String label;
  final String hint;
  final IconData icon;
  final Color bg;
  final Color fg;
  final Color iconBg;
  final Color iconColor;
  final VoidCallback onTap;

  const _BigAction({
    required this.label,
    required this.hint,
    required this.icon,
    required this.bg,
    required this.fg,
    required this.iconBg,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(height: 16),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 17,
                color: fg,
              ),
            ),
            Text(
              hint,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 11.5,
                color: fg.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  final Color color;
  final Color bg;
  final IconData icon;
  final String text;

  const _Notice({
    required this.color,
    required this.bg,
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodySmall
                  .copyWith(color: color, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// Label over value, two to a row.
class _Fact extends StatelessWidget {
  final String label;
  final String value;

  const _Fact(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: 0.5,
      child: Padding(
        padding: const EdgeInsets.only(right: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTextStyles.bodySmall),
            const SizedBox(height: 2),
            Text(
              value,
              style: AppTextStyles.bodyMedium
                  .copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _BatchTile extends StatelessWidget {
  final Batch batch;

  const _BatchTile({required this.batch});

  @override
  Widget build(BuildContext context) {
    final days = batch.daysToExpiry;

    final (label, bg, fg) = batch.isExpired
        ? ('Expired', AppColors.errorSoft, AppColors.error)
        : batch.isDepleted
            ? ('Used up', AppColors.background, AppColors.textSecondary)
            : batch.isExpiringSoon
                ? ('Expiring', AppColors.warningSoft, AppColors.warning)
                : ('Active', AppColors.successSoft, AppColors.primaryDeep);

    final facts = <String>[
      'Exp ${Formatter.date(batch.expiryDate)}'
          '${(days == null || batch.isDepleted) ? '' : (days < 0 ? ' (${-days}d ago)' : ' (in ${days}d)')}',
      if (batch.supplierName.isNotEmpty) batch.supplierName,
      if (batch.buyingPrice > 0)
        'Cost ${Formatter.number(batch.buyingPrice.round())}',
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Batch ${batch.batchNumber}',
                  style: AppTextStyles.bodyMedium
                      .copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(facts.join(' · '), style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                batch.originalQuantity > 0
                    ? '${batch.quantity} / ${batch.originalQuantity}'
                    : '${batch.quantity}',
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
