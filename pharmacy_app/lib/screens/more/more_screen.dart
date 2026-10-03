import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../routes/route_names.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <_MoreItem>[
      _MoreItem(Icons.local_shipping_outlined, 'Purchases', RouteNames.purchases),
      _MoreItem(Icons.point_of_sale_outlined, 'Sales', RouteNames.sales),
      _MoreItem(Icons.groups_outlined, 'Suppliers', RouteNames.suppliers),
      _MoreItem(Icons.bar_chart_outlined, 'Reports', RouteNames.reports),
      _MoreItem(Icons.history, 'Movement History', RouteNames.movementHistory),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView.separated(
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = items[index];
          return ListTile(
            leading: Icon(item.icon),
            title: Text(item.label),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(item.route),
          );
        },
      ),
    );
  }
}

class _MoreItem {
  final IconData icon;
  final String label;
  final String route;
  const _MoreItem(this.icon, this.label, this.route);
}