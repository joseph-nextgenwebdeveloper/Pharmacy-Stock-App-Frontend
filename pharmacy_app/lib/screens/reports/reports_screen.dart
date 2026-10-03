import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_sizes.dart';
import '../../config/app_text_styles.dart';
import '../../models/expired_medicine_report.dart';
import '../../models/fast_moving_medicine.dart';
import '../../models/inventory_report.dart';
import '../../models/monthly_movement_report.dart';
import '../../models/slow_moving_medicine.dart';
import '../../models/stock_valuation_report.dart';
import '../../providers/report_provider.dart';
import '../../widgets/error_widget.dart';
import '../../widgets/loading_widget.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() =>
      _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String? _selectedReport;

  final int _currentYear = DateTime.now().year;
  final int _currentMonth = DateTime.now().month;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Reports',
          style: AppTextStyles.headingMedium,
        ),
      ),
      body: Consumer<ReportProvider>(
        builder: (context, provider, child) {
          if (_selectedReport == null) {
            return _buildReportMenu(context);
          }

          return _buildSelectedReport(
            context,
            provider,
          );
        },
      ),
    );
  }

  Widget _buildReportMenu(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(
        AppSizes.paddingMedium,
      ),
      children: [
        _ReportCard(
          title: 'Inventory Report',
          description:
              'View medicine stock and inventory information.',
          icon: Icons.inventory_2_outlined,
          onTap: () {
            setState(() {
              _selectedReport = 'inventory';
            });

            context
                .read<ReportProvider>()
                .loadInventoryReport();
          },
        ),
        _ReportCard(
          title: 'Stock Valuation',
          description:
              'View the current value of pharmacy stock.',
          icon:
              Icons.account_balance_wallet_outlined,
          onTap: () {
            setState(() {
              _selectedReport = 'valuation';
            });

            context
                .read<ReportProvider>()
                .loadStockValuationReport();
          },
        ),
        _ReportCard(
          title: 'Expired Medicines',
          description:
              'View medicines that have already expired.',
          icon: Icons.event_busy_outlined,
          onTap: () {
            setState(() {
              _selectedReport = 'expired';
            });

            context
                .read<ReportProvider>()
                .loadExpiredMedicineReport();
          },
        ),
        _ReportCard(
          title: 'Monthly Movement',
          description:
              'Review monthly stock movement activity.',
          icon: Icons.bar_chart_outlined,
          onTap: () {
            setState(() {
              _selectedReport = 'monthly';
            });

            context
                .read<ReportProvider>()
                .loadMonthlyMovementReport(
                  year: _currentYear,
                  month: _currentMonth,
                );
          },
        ),
        _ReportCard(
          title: 'Fast-Moving Medicines',
          description:
              'View medicines with higher sales activity.',
          icon: Icons.trending_up_outlined,
          onTap: () {
            setState(() {
              _selectedReport = 'fast';
            });

            context
                .read<ReportProvider>()
                .loadFastMovingMedicines();
          },
        ),
        _ReportCard(
          title: 'Slow-Moving Medicines',
          description:
              'View medicines with lower sales activity.',
          icon: Icons.trending_down_outlined,
          onTap: () {
            setState(() {
              _selectedReport = 'slow';
            });

            context
                .read<ReportProvider>()
                .loadSlowMovingMedicines();
          },
        ),
      ],
    );
  }

  Widget _buildSelectedReport(
    BuildContext context,
    ReportProvider provider,
  ) {
    if (provider.isLoading) {
      return const LoadingWidget();
    }

    if (provider.error != null) {
      return AppErrorWidget(
        message: provider.error!,
        onRetry: () {
          _reloadSelectedReport(provider);
        },
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.paddingMedium,
            AppSizes.paddingMedium,
            AppSizes.paddingMedium,
            0,
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    _selectedReport = null;
                  });
                },
                icon: const Icon(Icons.arrow_back),
              ),
              Expanded(
                child: Text(
                  _reportTitle(),
                  style: AppTextStyles.headingMedium,
                ),
              ),
              IconButton(
                onPressed: () {
                  _reloadSelectedReport(provider);
                },
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        Expanded(
          child: _buildReportContent(provider),
        ),
      ],
    );
  }

  Widget _buildReportContent(ReportProvider provider) {
    switch (_selectedReport) {
      case 'inventory':
        return _InventoryReportView(
          reports: provider.inventoryReport,
        );

      case 'valuation':
        return _StockValuationReportView(
          reports: provider.stockValuationReport,
        );

      case 'expired':
        return _ExpiredReportView(
          reports: provider.expiredMedicineReport,
        );

      case 'monthly':
        return _MonthlyMovementReportView(
          report: provider.monthlyMovementReport,
        );

      case 'fast':
        return _FastMovingReportView(
          reports: provider.fastMovingMedicines,
        );

      case 'slow':
        return _SlowMovingReportView(
          reports: provider.slowMovingMedicines,
        );

      default:
        return const SizedBox.shrink();
    }
  }

  String _reportTitle() {
    switch (_selectedReport) {
      case 'inventory':
        return 'Inventory Report';
      case 'valuation':
        return 'Stock Valuation';
      case 'expired':
        return 'Expired Medicines';
      case 'monthly':
        return 'Monthly Movement';
      case 'fast':
        return 'Fast-Moving Medicines';
      case 'slow':
        return 'Slow-Moving Medicines';
      default:
        return 'Reports';
    }
  }

  void _reloadSelectedReport(
    ReportProvider provider,
  ) {
    switch (_selectedReport) {
      case 'inventory':
        provider.loadInventoryReport();
        break;
      case 'valuation':
        provider.loadStockValuationReport();
        break;
      case 'expired':
        provider.loadExpiredMedicineReport();
        break;
      case 'monthly':
        provider.loadMonthlyMovementReport(
          year: _currentYear,
          month: _currentMonth,
        );
        break;
      case 'fast':
        provider.loadFastMovingMedicines();
        break;
      case 'slow':
        provider.loadSlowMovingMedicines();
        break;
    }
  }
}

class _ReportCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  const _ReportCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(
        bottom: AppSizes.spacingSmall,
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSizes.paddingMedium,
          vertical: AppSizes.paddingSmall,
        ),
        leading: CircleAvatar(
          child: Icon(icon),
        ),
        title: Text(
          title,
          style: AppTextStyles.headingSmall,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            description,
            style: AppTextStyles.bodySmall,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right,
        ),
      ),
    );
  }
}

class _InventoryReportView extends StatelessWidget {
  final List<InventoryReport> reports;

  const _InventoryReportView({
    required this.reports,
  });

  @override
  Widget build(BuildContext context) {
    if (reports.isEmpty) {
      return const _EmptyReport(
        message: 'No inventory report data found.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(
        AppSizes.paddingMedium,
      ),
      itemCount: reports.length,
      itemBuilder: (context, index) {
        final report = reports[index];

        return Card(
          child: ListTile(
            title: Text(
              report.medicine,
              style: AppTextStyles.headingSmall,
            ),
            subtitle: Text(
              'SKU: ${report.sku}\n'
              'Reorder level: ${report.reorderLevel}',
            ),
            isThreeLine: true,
            trailing: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              crossAxisAlignment:
                  CrossAxisAlignment.end,
              children: [
                Text('${report.quantity}'),
                const SizedBox(height: 4),
                Text(
                  report.status,
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StockValuationReportView extends StatelessWidget {
  final List<StockValuationReport> reports;

  const _StockValuationReportView({
    required this.reports,
  });

  @override
  Widget build(BuildContext context) {
    if (reports.isEmpty) {
      return const _EmptyReport(
        message: 'No stock valuation data found.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(
        AppSizes.paddingMedium,
      ),
      itemCount: reports.length,
      itemBuilder: (context, index) {
        final report = reports[index];

        return Card(
          child: ListTile(
            title: Text(
              report.medicine,
              style: AppTextStyles.headingSmall,
            ),
            subtitle: Text(
              'SKU: ${report.sku}\n'
              'Quantity: ${report.quantity}',
            ),
            isThreeLine: true,
            trailing: Text(
              'KSh ${report.stockValue.toStringAsFixed(2)}',
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ExpiredReportView extends StatelessWidget {
  final List<ExpiredMedicineReport> reports;

  const _ExpiredReportView({
    required this.reports,
  });

  @override
  Widget build(BuildContext context) {
    if (reports.isEmpty) {
      return const _EmptyReport(
        message: 'No expired medicines found.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(
        AppSizes.paddingMedium,
      ),
      itemCount: reports.length,
      itemBuilder: (context, index) {
        final report = reports[index];

        return Card(
          child: ListTile(
            title: Text(
              report.medicine,
              style: AppTextStyles.headingSmall,
            ),
            subtitle: Text(
              'SKU: ${report.sku}\n'
              'Batch: ${report.batchNumber}\n'
              'Expiry: ${report.expiryDate}',
            ),
            isThreeLine: true,
            trailing: Text(
              '${report.quantity}',
              style: AppTextStyles.headingSmall,
            ),
          ),
        );
      },
    );
  }
}

class _MonthlyMovementReportView
    extends StatelessWidget {
  final MonthlyMovementReport? report;

  const _MonthlyMovementReportView({
    required this.report,
  });

  @override
  Widget build(BuildContext context) {
    if (report == null) {
      return const _EmptyReport(
        message: 'No monthly movement data found.',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(
        AppSizes.paddingMedium,
      ),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(
              AppSizes.paddingMedium,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  '${report!.year} - '
                  '${report!.month.toString().padLeft(2, '0')}',
                  style: AppTextStyles.headingMedium,
                ),
                const SizedBox(
                  height: AppSizes.spacingMedium,
                ),
                _MovementValue(
                  label: 'Stock Received',
                  value: report!.stockReceived,
                  icon: Icons.input_outlined,
                ),
                const SizedBox(
                  height: AppSizes.spacingMedium,
                ),
                _MovementValue(
                  label: 'Stock Dispensed',
                  value: report!.stockDispensed,
                  icon: Icons.output_outlined,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MovementValue extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;

  const _MovementValue({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.bodyMedium,
          ),
        ),
        Text(
          '$value',
          style: AppTextStyles.headingSmall,
        ),
      ],
    );
  }
}

class _FastMovingReportView extends StatelessWidget {
  final List<FastMovingMedicine> reports;

  const _FastMovingReportView({
    required this.reports,
  });

  @override
  Widget build(BuildContext context) {
    if (reports.isEmpty) {
      return const _EmptyReport(
        message:
            'No fast-moving medicine data found.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(
        AppSizes.paddingMedium,
      ),
      itemCount: reports.length,
      itemBuilder: (context, index) {
        final report = reports[index];

        return Card(
          child: ListTile(
            title: Text(
              report.medicine,
              style: AppTextStyles.headingSmall,
            ),
            subtitle: Text(
              'SKU: ${report.sku}',
            ),
            trailing: Text(
              '${report.quantityDispensed}',
              style: AppTextStyles.headingSmall,
            ),
          ),
        );
      },
    );
  }
}

class _SlowMovingReportView extends StatelessWidget {
  final List<SlowMovingMedicine> reports;

  const _SlowMovingReportView({
    required this.reports,
  });

  @override
  Widget build(BuildContext context) {
    if (reports.isEmpty) {
      return const _EmptyReport(
        message:
            'No slow-moving medicine data found.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(
        AppSizes.paddingMedium,
      ),
      itemCount: reports.length,
      itemBuilder: (context, index) {
        final report = reports[index];

        return Card(
          child: ListTile(
            title: Text(
              report.medicine,
              style: AppTextStyles.headingSmall,
            ),
            subtitle: Text(
              'SKU: ${report.sku}',
            ),
            trailing: Text(
              '${report.quantityDispensed}',
              style: AppTextStyles.headingSmall,
            ),
          ),
        );
      },
    );
  }
}

class _EmptyReport extends StatelessWidget {
  final String message;

  const _EmptyReport({
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(
          AppSizes.paddingLarge,
        ),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium,
        ),
      ),
    );
  }
}