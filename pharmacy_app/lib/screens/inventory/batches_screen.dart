import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/app_colors.dart';
import '../../config/app_text_styles.dart';
import '../../helpers/formatter.dart';
import '../../providers/batch_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../routes/route_names.dart';
import '../../widgets/error_widget.dart';
import '../../widgets/loading_widget.dart';

/// A full list of every batch across every medicine — "how many batches do
/// I have" plus a way to jump straight to any one of them.
class BatchesScreen extends StatefulWidget {
  const BatchesScreen({super.key});

  @override
  State<BatchesScreen> createState() => _BatchesScreenState();
}

class _BatchesScreenState extends State<BatchesScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BatchProvider>().loadBatches();
      context.read<InventoryProvider>().loadMedicines();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Batches')),
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

          final batches = [...batchProvider.batches]
            ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));

          if (batches.isEmpty) {
            return RefreshIndicator(
              onRefresh: batchProvider.refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                children: const [
                  Center(child: Text('No batches recorded yet.')),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: batchProvider.refresh,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
              itemCount: batches.length,
              itemBuilder: (context, index) {
                final batch = batches[index];

                final matches = inventoryProvider.medicines
                    .where((m) => m.id == batch.medicineId)
                    .toList();
                final medicineName =
                    matches.isNotEmpty ? matches.first.name : 'Medicine #${batch.medicineId}';

                final expiry = DateTime.tryParse(batch.expiryDate);
                final isExpiringSoon = expiry != null &&
                    expiry.difference(DateTime.now()).inDays <= 30;

                return GestureDetector(
                  onTap: () => context.push(
                    RouteNames.medicineDetail(batch.medicineId),
                  ),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isExpiringSoon
                          ? AppColors.warningSoft
                          : AppColors.surface,
                      border: Border.all(
                        color: isExpiringSoon
                            ? const Color(0xFFF3E2AE)
                            : AppColors.border,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.successSoft,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.inventory_outlined,
                              size: 17, color: AppColors.primaryDeep),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(medicineName,
                                  style: AppTextStyles.bodyMedium
                                      .copyWith(fontWeight: FontWeight.w800)),
                              const SizedBox(height: 2),
                              Text(
                                '${batch.batchNumber} · exp ${Formatter.date(batch.expiryDate)}',
                                style: AppTextStyles.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('${batch.quantity}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 15)),
                            if (isExpiringSoon)
                              const Text(
                                'Expiring soon',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.warning,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
