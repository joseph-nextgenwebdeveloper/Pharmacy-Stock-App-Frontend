import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../routes/route_names.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthentication();
  }

  Future<void> _checkAuthentication() async {
    await Future.delayed(const Duration(milliseconds: 1200));

    if (!mounted) return;

    final authProvider = context.read<AuthProvider>();
    await authProvider.loadStoredUser();

    if (!mounted) return;

    if (authProvider.isAuthenticated) {
      context.go(RouteNames.dashboard);
    } else {
      context.go(RouteNames.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dark,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.inventory_2_rounded,
                color: Color(0xFF06170C),
                size: 30,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'StockRoom',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Pharmacy Inventory',
              style: TextStyle(
                color: Color(0xFFB9BEB9),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
