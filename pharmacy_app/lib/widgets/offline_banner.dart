import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_colors.dart';
import '../providers/connectivity_provider.dart';

/// Shown across the top of the app whenever the phone can't reach the server.
/// The screens underneath keep showing the data saved on the phone.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  static String _when(DateTime? t) {
    if (t == null) return 'earlier';
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    return '${diff.inDays} d ago';
  }

  @override
  Widget build(BuildContext context) {
    final net = context.watch<ConnectivityProvider>();
    if (net.isOnline) return const SizedBox.shrink();

    final ink = AppColors.darkMode
        ? const Color(0xFFFFD98A)
        : const Color(0xFF6B4E00);

    return Material(
      color: AppColors.warningSoft,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(
            children: [
              Icon(Icons.cloud_off_rounded, size: 20, color: ink),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'You are offline',
                      style: TextStyle(
                        color: ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Showing data saved ${_when(net.lastSync)}. Some '
                      'transactions and changes may have happened since. '
                      'Reconnect to see the latest and to save changes.',
                      style: TextStyle(
                        color: ink,
                        fontSize: 11.5,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: net.isChecking ? null : net.retry,
                child: net.isChecking
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        'Retry',
                        style: TextStyle(
                          color: ink,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
