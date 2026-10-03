// `flutter/foundation.dart` also exports a `Category` test-annotation class
// (from package:meta) which collides with our own Category model — hide it.
import 'package:flutter/foundation.dart' hide Category;

import '../models/category.dart';
import '../services/category_service.dart';

class CategoryProvider extends ChangeNotifier {
  List<Category> _categories = [];
  bool _isLoading = false;
  String? _error;

  List<Category> get categories => List.unmodifiable(_categories);
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadCategories() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _categories = await CategoryService.getCategories();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await loadCategories();
  }

  /// Creates a category and adds it to the local list on success.
  Future<Category?> createCategory({
    required String name,
    String description = '',
  }) async {
    try {
      final category = await CategoryService.createCategory(
        name: name,
        description: description,
      );

      _categories = [..._categories, category];
      notifyListeners();

      return category;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  String nameFor(int categoryId) {
    for (final category in _categories) {
      if (category.id == categoryId) return category.name;
    }
    return 'Uncategorised';
  }
}
