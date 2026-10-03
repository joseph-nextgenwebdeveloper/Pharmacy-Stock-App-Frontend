import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_colors.dart';
import '../../routes/route_names.dart';
import '../../widgets/bottom_nav_bar.dart';

class MainScreen extends StatefulWidget {
  final Widget child;

  const MainScreen({
    super.key,
    required this.child,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  static const List<String> _routes = [
    RouteNames.dashboard,
    RouteNames.inventory,
    RouteNames.scanner,
    RouteNames.alerts,
    RouteNames.profile,
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final location = GoRouterState.of(context).uri.path;

    final index = _routes.indexWhere(
      (route) => location.startsWith(route),
    );

    if (index != -1 && index != _currentIndex) {
      _currentIndex = index;
    }
  }

  void _onNavigationTap(int index) {
    setState(() {
      _currentIndex = index;
    });

    context.go(_routes[index]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: true,
      body: widget.child,
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onNavigationTap,
      ),
    );
  }
}
