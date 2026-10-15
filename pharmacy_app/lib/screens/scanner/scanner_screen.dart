import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../config/app_colors.dart';
import '../../config/app_text_styles.dart';
import '../../helpers/barcode_parser.dart';
import '../../helpers/formatter.dart';
import '../../models/batch.dart';
import '../../models/medicine.dart';
import '../../providers/batch_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/stock_movement_provider.dart';
import '../../routes/route_names.dart';
import '../../widgets/medicine_image.dart';

enum _SheetAction { none, openMedicine, registerBatch, registerMedicine }

/// Scans a medicine pack (EAN-13 / UPC / GTIN-14 / GS1 DataMatrix / QR),
/// identifies the medicine by its manufacturer barcode, and — when the code
/// also carries a lot number — the exact batch. Without batch info it lists
/// the medicine's batches in FEFO order (earliest expiry first).
///
/// With [pickMode] the screen just returns the scanned text to the caller
/// (used by "scan barcode" buttons on forms).
///
/// Camera reliability
/// ------------------
/// * Every start / stop goes through ONE queue, so a lifecycle event (the
///   permission dialog, the notification shade) can never stop the camera
///   in the middle of it starting — that race was behind most
///   "genericError" failures.
/// * If starting fails, the screen retries with a brand-new camera
///   controller before showing an error.
/// * If the live camera still can't open, you can take a photo of the
///   barcode with the phone's own camera app (or pick one from the gallery)
///   and it is read from the picture. The scanner always works.
class ScannerScreen extends StatefulWidget {
  final bool pickMode;

  const ScannerScreen({super.key, this.pickMode = false});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  static const _formats = <BarcodeFormat>[
    BarcodeFormat.ean13,
    BarcodeFormat.ean8,
    BarcodeFormat.upcA,
    BarcodeFormat.upcE,
    BarcodeFormat.code128,
    BarcodeFormat.dataMatrix,
    BarcodeFormat.qrCode,
  ];

  static MobileScannerController _newController() => MobileScannerController(
        autoStart: false,
        detectionSpeed: DetectionSpeed.noDuplicates,
        facing: CameraFacing.back,
        formats: _formats,
      );

  MobileScannerController _controller = _newController();
  int _generation = 0; // changes whenever the controller is replaced

  final _manualController = TextEditingController();
  final _manualFocus = FocusNode();
  late final AnimationController _scanLine;

  // All camera start/stop work runs one-at-a-time through this chain.
  Future<void> _queue = Future<void>.value();

  bool _busy = false; // a result sheet / lookup is in progress
  bool _starting = false;
  bool _disposed = false;
  Object? _startError;
  String? _message;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _scanLine = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!widget.pickMode) {
        context.read<InventoryProvider>().loadMedicines();
        context.read<BatchProvider>().loadBatches();
      }
      _startCamera();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _scanLine.dispose();
    _manualController.dispose();
    _manualFocus.dispose();
    final controller = _controller;
    // Let any start/stop in flight finish, then release the camera.
    _queue = _queue.then((_) async {
      try {
        await controller.dispose();
      } catch (_) {}
    });
    super.dispose();
  }

  // The permission dialog and the notification shade only make the app
  // "inactive" — leave the camera alone then. Stop it only when the app is
  // really in the background, and start it again on return.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (!_busy) _startCamera();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _enqueue(() async {
          try {
            await _controller.stop();
          } catch (_) {}
        });
        break;
      case AppLifecycleState.inactive:
        break;
    }
  }

  Future<void> _enqueue(Future<void> Function() op) {
    final next = _queue.then((_) async {
      try {
        await op();
      } catch (_) {/* a failed step must never break the chain */}
    });
    _queue = next;
    return next;
  }

  void _setError(Object? error) {
    if (!mounted || _disposed) return;
    setState(() => _startError = error);
  }

  /// Replaces the camera controller with a fresh one (clears any stuck
  /// native state) and rebuilds the preview.
  Future<void> _swapController() async {
    final old = _controller;
    _controller = _newController();
    if (mounted && !_disposed) setState(() => _generation++);

    await WidgetsBinding.instance.endOfFrame;
    try {
      await old.dispose();
    } catch (_) {}
  }

  /// Opens the camera. Retries (with a fresh controller) before giving up.
  Future<void> _startCamera({bool fresh = false}) {
    return _enqueue(() async {
      if (!mounted || _disposed || _busy) return;

      if (mounted) setState(() => _starting = true);
      Object? lastError;

      try {
        if (fresh) await _swapController();

        for (var attempt = 0; attempt < 3; attempt++) {
          if (!mounted || _disposed) return;

          try {
            if (_controller.value.isRunning) {
              _setError(null);
              return;
            }

            // Give a previous screen / the OS a moment to release the camera.
            await Future.delayed(Duration(milliseconds: attempt == 0 ? 250 : 700));
            if (!mounted || _disposed) return;

            await _controller.start();
            _setError(null);
            return;
          } on MobileScannerException catch (e) {
            if (e.errorCode.name == 'controllerAlreadyInitialized') {
              _setError(null);
              return;
            }
            if (e.errorCode == MobileScannerErrorCode.permissionDenied) {
              _setError(e); // retrying can't fix this
              return;
            }
            lastError = e;
          } catch (e) {
            lastError = e;
          }

          if (attempt < 2) await _swapController();
        }

        _setError(lastError);
      } finally {
        if (mounted && !_disposed) setState(() => _starting = false);
      }
    });
  }

  Future<void> _retry() => _startCamera(fresh: true);

  Object? _currentError(MobileScannerState state) => _startError ?? state.error;

  String _describeError(Object error) {
    if (error is MobileScannerException) {
      switch (error.errorCode) {
        case MobileScannerErrorCode.permissionDenied:
          return 'Camera permission was denied.\n'
              'Allow it in Settings > Apps > this app > Permissions, '
              'then tap "Try again".';
        case MobileScannerErrorCode.unsupported:
          return 'This device does not support the live scanner.\n'
              'Take a photo of the barcode instead, or type it below.';
        default:
          return 'The live camera could not be opened.\n'
              'You can still scan by taking a photo of the barcode.';
      }
    }
    return 'The live camera could not be opened.\n'
        'You can still scan by taking a photo of the barcode.';
  }

  /// The real reason the camera failed, shown small so it can be reported.
  String? _technicalDetail(Object error) {
    if (error is MobileScannerException) {
      final msg = error.errorDetails?.message;
      final code = error.errorCode.name;
      return (msg == null || msg.isEmpty) ? code : '$code: $msg';
    }
    return error.toString();
  }

  // ----------------------------------------------- photo / gallery fallback

  Future<void> _scanFromPicture(ImageSource source) async {
    if (_busy) return;

    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 92,
      );
      if (picked == null || !mounted) return;

      setState(() => _message = 'Reading the picture…');

      final capture = await _controller.analyzeImage(picked.path);
      String? code;
      for (final barcode in capture?.barcodes ?? const <Barcode>[]) {
        final v = barcode.rawValue?.trim();
        if (v != null && v.isNotEmpty) {
          code = v;
          break;
        }
      }

      if (!mounted) return;
      setState(() => _message = null);

      if (code == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No barcode found in that picture. Get closer and keep it '
              'sharp, or type the code below.',
            ),
          ),
        );
        return;
      }

      await _handleCode(code);
    } catch (e) {
      if (!mounted) return;
      setState(() => _message = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not read that picture. Try again or type the code.'),
        ),
      );
    }
  }

  // ------------------------------------------------------------- scanning

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy) return;

    String? value;
    for (final barcode in capture.barcodes) {
      final v = barcode.rawValue?.trim();
      if (v != null && v.isNotEmpty) {
        value = v;
        break;
      }
    }

    if (value != null) await _handleCode(value);
  }

  String? _lastCode;
  DateTime _lastAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// The last few medicines handled here (shown under "Recent scans").
  final List<_Recent> _recent = [];

  Future<void> _handleCode(String raw, {bool manual = false}) async {
    final code = raw.trim();
    if (code.isEmpty || _busy) return;

    // The same pack still in front of the camera right after a result.
    if (!manual &&
        code == _lastCode &&
        DateTime.now().difference(_lastAt) < const Duration(seconds: 2)) {
      return;
    }

    _busy = true;
    _lastCode = code;
    HapticFeedback.mediumImpact();

    // NOTE: the camera is NOT stopped and restarted around a scan any more -
    // that stop/start cycle was the main reason scanning felt slow. The
    // _busy flag alone keeps new detections out while a sheet is open.
    if (widget.pickMode) {
      context.pop(code);
      return;
    }

    final inventory = context.read<InventoryProvider>();
    if (inventory.medicines.isEmpty) await inventory.loadMedicines();
    if (!mounted) return;

    final parsed = BarcodeParser.parse(code);
    final matches = _findMedicines(parsed, inventory.medicines, manual: manual);

    _SheetAction action = _SheetAction.none;
    Medicine? target;

    if (matches.isEmpty) {
      if (manual) {
        // Typed text that matches nothing - let the person decide.
        action = await _showNotFound(parsed) ?? _SheetAction.none;
      } else {
        // A pack we have never seen: the point of scanning is to ADD it, so
        // go straight to the new-medicine form with the barcode filled in.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            duration: Duration(seconds: 2),
            content: Text('New barcode - add this medicine.'),
          ));
        }
        action = _SheetAction.registerMedicine;
      }
    } else if (matches.length == 1) {
      target = matches.first;
    } else {
      target = await _chooseMedicine(matches);
    }

    if (target != null && mounted) {
      final found = target;
      _recent.removeWhere((r) => r.medicine.id == found.id);
      _recent.insert(0, _Recent(found, DateTime.now()));
      if (_recent.length > 4) _recent.removeLast();

      action = await _showResult(found, parsed) ?? _SheetAction.none;
    }

    if (!mounted) return;
    setState(() => _message = null);
    _manualController.clear();

    if (action == _SheetAction.openMedicine && target != null) {
      await context.push(RouteNames.medicineDetail(target.id));
    } else if (action == _SheetAction.registerBatch) {
      final q = <String, String>{
        if (target != null) 'medicine': '${target.id}',
        if (parsed.batch != null) 'batch': parsed.batch!,
        if (parsed.expiry != null)
          'expiry': DateFormat('yyyy-MM-dd').format(parsed.expiry!),
      };
      await context.push(Uri(
        path: RouteNames.createBatch,
        queryParameters: q.isEmpty ? null : q,
      ).toString());
    } else if (action == _SheetAction.registerMedicine) {
      await context.push(Uri(
        path: RouteNames.addMedicine,
        queryParameters: {'barcode': parsed.gtin ?? parsed.raw},
      ).toString());
    }

    if (!mounted) return;
    _lastAt = DateTime.now();
    _busy = false;

    // Only restart the camera if it actually stopped (e.g. it was paused by
    // the system while another screen was open).
    if (!_controller.value.isRunning) unawaited(_startCamera());
  }

  /// Exact matches on barcode/GTIN, SKU or name. Typed searches also fall
  /// back to "contains" so staff can find a medicine by part of its name.
  List<Medicine> _findMedicines(
    ParsedCode parsed,
    List<Medicine> all, {
    required bool manual,
  }) {
    final raw = parsed.raw.trim().toLowerCase();
    final exact = <Medicine>[];

    for (final m in all) {
      final byBarcode = m.barcode != null &&
          (BarcodeParser.sameProduct(m.barcode, parsed.gtin) ||
              m.barcode!.toLowerCase() == raw);

      if (byBarcode ||
          m.sku.trim().toLowerCase() == raw ||
          m.name.trim().toLowerCase() == raw) {
        exact.add(m);
      }
    }

    if (exact.isNotEmpty || !manual) return exact;

    return all.where((m) {
      return m.name.toLowerCase().contains(raw) ||
          m.genericName.toLowerCase().contains(raw) ||
          m.sku.toLowerCase().contains(raw) ||
          (m.barcode ?? '').toLowerCase().contains(raw);
    }).toList();
  }

  Future<Medicine?> _chooseMedicine(List<Medicine> list) {
    return showModalBottomSheet<Medicine>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('${list.length} medicines match',
                      style: AppTextStyles.headingSmall),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final m = list[i];
                    return ListTile(
                      leading:
                          MedicineImage(url: m.imageUrl, size: 40, radius: 10),
                      title: Text(m.name),
                      subtitle: Text('SKU ${m.sku}'),
                      trailing: Text('${m.quantity}'),
                      onTap: () => Navigator.pop(sheetContext, m),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<_SheetAction?> _showNotFound(ParsedCode parsed) {
    return showModalBottomSheet<_SheetAction>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.search_off_rounded,
                      color: AppColors.error),
                  const SizedBox(width: 8),
                  Text('Barcode not recognized',
                      style: AppTextStyles.headingSmall),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                parsed.gtin != null
                    ? 'No medicine is registered with barcode ${parsed.gtin}.'
                    : 'Nothing matches "${parsed.raw}".',
                style: AppTextStyles.bodyMedium,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () =>
                    Navigator.pop(sheetContext, _SheetAction.registerMedicine),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add as new medicine'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Navigator.pop(sheetContext, _SheetAction.none),
                child: const Text('Search manually'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<_SheetAction?> _showResult(Medicine medicine, ParsedCode parsed) {
    return showModalBottomSheet<_SheetAction>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => _ScanResultSheet(
        medicineId: medicine.id,
        parsed: parsed,
      ),
    );
  }

  // ------------------------------------------------------------------ UI

  Widget _errorPanel(Object error) {
    final detail = _technicalDetail(error);
    final denied = error is MobileScannerException &&
        error.errorCode == MobileScannerErrorCode.permissionDenied;

    return Positioned.fill(
      child: Container(
        color: AppColors.onDark.withValues(alpha: 0.0),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 8),
              const Icon(Icons.videocam_off_rounded,
                  color: Colors.white, size: 40),
              const SizedBox(height: 12),
              Text(
                _describeError(error),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _starting ? null : _retry,
                  child: Text(_starting ? 'Opening camera…' : 'Try again'),
                ),
              ),
              if (!denied) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _scanFromPicture(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera_rounded),
                    label: const Text('Take a photo of the barcode'),
                  ),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () => _scanFromPicture(ImageSource.gallery),
                  child: const Text(
                    'Choose a picture from the gallery',
                    style: TextStyle(color: AppColors.primary),
                  ),
                ),
              ],
              TextButton(
                onPressed: _manualFocus.requestFocus,
                child: const Text(
                  'Type the code instead',
                  style: TextStyle(color: AppColors.primary),
                ),
              ),
              if (detail != null) ...[
                const SizedBox(height: 6),
                SelectableText(
                  detail,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF8A908A),
                    fontSize: 10.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _roundButton({required IconData icon, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.08),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Icon(
          icon,
          size: 22,
          color: onTap == null ? Colors.white30 : Colors.white,
        ),
      ),
    );
  }

  Widget _recentScans() {
    if (_recent.isEmpty || widget.pickMode) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 14),
        Text(
          'RECENT SCANS',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        for (final r in _recent.take(2))
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _handleCode(r.medicine.sku, manual: true),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.successSoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.medication_outlined,
                        color: AppColors.primaryDeep),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.medicine.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 15.5),
                        ),
                        Text(
                          '${r.medicine.sku} · ${Formatter.timeAgo(r.at.toIso8601String())}',
                          style: AppTextStyles.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0C0B),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  _roundButton(
                    icon: Icons.close_rounded,
                    onTap: () => widget.pickMode
                        ? context.pop()
                        : context.go(RouteNames.dashboard),
                  ),
                  Expanded(
                    child: Text(
                      widget.pickMode ? 'Scan to fill barcode' : 'Scan barcode',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                  ),
                  ValueListenableBuilder<MobileScannerState>(
                    valueListenable: _controller,
                    builder: (context, state, _) {
                      final ready = state.isRunning;
                      return _roundButton(
                        icon: state.torchState == TorchState.on
                            ? Icons.flashlight_off_rounded
                            : Icons.flashlight_on_rounded,
                        onTap: ready
                            ? () async {
                                try {
                                  await _controller.toggleTorch();
                                } catch (_) {}
                              }
                            : null,
                      );
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: ValueListenableBuilder<MobileScannerState>(
                valueListenable: _controller,
                builder: (context, state, _) {
                  final error = _currentError(state);

                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        child: MobileScanner(
                          key: ValueKey(_generation),
                          controller: _controller,
                          onDetect: _onDetect,
                        ),
                      ),

                      // Viewfinder + sweeping line - only while the camera is
                      // actually showing (never drawn over the error text).
                      if (error == null)
                        Center(
                          child: SizedBox(
                            width: 250,
                            height: 250,
                            child: AnimatedBuilder(
                              animation: _scanLine,
                              builder: (context, _) => CustomPaint(
                                painter: _ScanFramePainter(
                                  progress: _scanLine.value,
                                  showLine: state.isRunning && !_busy,
                                ),
                              ),
                            ),
                          ),
                        ),

                      if (error == null)
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 14,
                          child: Text(
                            _message ??
                                (_starting && !state.isRunning
                                    ? 'Opening camera…'
                                    : (widget.pickMode
                                        ? 'Point at the medicine barcode'
                                        : 'Point at the item barcode')),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFFB9BEB9),
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),

                      // Error state: its own opaque layer, no overlap.
                      if (error != null)
                        Positioned.fill(
                          child: Container(
                            color: const Color(0xFF0B0C0B),
                            child: Stack(children: [_errorPanel(error)]),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _manualController,
                    focusNode: _manualFocus,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (v) => _handleCode(v, manual: true),
                    decoration: InputDecoration(
                      hintText: 'Or type SKU / name manually',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.arrow_forward_rounded),
                        onPressed: () =>
                            _handleCode(_manualController.text, manual: true),
                      ),
                      filled: true,
                      fillColor: AppColors.background,
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide:
                            const BorderSide(color: AppColors.primary, width: 1.4),
                      ),
                    ),
                  ),
                  if (!widget.pickMode) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => context.push(RouteNames.addMedicine),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            const Icon(Icons.add_circle_outline_rounded,
                                size: 18, color: AppColors.primaryDeep),
                            const SizedBox(width: 6),
                            const Text(
                              'Add a new medicine',
                              style: TextStyle(
                                color: AppColors.primaryDeep,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  _recentScans(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Recent {
  final Medicine medicine;
  final DateTime at;

  const _Recent(this.medicine, this.at);
}

// ======================================================================
// Result sheet: medicine + batches (FEFO) + record stock in / out
// ======================================================================

class _ScanResultSheet extends StatefulWidget {
  final int medicineId;
  final ParsedCode parsed;

  const _ScanResultSheet({required this.medicineId, required this.parsed});

  @override
  State<_ScanResultSheet> createState() => _ScanResultSheetState();
}

class _ScanResultSheetState extends State<_ScanResultSheet> {
  final _qtyController = TextEditingController(text: '1');

  // Scanning is mostly used to ADD stock, so the sheet opens on "Stock in".
  bool _isOut = false;
  String _reason = 'RECEIVED';
  int? _selectedBatchId;
  bool _saving = false;
  String? _error;
  bool _initialisedSelection = false;

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  static const _outReasons = <String, String>{
    'DISPENSED': 'Dispensed',
    'DAMAGED': 'Damaged',
    'EXPIRED': 'Expired (write-off)',
    'COUNT_DISCREPANCY': 'Stock count discrepancy',
    'CORRECTION': 'Correction',
  };

  static const _inReasons = <String, String>{
    'RECEIVED': 'Received',
    'RETURNED': 'Returned',
    'COUNT_DISCREPANCY': 'Stock count discrepancy',
    'CORRECTION': 'Correction',
  };

  // Expired stock can't be dispensed, but it CAN be written off as "Expired".
  bool _usable(Batch b) {
    if (!_isOut) return !b.isExpired;
    if (_reason == 'EXPIRED') return b.quantity > 0;
    if (_reason == 'DISPENSED') return b.isActive;
    return b.quantity > 0;
  }

  void _ensureSelection(List<Batch> sorted, Batch? lot) {
    if (_initialisedSelection) return;
    _initialisedSelection = true;

    if (lot != null && _usable(lot)) {
      _selectedBatchId = lot.id;
      return;
    }
    for (final b in sorted) {
      if (_usable(b)) {
        _selectedBatchId = b.id;
        return;
      }
    }
  }

  Future<void> _record(Medicine medicine, Batch batch) async {
    final qty = int.tryParse(_qtyController.text.trim());

    if (qty == null || qty <= 0) {
      setState(() => _error = 'Enter a quantity above 0.');
      return;
    }
    if (_isOut && qty > batch.quantity) {
      setState(() => _error = 'Only ${batch.quantity} left in this batch.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final movements = context.read<StockMovementProvider>();
    final ok = await movements.recordMovement(
      medicineId: medicine.id,
      batchId: batch.id,
      quantity: qty,
      movementType: _isOut ? 'OUT' : 'IN',
      reason: _reason,
    );

    if (!mounted) return;

    if (!ok) {
      setState(() {
        _saving = false;
        _error = movements.error ?? 'Could not record this movement.';
      });
      return;
    }

    // Close straight away and refresh in the background - waiting for the
    // reloads before closing made every scan feel slow.
    final batchProvider = context.read<BatchProvider>();
    final inventoryProvider = context.read<InventoryProvider>();
    final messenger = ScaffoldMessenger.of(context);

    Navigator.of(context).pop(_SheetAction.none);
    messenger.showSnackBar(SnackBar(
      duration: const Duration(seconds: 2),
      content: Text(
        '${(_isOut ? _outReasons : _inReasons)[_reason] ?? (_isOut ? 'Removed' : 'Received')}: '
        '$qty × ${medicine.name} (batch ${batch.batchNumber}).',
      ),
    ));

    unawaited(Future.wait([
      batchProvider.loadBatches(),
      inventoryProvider.loadMedicines(),
    ]));
  }

  @override
  Widget build(BuildContext context) {
    final inventory = context.watch<InventoryProvider>();
    final batchProvider = context.watch<BatchProvider>();

    Medicine? medicine;
    for (final m in inventory.medicines) {
      if (m.id == widget.medicineId) medicine = m;
    }
    if (medicine == null) {
      return const SizedBox(
        height: 160,
        child: Center(child: Text('Medicine not found.')),
      );
    }

    final batches = batchProvider.batches
        .where((b) => b.medicineId == medicine!.id)
        .toList()
      ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));

    final parsed = widget.parsed;
    final lot = parsed.hasBatchInfo
        ? batchProvider.findLot(medicine.id, parsed.batch!)
        : null;
    final lotMissing = parsed.hasBatchInfo && lot == null;

    _ensureSelection(batches, lot);

    Batch? selected;
    for (final b in batches) {
      if (b.id == _selectedBatchId) selected = b;
    }

    final firstFefoId =
        batches.where((b) => b.isActive).map((b) => b.id).firstOrNull;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            children: [
              Row(
                children: [
                  MedicineImage(url: medicine.imageUrl, size: 56, radius: 14),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(medicine.name, style: AppTextStyles.headingMedium),
                        if (medicine.genericName.isNotEmpty)
                          Text(medicine.genericName,
                              style: AppTextStyles.bodySmall),
                        Text(
                          'SKU ${medicine.sku}'
                          '${medicine.barcode != null ? '  ·  ${medicine.barcode}' : ''}',
                          style: AppTextStyles.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${medicine.quantity}',
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.w800)),
                      Text('in stock', style: AppTextStyles.bodySmall),
                    ],
                  ),
                ],
              ),

              if (parsed.isGs1) ...[
                const SizedBox(height: 12),
                _banner(
                  icon: Icons.qr_code_2_rounded,
                  color: AppColors.primaryDeep,
                  bg: AppColors.successSoft,
                  text: [
                    'Pack code read',
                    if (parsed.batch != null) 'lot ${parsed.batch}',
                    if (parsed.expiry != null)
                      'exp ${DateFormat('d MMM y').format(parsed.expiry!)}',
                  ].join(' · '),
                ),
              ],

              if (lot != null) ...[
                const SizedBox(height: 8),
                _banner(
                  icon: Icons.check_circle_outline_rounded,
                  color: AppColors.primaryDeep,
                  bg: AppColors.successSoft,
                  text: 'Matched registered batch ${lot.batchNumber}'
                      '${parsed.expiry != null && lot.expiry != null && DateTime(parsed.expiry!.year, parsed.expiry!.month, parsed.expiry!.day) != DateTime(lot.expiry!.year, lot.expiry!.month, lot.expiry!.day) ? ' — but the pack says a different expiry date' : ''}',
                ),
              ],

              if (lotMissing) ...[
                const SizedBox(height: 8),
                _banner(
                  icon: Icons.warning_amber_rounded,
                  color: AppColors.warning,
                  bg: AppColors.warningSoft,
                  text: 'Batch ${parsed.batch} is not registered yet.',
                  action: TextButton(
                    onPressed: () =>
                        Navigator.pop(context, _SheetAction.registerBatch),
                    child: const Text('Register it'),
                  ),
                ),
              ],

              const SizedBox(height: 16),
              Text(
                parsed.hasBatchInfo
                    ? 'Batches'
                    : 'Batches — earliest expiry first (FEFO)',
                style: AppTextStyles.headingSmall,
              ),
              const SizedBox(height: 8),

              if (batches.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    'No batches yet for this medicine.',
                    style: AppTextStyles.bodySmall,
                  ),
                )
              else
                ...batches.map((b) {
                  final usable = _usable(b);
                  final isSelected = b.id == _selectedBatchId;
                  final isFefo = b.id == firstFefoId;

                  return GestureDetector(
                    onTap: usable
                        ? () => setState(() => _selectedBatchId = b.id)
                        : null,
                    child: Opacity(
                      opacity: usable ? 1 : 0.5,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.successSoft
                              : AppColors.surface,
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.border,
                            width: isSelected ? 1.6 : 1,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected
                                  ? Icons.radio_button_checked_rounded
                                  : Icons.radio_button_off_rounded,
                              size: 20,
                              color: isSelected
                                  ? AppColors.primaryDeep
                                  : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(b.batchNumber,
                                          style: AppTextStyles.bodyMedium
                                              .copyWith(
                                                  fontWeight: FontWeight.w800)),
                                      if (isFefo && !parsed.hasBatchInfo) ...[
                                        const SizedBox(width: 6),
                                        _tag('Use first', AppColors.primaryDeep,
                                            AppColors.successSoft),
                                      ],
                                      if (lot != null && b.id == lot.id) ...[
                                        const SizedBox(width: 6),
                                        _tag('Scanned', AppColors.primaryDeep,
                                            AppColors.successSoft),
                                      ],
                                    ],
                                  ),
                                  Text(
                                    'Exp ${Formatter.date(b.expiryDate)}'
                                    '${b.isExpired ? ' · EXPIRED' : ''}'
                                    '${b.isDepleted ? ' · EMPTY' : ''}',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: b.isExpired
                                          ? AppColors.error
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text('${b.quantity}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 16)),
                          ],
                        ),
                      ),
                    ),
                  );
                }),

              if (batches.isNotEmpty) ...[
                const SizedBox(height: 10),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                        value: true,
                        icon: Icon(Icons.north_east_rounded),
                        label: Text('Dispense')),
                    ButtonSegment(
                        value: false,
                        icon: Icon(Icons.south_west_rounded),
                        label: Text('Receive')),
                  ],
                  selected: {_isOut},
                  onSelectionChanged: (s) => setState(() {
                    _isOut = s.first;
                    _reason = _isOut ? 'DISPENSED' : 'RECEIVED';
                    _initialisedSelection = false;
                    _selectedBatchId = null;
                    _ensureSelection(batches, lot);
                  }),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _reason,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Reason'),
                  items: (_isOut ? _outReasons : _inReasons)
                      .entries
                      .map((e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value)))
                      .toList(),
                  onChanged: (v) => setState(() {
                    _reason = v ?? _reason;
                    _initialisedSelection = false;
                    _selectedBatchId = null;
                  }),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _qtyController,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Quantity'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: (_saving || selected == null)
                            ? null
                            : () => _record(medicine!, selected!),
                        child: _saving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : Text(_isOut
                                ? (_reason == 'DISPENSED'
                                    ? 'Record dispense'
                                    : 'Record removal')
                                : 'Record receipt'),
                      ),
                    ),
                  ],
                ),
                if (selected == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _isOut
                          ? (_reason == 'DISPENSED'
                              ? 'No in-date stock available to dispense.'
                              : 'No stock in any batch to remove.')
                          : 'No valid batch to receive into — create a new batch.',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.error),
                    ),
                  ),
              ],

              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_error!,
                      style: const TextStyle(color: AppColors.error)),
                ),

              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          Navigator.pop(context, _SheetAction.openMedicine),
                      child: const Text('Open medicine'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          Navigator.pop(context, _SheetAction.registerBatch),
                      child: const Text('New batch'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tag(String text, Color fg, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w800, color: fg)),
      );

  Widget _banner({
    required IconData icon,
    required Color color,
    required Color bg,
    required String text,
    Widget? action,
  }) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text,
                  style: TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w700, color: color)),
            ),
            if (action != null) action,
          ],
        ),
      );
}

// ======================================================================

class _ScanFramePainter extends CustomPainter {
  final double progress;
  final bool showLine;

  _ScanFramePainter({required this.progress, required this.showLine});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    // Rounded corner brackets, like the design.
    const len = 46.0;
    const r = 22.0;
    final w = size.width, h = size.height;

    // top-left
    canvas.drawPath(
      Path()
        ..moveTo(0, len)
        ..lineTo(0, r)
        ..quadraticBezierTo(0, 0, r, 0)
        ..lineTo(len, 0),
      paint,
    );
    // top-right
    canvas.drawPath(
      Path()
        ..moveTo(w - len, 0)
        ..lineTo(w - r, 0)
        ..quadraticBezierTo(w, 0, w, r)
        ..lineTo(w, len),
      paint,
    );
    // bottom-left
    canvas.drawPath(
      Path()
        ..moveTo(0, h - len)
        ..lineTo(0, h - r)
        ..quadraticBezierTo(0, h, r, h)
        ..lineTo(len, h),
      paint,
    );
    // bottom-right
    canvas.drawPath(
      Path()
        ..moveTo(w - len, h)
        ..lineTo(w - r, h)
        ..quadraticBezierTo(w, h, w, h - r)
        ..lineTo(w, h - len),
      paint,
    );

    if (showLine) {
      final y = 10 + (size.height - 20) * progress;
      canvas.drawLine(
        Offset(10, y),
        Offset(size.width - 10, y),
        Paint()
          ..color = AppColors.primary.withValues(alpha: 0.9)
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ScanFramePainter old) =>
      old.progress != progress || old.showLine != showLine;
}
