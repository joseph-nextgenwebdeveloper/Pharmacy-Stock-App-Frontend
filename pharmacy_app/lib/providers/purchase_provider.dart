import 'package:flutter/foundation.dart';

import '../models/goods_received.dart';
import '../services/goods_received_service.dart';

class PurchaseProvider extends ChangeNotifier {
  List<GoodsReceived> _goodsReceived = [];
  bool _isLoading = false;
  bool _hydrated = false;
  String? _error;

  List<GoodsReceived> get goodsReceived =>
      List.unmodifiable(_goodsReceived);

  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadGoodsReceived() async {
    if (!_hydrated) {
      _hydrated = true;
      final cached = await GoodsReceivedService.getCachedGoodsReceived();
      if (_goodsReceived.isEmpty && cached.isNotEmpty) {
        _goodsReceived = cached;
        notifyListeners();
      }
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _goodsReceived =
          await GoodsReceivedService.getGoodsReceived();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<GoodsReceived?> getGoodsReceivedDetail(
    int id,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      return await GoodsReceivedService.getGoodsReceivedDetail(id);
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createGoodsReceived(
    GoodsReceived goodsReceived,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final createdGoodsReceived =
          await GoodsReceivedService.createGoodsReceived(
        goodsReceived,
      );

      _goodsReceived.insert(0, createdGoodsReceived);
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await loadGoodsReceived();
  }

  void reset() {
    _goodsReceived = [];
    _hydrated = false;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
