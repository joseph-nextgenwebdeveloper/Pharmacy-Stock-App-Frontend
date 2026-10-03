import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';

import '../../config/app_colors.dart';
import '../../providers/inventory_provider.dart';
import '../../routes/route_names.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  final _manualController = TextEditingController();

  bool _isProcessing = false;
  String? _message;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InventoryProvider>().loadMedicines();
      // Explicit start (rather than relying on autoStart) so a failure —
      // most commonly a denied camera permission — surfaces through
      // errorBuilder below instead of leaving a blank preview.
      _controller.start();
    });
  }

  String _describeError(MobileScannerException error) {
    switch (error.errorCode) {
      case MobileScannerErrorCode.permissionDenied:
        return 'Camera permission was denied.\n'
            'Enable it for this app in your phone\'s Settings > Apps > '
            'Permissions, then come back and tap "Try again".';
      case MobileScannerErrorCode.unsupported:
        return 'This device doesn\'t support the camera scanner.\n'
            'Use "Or type SKU / name manually" below instead.';
      default:
        return 'Could not open the camera (${error.errorCode.name}).\n'
            'Try again, or use the manual search below.';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _manualController.dispose();
    super.dispose();
  }

  Future<void> _lookup(String value) async {
    final query = value.trim().toLowerCase();
    if (query.isEmpty) return;

    setState(() {
      _isProcessing = true;
      _message = 'Searching for $value...';
    });

    await _controller.stop();
    if (!mounted) return;

    final inventoryProvider = context.read<InventoryProvider>();

    final medicine = inventoryProvider.medicines.where((medicine) {
      return medicine.sku.trim().toLowerCase() == query ||
          medicine.name.trim().toLowerCase() == query;
    }).firstOrNull;

    if (medicine != null) {
      context.push(RouteNames.medicineDetail(medicine.id));
      _restartScanner();
      return;
    }

    setState(() {
      _isProcessing = false;
      _message = 'No medicine found for "$value".';
    });

    await _controller.start();
  }

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (_isProcessing) return;

    String? scannedValue;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim();
      if (value != null && value.isNotEmpty) {
        scannedValue = value;
        break;
      }
    }

    if (scannedValue == null) return;
    await _lookup(scannedValue);
  }

  void _restartScanner() {
    setState(() {
      _isProcessing = false;
      _message = null;
    });
    _manualController.clear();
    _controller.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dark,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.go(RouteNames.dashboard),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                  const Spacer(),
                  const Text(
                    'Scan barcode',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => _controller.toggleTorch(),
                    icon: const Icon(Icons.flashlight_on_rounded, color: Colors.white),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    child: MobileScanner(
                      controller: _controller,
                      onDetect: _handleBarcode,
                      // Surfaces the *real* reason the camera didn't open
                      // (permission denied, camera in use, unsupported,
                      // etc.) instead of leaving a blank/frozen preview —
                      // that silent failure is what "scan isn't working"
                      // usually turns out to be.
                      errorBuilder: (context, error, child) {
                        final reason = _describeError(error);

                        return Container(
                          color: AppColors.dark,
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.videocam_off_rounded,
                                  color: Colors.white, size: 40),
                              const SizedBox(height: 14),
                              Text(
                                reason,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 16),
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: Colors.white),
                                ),
                                onPressed: () => _controller.start(),
                                child: const Text('Try again'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  Center(
                    child: SizedBox(
                      width: 230,
                      height: 230,
                      child: CustomPaint(painter: _ScanFramePainter()),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 16,
                    child: Text(
                      _message ?? 'Point at the item barcode',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFB9BEB9),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              decoration: const BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _manualController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: _lookup,
                    decoration: InputDecoration(
                      hintText: 'Or type SKU / name manually',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                    ),
                  ),
                  if (_isProcessing) ...[
                    const SizedBox(height: 14),
                    const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ] else if (_message != null) ...[
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: _restartScanner,
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                      label: const Text('Scan again'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    const len = 32.0;

    // top-left
    canvas.drawLine(const Offset(0, 0), const Offset(len, 0), paint);
    canvas.drawLine(const Offset(0, 0), const Offset(0, len), paint);
    // top-right
    canvas.drawLine(Offset(size.width - len, 0), Offset(size.width, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, len), paint);
    // bottom-left
    canvas.drawLine(Offset(0, size.height - len), Offset(0, size.height), paint);
    canvas.drawLine(
        Offset(0, size.height), Offset(len, size.height), paint);
    // bottom-right
    canvas.drawLine(Offset(size.width - len, size.height),
        Offset(size.width, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height - len),
        Offset(size.width, size.height), paint);

    final linePaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(8, size.height / 2),
      Offset(size.width - 8, size.height / 2),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
