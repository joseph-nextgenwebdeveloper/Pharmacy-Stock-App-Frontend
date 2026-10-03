import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_sizes.dart';
import '../../config/app_text_styles.dart';
import '../../providers/sales_provider.dart';
import '../../widgets/error_widget.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/search_bar_widget.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SalesProvider>().loadSales();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Sales',
          style: AppTextStyles.headingMedium,
        ),
      ),
      body: Consumer<SalesProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading &&
              provider.sales.isEmpty) {
            return const LoadingWidget();
          }

          if (provider.error != null &&
              provider.sales.isEmpty) {
            return AppErrorWidget(
              message: provider.error!,
              onRetry: provider.loadSales,
            );
          }

          final sales = provider.sales.where((sale) {
            final query = _searchQuery.toLowerCase();

            return sale.receiptNumber
                    .toLowerCase()
                    .contains(query) ||
                sale.paymentMethod
                    .toLowerCase()
                    .contains(query) ||
                sale.id.toString().contains(query);
          }).toList();

          return RefreshIndicator(
            onRefresh: provider.refresh,
            child: ListView(
              padding: const EdgeInsets.all(
                AppSizes.paddingMedium,
              ),
              children: [
                SearchBarWidget(
                  hintText: 'Search sales...',
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
                const SizedBox(
                  height: AppSizes.spacingMedium,
                ),
                if (sales.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: Center(
                      child: Text(
                        'No sales records found.',
                      ),
                    ),
                  )
                else
                  ...sales.map(
                    (sale) => Card(
                      margin: const EdgeInsets.only(
                        bottom: AppSizes.spacingSmall,
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.paddingMedium,
                          vertical: AppSizes.paddingSmall,
                        ),
                        leading: CircleAvatar(
                          child: const Icon(
                            Icons.receipt_long_outlined,
                          ),
                        ),
                        title: Text(
                          sale.receiptNumber.isNotEmpty
                              ? sale.receiptNumber
                              : 'Sale #${sale.id}',
                          style: AppTextStyles.headingSmall,
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            '${sale.paymentMethod}\n'
                            '${sale.createdAt}\n'
                            '${sale.items.length} item(s)',
                            style: AppTextStyles.bodySmall,
                          ),
                        ),
                        isThreeLine: true,
                        trailing: Text(
                          'KES ${sale.totalAmount.toStringAsFixed(2)}',
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}