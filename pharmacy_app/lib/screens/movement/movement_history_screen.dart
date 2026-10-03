import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_sizes.dart';
import '../../config/app_text_styles.dart';
import '../../models/stock_movement.dart';
import '../../providers/stock_movement_provider.dart';
import '../../widgets/error_widget.dart';
import '../../widgets/loading_widget.dart';

class MovementHistoryScreen extends StatefulWidget {
  const MovementHistoryScreen({super.key});

  @override
  State<MovementHistoryScreen> createState() =>
      _MovementHistoryScreenState();
}

class _MovementHistoryScreenState
    extends State<MovementHistoryScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context
          .read<StockMovementProvider>()
          .loadMovements();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Movement History',
          style: AppTextStyles.headingMedium,
        ),
      ),
      body: Consumer<StockMovementProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading &&
              provider.movements.isEmpty) {
            return const LoadingWidget();
          }

          if (provider.error != null &&
              provider.movements.isEmpty) {
            return AppErrorWidget(
              message: provider.error!,
              onRetry: provider.loadMovements,
            );
          }

          if (provider.movements.isEmpty) {
            return RefreshIndicator(
              onRefresh: provider.refresh,
              child: ListView(
                physics:
                    const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  Center(
                    child: Text(
                      'No stock movements found.',
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: provider.refresh,
            child: ListView.builder(
              physics:
                  const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(
                AppSizes.paddingMedium,
              ),
              itemCount: provider.movements.length,
              itemBuilder: (context, index) {
                final movement =
                    provider.movements[index];

                return _MovementCard(
                  movement: movement,
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _MovementCard extends StatelessWidget {
  final StockMovement movement;

  const _MovementCard({
    required this.movement,
  });

  @override
  Widget build(BuildContext context) {
    final isIncoming =
        movement.movementType.toUpperCase() == 'IN';

    return Card(
      margin: const EdgeInsets.only(
        bottom: AppSizes.spacingSmall,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSizes.paddingMedium,
          vertical: AppSizes.paddingSmall,
        ),
        leading: CircleAvatar(
          child: Icon(
            isIncoming
                ? Icons.arrow_downward
                : Icons.arrow_upward,
          ),
        ),
        title: Text(
          movement.movementType.isNotEmpty
              ? movement.movementType
              : 'Stock Movement',
          style: AppTextStyles.headingSmall,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            'Medicine ID: ${movement.medicineId}\n'
            'Batch ID: ${movement.batchId}\n'
            'Date: ${_displayDate(movement)}',
            style: AppTextStyles.bodySmall,
          ),
        ),
        trailing: Text(
          '${movement.quantity}',
          style: AppTextStyles.headingSmall,
        ),
        isThreeLine: true,
      ),
    );
  }

  String _displayDate(StockMovement movement) {
    if (movement.movementDate.isNotEmpty) {
      return movement.movementDate;
    }

    return movement.date;
  }
}