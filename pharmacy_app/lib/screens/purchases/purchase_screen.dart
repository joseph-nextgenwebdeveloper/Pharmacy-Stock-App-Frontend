import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_sizes.dart';
import '../../config/app_text_styles.dart';
import '../../providers/purchase_provider.dart';
import '../../widgets/error_widget.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/search_bar_widget.dart';

class PurchaseScreen extends StatefulWidget {
  const PurchaseScreen({super.key});

  @override
  State<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends State<PurchaseScreen> {
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PurchaseProvider>().loadGoodsReceived();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Goods Received',
          style: AppTextStyles.headingMedium,
        ),
      ),
      body: Consumer<PurchaseProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading &&
              provider.goodsReceived.isEmpty) {
            return const LoadingWidget();
          }

          if (provider.error != null &&
              provider.goodsReceived.isEmpty) {
            return AppErrorWidget(
              message: provider.error!,
              onRetry: provider.loadGoodsReceived,
            );
          }

          final deliveries = provider.goodsReceived.where((delivery) {
            final query = _searchQuery.toLowerCase();

            return delivery.invoiceNumber
                    .toLowerCase()
                    .contains(query) ||
                delivery.supplier.toString().contains(query) ||
                delivery.receivedBy.toString().contains(query);
          }).toList();

          return RefreshIndicator(
            onRefresh: provider.refresh,
            child: ListView(
              padding: const EdgeInsets.all(
                AppSizes.paddingMedium,
              ),
              children: [
                SearchBarWidget(
                  hintText: 'Search received stock...',
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
                const SizedBox(
                  height: AppSizes.spacingMedium,
                ),
                if (deliveries.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: Center(
                      child: Text(
                        'No goods received records found.',
                      ),
                    ),
                  )
                else
                  ...deliveries.map(
                    (delivery) => Card(
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
                            Icons.inventory_2_outlined,
                          ),
                        ),
                        title: Text(
                          delivery.invoiceNumber.isNotEmpty
                              ? 'Invoice ${delivery.invoiceNumber}'
                              : 'Goods Received #${delivery.id}',
                          style: AppTextStyles.headingSmall,
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'Supplier: ${delivery.supplier}\n'
                            'Received: ${delivery.receivedDate}\n'
                            '${delivery.items.length} item(s)',
                            style: AppTextStyles.bodySmall,
                          ),
                        ),
                        isThreeLine: true,
                        trailing: const Icon(
                          Icons.chevron_right,
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