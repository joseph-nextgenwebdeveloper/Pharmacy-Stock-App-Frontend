import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/app_colors.dart';
import '../../config/app_text_styles.dart';
import '../../helpers/formatter.dart';
import '../../models/batch.dart';
import '../../providers/batch_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../routes/route_names.dart';
import '../../widgets/error_widget.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/medicine_image.dart';

/// Every real stock batch in the system — one row per received lot, each
/// belonging to exactly one medicine. Search, filter by status, open one for
/// full detail, or create a new batch.
class BatchesScreen extends StatefulWidget {
  const BatchesScreen({super.key});

  @override
  State<BatchesScreen> createState() => _BatchesScreenState();
}

class _BatchesScreenState extends State<BatchesScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  String _filter = 'ALL'; // ALL / ACTIVE / EXPIRING / EXPIRED / DEPLETED

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BatchProvider>().loadBatches();
      context.read<InventoryProvider>().loadMedicines();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesFilter(Batch b) {
    switch (_filter) {
      case 'ACTIVE':
        return b.isActive;
      case 'EXPIRING':
        return b.isExpiringSoon;
      case 'EXPIRED':
        return b.isExpired;
      case 'DEPLETED':
        return b.isDepleted;
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Batches'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => context.read<BatchProvider>().refresh(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 74),
        child: FloatingActionButton.extended(
          onPressed: () async {
            await context.push(RouteNames.createBatch);
            if (mounted) context.read<BatchProvider>().loadBatches();
          },
          backgroundColor: AppColors.dark,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: const Text(
            'Create batch',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
        ),
      ),
      body: Consumer2<BatchProvider, InventoryProvider>(
        builder: (context, batchProvider, inventoryProvider, child) {
          if (batchProvider.isLoading && batchProvider.batches.isEmpty) {
            return const LoadingWidget();
          }

          if (batchProvider.error != null && batchProvider.batches.isEmpty) {
            return AppErrorWidget(
              message: batchProvider.error!,
              onRetry: batchProvider.loadBatches,
            );
          }

          final all = batchProvider.batches;
          final q = _query.trim().toLowerCase();

          String nameOf(Batch b) {
            if (b.medicineName.isNotEmpty) return b.medicineName;
            for (final m in inventoryProvider.medicines) {
              if (m.id == b.medicineId) return m.name;
            }
            return 'Medicine #${b.medicineId}';
          }

          final shown = all.where(_matchesFilter).where((b) {
            if (q.isEmpty) return true;
            return nameOf(b).toLowerCase().contains(q) ||
                b.batchNumber.toLowerCase().contains(q) ||
                b.supplierName.toLowerCase().contains(q) ||
                b.medicineSku.toLowerCase().contains(q);
          }).toList()
            ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));

          int count(bool Function(Batch) test) => all.where(test).length;

          final chips = <(String, String, int)>[
            ('ALL', 'All', all.length),
            ('ACTIVE', 'Active', count((b) => b.isActive)),
            ('EXPIRING', 'Expiring soon', count((b) => b.isExpiringSoon)),
            ('EXPIRED', 'Expired', count((b) => b.isExpired)),
            ('DEPLETED', 'Depleted', count((b) => b.isDepleted)),
          ];

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Search medicine, batch number or supplier',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          ),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: chips.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final c = chips[i];
                    final selected = _filter == c.$1;

                    return ChoiceChip(
                      label: Text('${c.$2} (${c.$3})'),
                      selected: selected,
                      onSelected: (_) => setState(() => _filter = c.$1),
                      selectedColor: AppColors.dark,
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: selected ? Colors.white : AppColors.textPrimary,
                      ),
                      showCheckmark: false,
                    );
                  },
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: batchProvider.refresh,
                  child: shown.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                          children: [
                            Icon(Icons.inventory_2_outlined,
                                size: 42, color: AppColors.textSecondary),
                            const SizedBox(height: 10),
                            Center(
                              child: Text(
                                all.isEmpty
                                    ? 'No batches recorded yet.\nTap "Create batch" to receive stock.'
                                    : 'No batches match your search or filter.',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.bodyMedium,
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 6, 20, 150),
                          itemCount: shown.length,
                          itemBuilder: (context, index) {
                            final batch = shown[index];
                            final med = inventoryProvider.medicines
                                .where((m) => m.id == batch.medicineId)
                                .firstOrNull;

                            return _BatchCard(
                              batch: batch,
                              medicineName: nameOf(batch),
                              imageUrl: med?.imageUrl,
                              onTap: () => context
                                  .push(RouteNames.batchDetail(batch.id)),
                            );
                          },
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BatchCard extends StatelessWidget {
  final Batch batch;
  final String medicineName;
  final String? imageUrl;
  final VoidCallback onTap;

  const _BatchCard({
    required this.batch,
    required this.medicineName,
    required this.imageUrl,
    required this.onTap,
  });

  static ({Color bg, Color fg}) statusColors(Batch b) {
    if (b.isExpired) {
      return (bg: AppColors.errorSoft, fg: AppColors.error);
    }
    if (b.isDepleted) {
      return (bg: AppColors.background, fg: AppColors.textSecondary);
    }
    if (b.isExpiringSoon) {
      return (bg: AppColors.warningSoft, fg: AppColors.warning);
    }
    return (bg: AppColors.successSoft, fg: AppColors.primaryDeep);
  }

  @override
  Widget build(BuildContext context) {
    final colors = statusColors(batch);
    final days = batch.daysToExpiry;
    final orig = batch.originalQuantity > 0
        ? batch.originalQuantity
        : (batch.quantity > 0 ? batch.quantity : 1);
    final ratio = (batch.quantity / orig).clamp(0.0, 1.0);

    String expiryText = 'Exp ${Formatter.date(batch.expiryDate)}';
    if (days != null && !batch.isDepleted) {
      if (days < 0) {
        expiryText += ' · ${-days}d ago';
      } else if (days <= 90) {
        expiryText += ' · in ${days}d';
      }
    }

    return GestureDetector(
      onTap: onTap,
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
                MedicineImage(url: imageUrl, size: 40, radius: 11),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        medicineName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyMedium
                            .copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text('Batch ${batch.batchNumber}',
                          style: AppTextStyles.bodySmall),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.bg,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    batch.isExpiringSoon ? 'Expiring soon' : batch.statusLabel,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: colors.fg,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  '${batch.quantity}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 18),
                ),
                Text(
                  ' / ${batch.originalQuantity > 0 ? batch.originalQuantity : batch.quantity} units left',
                  style: AppTextStyles.bodySmall,
                ),
                const Spacer(),
                Text(expiryText, style: AppTextStyles.bodySmall),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 5,
                backgroundColor: AppColors.border,
                valueColor: AlwaysStoppedAnimation(colors.fg),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.local_shipping_outlined,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    batch.supplierName.isEmpty ? 'No supplier' : batch.supplierName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall,
                  ),
                ),
                Text(
                  'Buy ${Formatter.number(batch.buyingPrice)}  ·  Sell ${Formatter.number(batch.sellingPrice)}',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
