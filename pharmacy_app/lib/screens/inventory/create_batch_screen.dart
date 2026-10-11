import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/app_colors.dart';
import '../../config/app_text_styles.dart';
import '../../helpers/barcode_parser.dart';
import '../../helpers/formatter.dart';
import '../../models/goods_received.dart';
import '../../models/goods_received_item.dart';
import '../../models/medicine.dart';
import '../../providers/batch_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/purchase_provider.dart';
import '../../providers/stock_movement_provider.dart';
import '../../providers/supplier_provider.dart';
import '../../routes/route_names.dart';
import '../../widgets/medicine_image.dart';

/// Receive stock: one supplier delivery containing one or more medicines.
///
/// Every medicine line becomes its OWN batch (a batch is one lot of one
/// medicine — never a mix), and all lines are saved together, so the batches
/// and their "stock in" movements are created atomically.
class CreateBatchScreen extends StatefulWidget {
  final int? initialMedicineId;
  final String? initialBatchNumber;
  final DateTime? initialExpiry;

  const CreateBatchScreen({
    super.key,
    this.initialMedicineId,
    this.initialBatchNumber,
    this.initialExpiry,
  });

  @override
  State<CreateBatchScreen> createState() => _CreateBatchScreenState();
}

class _Line {
  Medicine? medicine;
  final batchNumber = TextEditingController();
  final quantity = TextEditingController();
  final buying = TextEditingController();
  final selling = TextEditingController();
  DateTime? manufactureDate;
  DateTime? expiryDate;

  void dispose() {
    batchNumber.dispose();
    quantity.dispose();
    buying.dispose();
    selling.dispose();
  }
}

class _CreateBatchScreenState extends State<CreateBatchScreen> {
  final _invoiceController = TextEditingController();
  final _notesController = TextEditingController();
  final List<_Line> _lines = [];

  int? _supplierId;
  bool _isSaving = false;
  String? _error;

  static final DateFormat _iso = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();

    final first = _Line();
    if (widget.initialBatchNumber != null) {
      first.batchNumber.text = widget.initialBatchNumber!;
    }
    first.expiryDate = widget.initialExpiry;
    _lines.add(first);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final inventory = context.read<InventoryProvider>();
      context.read<SupplierProvider>().loadSuppliers();
      context.read<BatchProvider>().loadBatches();

      if (inventory.medicines.isEmpty) {
        await inventory.loadMedicines();
      }

      if (!mounted || widget.initialMedicineId == null) return;

      for (final m in inventory.medicines) {
        if (m.id == widget.initialMedicineId) {
          setState(() => first.medicine = m);
        }
      }
    });
  }

  @override
  void dispose() {
    _invoiceController.dispose();
    _notesController.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  // ---------------------------------------------------------------- pickers

  Future<void> _pickMedicine(_Line line) async {
    final medicines = context.read<InventoryProvider>().medicines;

    final picked = await showModalBottomSheet<Medicine>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        var query = '';

        return StatefulBuilder(
          builder: (context, setSheetState) {
            final q = query.trim().toLowerCase();
            final list = medicines.where((m) {
              if (q.isEmpty) return true;
              return m.name.toLowerCase().contains(q) ||
                  m.genericName.toLowerCase().contains(q) ||
                  m.sku.toLowerCase().contains(q) ||
                  (m.barcode ?? '').toLowerCase().contains(q);
            }).toList();

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: SizedBox(
                height: MediaQuery.of(sheetContext).size.height * 0.75,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              autofocus: true,
                              onChanged: (v) =>
                                  setSheetState(() => query = v),
                              decoration: const InputDecoration(
                                hintText: 'Search name, SKU or barcode',
                                prefixIcon: Icon(Icons.search_rounded),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            tooltip: 'Scan barcode',
                            icon: const Icon(Icons.qr_code_scanner_rounded),
                            onPressed: () async {
                              final code = await sheetContext
                                  .push<String>('${RouteNames.scanner}?pick=1');
                              if (code == null) return;
                              final parsed = BarcodeParser.parse(code);

                              Medicine? hit;
                              for (final m in medicines) {
                                if (BarcodeParser.sameProduct(
                                        m.barcode, parsed.gtin ?? code) ||
                                    m.sku.toLowerCase() ==
                                        code.trim().toLowerCase()) {
                                  hit = m;
                                  break;
                                }
                              }
                              if (hit != null && sheetContext.mounted) {
                                Navigator.pop(sheetContext, hit);
                              } else {
                                setSheetState(() => query = code);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: list.isEmpty
                          ? const Center(child: Text('No medicines found.'))
                          : ListView.builder(
                              itemCount: list.length,
                              itemBuilder: (context, i) {
                                final m = list[i];
                                return ListTile(
                                  leading: MedicineImage(
                                      url: m.imageUrl, size: 40, radius: 10),
                                  title: Text(m.name),
                                  subtitle: Text(
                                    'SKU ${m.sku}${m.barcode != null ? '  ·  ${m.barcode}' : ''}',
                                  ),
                                  trailing: Text('${m.quantity} in stock'),
                                  onTap: () => Navigator.pop(sheetContext, m),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (picked != null) {
      // Same medicine received before? Reuse its latest prices as a start.
      final previous = context
          .read<BatchProvider>()
          .batches
          .where((b) => b.medicineId == picked.id)
          .toList()
        ..sort((a, b) => b.id.compareTo(a.id));

      setState(() {
        line.medicine = picked;
        if (previous.isNotEmpty) {
          if (line.buying.text.isEmpty) {
            line.buying.text = '${previous.first.buyingPrice}';
          }
          if (line.selling.text.isEmpty) {
            line.selling.text = '${previous.first.sellingPrice}';
          }
        }
      });
    }
  }

  Future<void> _pickDate(_Line line, {required bool expiry}) async {
    final now = DateTime.now();
    final current = expiry ? line.expiryDate : line.manufactureDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? (expiry ? now.add(const Duration(days: 365)) : now),
      firstDate: expiry ? DateTime(now.year - 1) : DateTime(now.year - 10),
      lastDate: expiry
          ? DateTime(now.year + 15)
          : now.add(const Duration(days: 1)),
    );

    if (picked == null) return;
    setState(() {
      if (expiry) {
        line.expiryDate = picked;
      } else {
        line.manufactureDate = picked;
      }
    });
  }

  // ------------------------------------------------------------------- save

  String? _validate() {
    if (_supplierId == null) return 'Choose the supplier for this delivery.';

    final batches = context.read<BatchProvider>();
    final seen = <String>{};

    for (var i = 0; i < _lines.length; i++) {
      final l = _lines[i];
      final label = 'Medicine ${i + 1}';

      if (l.medicine == null) return '$label: choose a medicine.';

      final number = l.batchNumber.text.trim();
      if (number.isEmpty) return '$label: enter the batch number.';

      final key = '${l.medicine!.id}|${number.toLowerCase()}';
      if (!seen.add(key)) {
        return '$label: ${l.medicine!.name} batch $number is entered twice.';
      }
      if (batches.findLot(l.medicine!.id, number) != null) {
        return '$label: ${l.medicine!.name} already has a batch $number.';
      }

      if (l.expiryDate == null) return '$label: choose the expiry date.';
      if (l.manufactureDate != null &&
          !l.expiryDate!.isAfter(l.manufactureDate!)) {
        return '$label: expiry must be after the manufacture date.';
      }

      final qty = int.tryParse(l.quantity.text.trim());
      if (qty == null || qty <= 0) {
        return '$label: quantity received must be more than 0.';
      }

      if (double.tryParse(l.buying.text.trim()) == null) {
        return '$label: enter the purchase price.';
      }
      if (double.tryParse(l.selling.text.trim()) == null) {
        return '$label: enter the selling price.';
      }
    }
    return null;
  }

  Future<void> _save() async {
    final problem = _validate();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    final delivery = GoodsReceived(
      id: 0,
      supplier: _supplierId!,
      invoiceNumber: _invoiceController.text.trim(),
      receivedDate: '',
      receivedBy: 0,
      notes: _notesController.text.trim(),
      items: _lines
          .map((l) => GoodsReceivedItem(
                id: 0,
                medicine: l.medicine!.id,
                batchNumber: l.batchNumber.text.trim(),
                manufactureDate:
                    l.manufactureDate == null ? '' : _iso.format(l.manufactureDate!),
                expiryDate: _iso.format(l.expiryDate!),
                quantity: int.parse(l.quantity.text.trim()),
                buyingPrice: double.parse(l.buying.text.trim()),
                sellingPrice: double.parse(l.selling.text.trim()),
              ))
          .toList(),
    );

    final purchases = context.read<PurchaseProvider>();
    final ok = await purchases.createGoodsReceived(delivery);

    if (!mounted) return;

    if (!ok) {
      setState(() {
        _isSaving = false;
        _error = purchases.error ?? 'Could not save these batches.';
      });
      return;
    }

    // Refresh everything the new stock affects.
    await Future.wait([
      context.read<BatchProvider>().loadBatches(),
      context.read<InventoryProvider>().loadMedicines(),
      context.read<StockMovementProvider>().loadMovements(),
    ]);

    if (!mounted) return;

    final n = _lines.length;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(content: Text(n == 1 ? 'Batch created.' : '$n batches created.')),
    );
  }

  // --------------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    final suppliers = context
        .watch<SupplierProvider>()
        .suppliers
        .where((s) => s.isActive)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Create batch')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.errorSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_error!,
                    style: const TextStyle(color: AppColors.error)),
              ),
              const SizedBox(height: 14),
            ],
            Text('Delivery', style: AppTextStyles.headingSmall),
            const SizedBox(height: 10),
            if (suppliers.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warningSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                          'No suppliers yet. Add the supplier first, then come back.'),
                    ),
                    TextButton(
                      onPressed: () => context.push(RouteNames.suppliers),
                      child: const Text('Suppliers'),
                    ),
                  ],
                ),
              )
            else
              DropdownButtonFormField<int>(
                value: _supplierId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Supplier'),
                items: suppliers
                    .map((s) =>
                        DropdownMenuItem(value: s.id, child: Text(s.name)))
                    .toList(),
                onChanged: (v) => setState(() => _supplierId = v),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _invoiceController,
              decoration:
                  const InputDecoration(labelText: 'Invoice number (optional)'),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Text('Medicines in this delivery',
                    style: AppTextStyles.headingSmall),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Each medicine becomes its own batch: one lot of one medicine, with its own '
              'lot number, expiry date, quantity and prices. Saving adds the stock and '
              'records a "stock in" movement under your name.',
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < _lines.length; i++) _buildLine(i),
            OutlinedButton.icon(
              onPressed: () => setState(() => _lines.add(_Line())),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add another medicine'),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
            ),
            const SizedBox(height: 22),
            ElevatedButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(_lines.length == 1
                      ? 'Create batch'
                      : 'Create ${_lines.length} batches'),
            ),
          ],
        ),
      ),
    );
  }

  /// What is already in stock for the chosen medicine, so the person can see
  /// at a glance whether this lot is new and where it will sit in FEFO order
  /// (earliest expiry is dispensed first).
  Widget _existingBatches(Medicine med) {
    final existing = context
        .watch<BatchProvider>()
        .batches
        .where((b) => b.medicineId == med.id && b.quantity > 0)
        .toList()
      ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            existing.isEmpty
                ? 'No stock of this medicine yet — this will be its first batch.'
                : 'Already in stock (${existing.length} batch${existing.length == 1 ? '' : 'es'}, earliest expiry first):',
            style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700),
          ),
          ...existing.take(3).map(
                (b) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${b.batchNumber} · ${b.quantity} left · expires ${Formatter.date(b.expiryDate)}',
                    style: AppTextStyles.bodySmall,
                  ),
                ),
              ),
          if (existing.length > 3)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('+ ${existing.length - 3} more',
                  style: AppTextStyles.bodySmall),
            ),
        ],
      ),
    );
  }

  Widget _buildLine(int index) {
    final line = _lines[index];
    final med = line.medicine;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Medicine ${index + 1}',
                  style: AppTextStyles.label),
              const Spacer(),
              if (_lines.length > 1)
                IconButton(
                  tooltip: 'Remove',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() {
                    _lines.removeAt(index).dispose();
                  }),
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: AppColors.error),
                ),
            ],
          ),
          InkWell(
            onTap: () => _pickMedicine(line),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  MedicineImage(url: med?.imageUrl, size: 38, radius: 10),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      med == null ? 'Choose medicine' : med.name,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: med == null ? AppColors.textSecondary : null,
                      ),
                    ),
                  ),
                  Icon(Icons.unfold_more_rounded,
                      color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
          if (med != null) _existingBatches(med),
          const SizedBox(height: 12),
          TextField(
            controller: line.batchNumber,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Batch number'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _dateField(
                  'Manufactured (optional)',
                  line.manufactureDate,
                  () => _pickDate(line, expiry: false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _dateField(
                  'Expiry date',
                  line.expiryDate,
                  () => _pickDate(line, expiry: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: line.quantity,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Quantity received'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: line.buying,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration:
                      const InputDecoration(labelText: 'Purchase price'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: line.selling,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration:
                      const InputDecoration(labelText: 'Selling price'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dateField(String label, DateTime? value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(
          value == null ? 'Select' : Formatter.date(_iso.format(value)),
          style: TextStyle(
            color: value == null ? AppColors.textSecondary : null,
          ),
        ),
      ),
    );
  }
}
