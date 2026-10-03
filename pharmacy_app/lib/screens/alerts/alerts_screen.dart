import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/app_colors.dart';
import '../../config/app_text_styles.dart';
import '../../providers/inventory_provider.dart';
import '../../routes/route_names.dart';
import '../../widgets/error_widget.dart';
import '../../widgets/loading_widget.dart';

/// Low-stock / out-of-stock alerts, computed straight from the medicines
/// list (reorder_level vs quantity) — the backend has no dedicated
/// notifications endpoint yet.
class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InventoryProvider>().loadMedicines();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
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

          final outOfStock = provider.outOfStock;
          final lowStock = provider.lowStock;
          final flagged = [...outOfStock, ...lowStock];
          final total = provider.medicines.length;

          return RefreshIndicator(
            onRefresh: provider.refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
              children: [
                Text('Alerts', style: AppTextStyles.headingLarge),
                const SizedBox(height: 14),
                Container(
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
                          color: Color(0xFFB9BEB9),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text.rich(
                        TextSpan(
                          text: '${flagged.length} ',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                          ),
                          children: [
                            TextSpan(
                              text: 'of $total SKUs',
                              style: const TextStyle(
                                color: Color(0xFFB9BEB9),
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _chip('${outOfStock.length} out of stock',
                              const Color(0x33EF4444), const Color(0xFFFF9A9A)),
                          const SizedBox(width: 8),
                          _chip('${lowStock.length} running low',
                              Colors.white.withValues(alpha: 0.1), Colors.white),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (flagged.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text(
                        'Everything is well stocked right now.',
                        style: AppTextStyles.bodyMedium,
                      ),
                    ),
                  )
                else
                  ...flagged.map((medicine) {
                    final isOut = medicine.quantity <= 0;

                    return GestureDetector(
                      onTap: () => context.push(
                        RouteNames.medicineDetail(medicine.id),
                      ),
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
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
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
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                ),
                                onPressed: () => context.push(
                                  RouteNames.medicineDetail(medicine.id),
                                ),
                                child: const Text('Reorder'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isOut
                                ? '0 left · out of stock'
                                : '${medicine.quantity} left · reorder at ${medicine.reorderLevel}',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: isOut
                                  ? AppColors.error
                                  : AppColors.textSecondary,
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
                              valueColor: const AlwaysStoppedAnimation(
                                  AppColors.error),
                            ),
                          ),
                        ],
                      ),
                      ),
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }

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
