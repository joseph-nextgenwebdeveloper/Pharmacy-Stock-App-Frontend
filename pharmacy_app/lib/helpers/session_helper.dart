import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/activity_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/batch_provider.dart';
import '../providers/category_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/inventory_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/purchase_provider.dart';
import '../providers/sales_provider.dart';
import '../providers/stock_movement_provider.dart';
import '../providers/supplier_provider.dart';
import '../routes/route_names.dart';
import '../services/stock_alert_service.dart';

class SessionHelper {
  /// Signs out, wipes the data saved on the phone and everything held in
  /// memory, stops the stock reminders, and returns to the login screen.
  static Future<void> signOut(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final resets = <VoidCallback>[
      context.read<InventoryProvider>().reset,
      context.read<BatchProvider>().reset,
      context.read<CategoryProvider>().reset,
      context.read<DashboardProvider>().reset,
      context.read<NotificationProvider>().reset,
      context.read<PurchaseProvider>().reset,
      context.read<SalesProvider>().reset,
      context.read<StockMovementProvider>().reset,
      context.read<SupplierProvider>().reset,
      context.read<ActivityProvider>().reset,
    ];
    final router = GoRouter.of(context);

    await StockAlertService.clear();
    await auth.logout();
    for (final reset in resets) {
      reset();
    }

    router.go(RouteNames.login);
  }
}
