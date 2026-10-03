import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/app_colors.dart';
import '../../config/app_text_styles.dart';
import '../../providers/category_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../routes/route_names.dart';
import '../../widgets/error_widget.dart';
import '../../widgets/loading_widget.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  String _searchQuery = '';
  int? _selectedCategoryId; // null == "All"

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InventoryProvider>().loadMedicines();
      context.read<CategoryProvider>().loadCategories();
    });
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<CategoryProvider>().categories;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 74),
        child: FloatingActionButton.extended(
          onPressed: () => context.push(RouteNames.addMedicine),
          backgroundColor: AppColors.dark,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: const Text(
            'Add medicine',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
        ),
      ),
      body: SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Row(
              children: [
                Text('Inventory', style: AppTextStyles.headingLarge),
                const Spacer(),
                IconButton(
                  onPressed: () => context.push(RouteNames.batches),
                  icon: const Icon(Icons.inventory_outlined),
                  tooltip: 'Batches',
                ),
                Consumer<InventoryProvider>(
                  builder: (context, provider, _) => Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.dark,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      '${provider.medicines.length} SKUs',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Search name or SKU...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              children: [
                _CategoryPill(
                  label: 'All',
                  active: _selectedCategoryId == null,
                  onTap: () => setState(() => _selectedCategoryId = null),
                ),
                ...categories.map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: _CategoryPill(
                      label: c.name,
                      active: _selectedCategoryId == c.id,
                      onTap: () => setState(() => _selectedCategoryId = c.id),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Consumer<InventoryProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading && provider.medicines.isEmpty) {
                  return const LoadingWidget();
                }

                if (provider.error != null && provider.medicines.isEmpty) {
                  return AppErrorWidget(
                    message: provider.error!,
                    onRetry: provider.loadMedicines,
                  );
                }

                final query = _searchQuery.toLowerCase();

                final medicines = provider.medicines.where((medicine) {
                  final matchesQuery = query.isEmpty ||
                      medicine.name.toLowerCase().contains(query) ||
                      medicine.genericName.toLowerCase().contains(query) ||
                      medicine.sku.toLowerCase().contains(query);

                  final matchesCategory = _selectedCategoryId == null ||
                      medicine.categoryId == _selectedCategoryId;

                  return matchesQuery && matchesCategory;
                }).toList();

                return RefreshIndicator(
                  onRefresh: provider.refresh,
                  child: medicines.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 100),
                            Center(child: Text('No medicines found.')),
                          ],
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
                          itemCount: medicines.length,
                          itemBuilder: (context, index) {
                            final medicine = medicines[index];
                            final isOut = medicine.quantity <= 0;
                            final isLow = !isOut &&
                                medicine.quantity <= medicine.reorderLevel;

                            return _MedicineRow(
                              name: medicine.name,
                              sku: medicine.sku,
                              quantity: medicine.quantity,
                              isLow: isLow,
                              isOut: isOut,
                              imageUrl: medicine.imageUrl,
                              onTap: () => context.push(
                                RouteNames.medicineDetail(medicine.id),
                              ),
                            );
                          },
                        ),
                );
              },
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _CategoryPill({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.dark : AppColors.surface,
          border: Border.all(
            color: active ? AppColors.dark : AppColors.border,
          ),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 12.5,
            color: active ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _MedicineRow extends StatelessWidget {
  final String name;
  final String sku;
  final int quantity;
  final bool isLow;
  final bool isOut;
  final String? imageUrl;
  final VoidCallback onTap;

  const _MedicineRow({
    required this.name,
    required this.sku,
    required this.quantity,
    required this.isLow,
    required this.isOut,
    required this.onTap,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final flagged = isLow || isOut;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: flagged ? AppColors.errorSoft : AppColors.surface,
          border: Border.all(
            color: flagged ? const Color(0xFFF6D0D0) : AppColors.border,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: flagged
                    ? const Color(0xFFFBD9D9)
                    : AppColors.successSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: imageUrl != null && imageUrl!.isNotEmpty
                  ? Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) => Icon(
                        Icons.medication_rounded,
                        size: 18,
                        color: flagged ? AppColors.error : AppColors.primaryDeep,
                      ),
                    )
                  : Icon(
                      Icons.medication_rounded,
                      size: 18,
                      color: flagged ? AppColors.error : AppColors.primaryDeep,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: AppTextStyles.bodyMedium
                          .copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(sku,
                      style: AppTextStyles.bodySmall,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('$quantity',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 3),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isOut
                        ? const Color(0xFFFBD9D9)
                        : isLow
                            ? AppColors.warningSoft
                            : AppColors.successSoft,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    isOut ? 'Out' : isLow ? 'Low' : 'In stock',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: isOut
                          ? AppColors.error
                          : isLow
                              ? AppColors.warning
                              : AppColors.primaryDeep,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
