import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../config/app_colors.dart';
import '../../config/app_text_styles.dart';
import '../../helpers/barcode_parser.dart';
import '../../helpers/formatter.dart';
import '../../models/batch.dart';
import '../../models/medicine.dart';
import '../../providers/batch_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../routes/route_names.dart';

/// Add-medicine flow. A medicine's "quantity" on this backend is always
/// the sum of its batches' quantities (there's no separate stock number
/// on the medicine itself), so creating a medicine here also creates its
/// first batch in the same step — that's what makes the initial "number
/// in stock" field meaningful, and keeps the "every medicine has at
/// least one batch" rule true from the moment it's created.
class AddMedicineScreen extends StatefulWidget {
  /// Pre-fills the barcode field (e.g. when arriving from a scan that
  /// matched no medicine).
  final String? initialBarcode;

  const AddMedicineScreen({super.key, this.initialBarcode});

  @override
  State<AddMedicineScreen> createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends State<AddMedicineScreen> {
  final _formKey = GlobalKey<FormState>();

  // Medicine fields
  final _nameController = TextEditingController();
  final _genericNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _skuController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _unitsController = TextEditingController(text: 'Box');
  final _reorderController = TextEditingController(text: '20');

  // First batch fields — this is where "number in stock" actually lives.
  final _batchNumberController = TextEditingController();
  final _quantityController = TextEditingController(text: '0');
  final _buyingPriceController = TextEditingController(text: '0');
  DateTime _expiryDate = DateTime.now().add(const Duration(days: 365));

  int? _categoryId;
  bool _isSaving = false;
  String? _error;
  XFile? _pickedImage;

  @override
  void initState() {
    super.initState();

    if (widget.initialBarcode != null) {
      _barcodeController.text = widget.initialBarcode!;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CategoryProvider>().loadCategories();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _genericNameController.dispose();
    _descriptionController.dispose();
    _skuController.dispose();
    _barcodeController.dispose();
    _unitsController.dispose();
    _reorderController.dispose();
    _batchNumberController.dispose();
    _quantityController.dispose();
    _buyingPriceController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await showModalBottomSheet<XFile?>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () async {
                final file = await ImagePicker()
                    .pickImage(source: ImageSource.camera, imageQuality: 80);
                if (sheetContext.mounted) Navigator.pop(sheetContext, file);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () async {
                final file = await ImagePicker()
                    .pickImage(source: ImageSource.gallery, imageQuality: 80);
                if (sheetContext.mounted) Navigator.pop(sheetContext, file);
              },
            ),
          ],
        ),
      ),
    );

    if (picked != null) {
      setState(() => _pickedImage = picked);
    }
  }

  Future<void> _quickAddCategory() async {
    final controller = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('New category'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. Analgesics'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty || !mounted) return;

    final created =
        await context.read<CategoryProvider>().createCategory(name: name);

    if (!mounted) return;

    if (created != null) {
      setState(() => _categoryId = created.id);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not create that category.')),
      );
    }
  }

  Future<void> _pickExpiryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );

    if (picked != null) {
      setState(() => _expiryDate = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_categoryId == null) {
      setState(() => _error = 'Choose or add a category first.');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    final medicine = Medicine(
      id: 0,
      name: _nameController.text.trim(),
      genericName: _genericNameController.text.trim(),
      description: _descriptionController.text.trim(),
      quantity: 0,
      categoryId: _categoryId!,
      sku: _skuController.text.trim(),
      barcode: _barcodeController.text.trim().isEmpty
          ? null
          : _barcodeController.text.trim(),
      units: _unitsController.text.trim(),
      reorderLevel: int.tryParse(_reorderController.text.trim()) ?? 0,
    );

    final createdMedicine = await context.read<InventoryProvider>().createMedicine(
          medicine,
          imagePath: _pickedImage?.path,
        );

    if (!mounted) return;

    if (createdMedicine == null) {
      setState(() {
        _isSaving = false;
        _error = context.read<InventoryProvider>().error ??
            'Could not save this medicine.';
      });
      return;
    }

    // Opening stock is optional. Without a batch number the medicine is
    // simply registered; stock is added later via Create batch.
    if (_batchNumberController.text.trim().isEmpty) {
      setState(() => _isSaving = false);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${createdMedicine.name} registered. Add stock from Batches > Create batch.',
          ),
        ),
      );
      return;
    }

    // Medicine saved — now create its opening batch, which is what actually
    // gives it the "number in stock" the person entered.
    final now = DateTime.now();

    final createdBatch = await context.read<BatchProvider>().createBatch(
          Batch(
            id: 0,
            medicineId: createdMedicine.id,
            batchNumber: _batchNumberController.text.trim(),
            manufactureDate: now.toIso8601String().split('T').first,
            expiryDate: _expiryDate.toIso8601String().split('T').first,
            quantity: int.tryParse(_quantityController.text.trim()) ?? 0,
            buyingPrice:
                double.tryParse(_buyingPriceController.text.trim()) ?? 0,
            receivedDate: now.toIso8601String().split('T').first,
          ),
        );

    if (!mounted) return;

    setState(() => _isSaving = false);

    if (createdBatch != null) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${createdMedicine.name} added with ${createdBatch.quantity} units in stock.',
          ),
        ),
      );
    } else {
      // The medicine itself was saved fine — only the batch failed. Don't
      // lose that progress; let them retry the batch from the detail page.
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${createdMedicine.name} was saved, but the first batch '
            'failed — add it from the medicine\'s page.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<CategoryProvider>().categories;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Add medicine')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: [
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.errorSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(_error!, style: const TextStyle(color: AppColors.error)),
                ),
                const SizedBox(height: 14),
              ],
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 96,
                    height: 96,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: AppColors.successSoft,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: _pickedImage != null
                        ? Image.file(File(_pickedImage!.path), fit: BoxFit.cover)
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo_outlined,
                                  color: AppColors.primaryDeep),
                              SizedBox(height: 6),
                              Text('Photo',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primaryDeep)),
                            ],
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text('Medicine', style: AppTextStyles.headingSmall),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _genericNameController,
                decoration: const InputDecoration(labelText: 'Generic name'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _skuController,
                decoration:
                    const InputDecoration(labelText: 'SKU (your internal code)'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _barcodeController,
                decoration: InputDecoration(
                  labelText: 'Manufacturer barcode / GTIN (optional)',
                  suffixIcon: IconButton(
                    tooltip: 'Scan barcode',
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    onPressed: () async {
                      final code = await context
                          .push<String>('${RouteNames.scanner}?pick=1');
                      if (code != null && mounted) {
                        setState(() => _barcodeController.text =
                            BarcodeParser.parse(code).gtin ?? code);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _unitsController,
                      decoration: const InputDecoration(labelText: 'Units'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _reorderController,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Reorder at'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text('Category', style: AppTextStyles.label),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _categoryId,
                      hint: const Text('Choose a category'),
                      items: categories
                          .map((c) => DropdownMenuItem(
                                value: c.id,
                                child: Text(c.name),
                              ))
                          .toList(),
                      onChanged: (value) => setState(() => _categoryId = value),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: _quickAddCategory,
                    icon: const Icon(Icons.add_rounded),
                    tooltip: 'New category',
                  ),
                ],
              ),

              const SizedBox(height: 28),
              Container(height: 1, color: AppColors.border),
              const SizedBox(height: 20),
              Text('Opening stock (optional)', style: AppTextStyles.headingSmall),
              const SizedBox(height: 4),
              Text(
                'Leave the batch number empty to register the medicine '
                'without stock. You can receive stock later from '
                'Batches > Create batch.',
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _batchNumberController,
                decoration: const InputDecoration(labelText: 'Batch number'),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _quantityController,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Number in stock'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _buyingPriceController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration:
                          const InputDecoration(labelText: 'Buying price'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              InkWell(
                onTap: _pickExpiryDate,
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Expiry date'),
                  child: Text(Formatter.date(_expiryDate.toIso8601String())),
                ),
              ),

              const SizedBox(height: 26),
              ElevatedButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save medicine'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
