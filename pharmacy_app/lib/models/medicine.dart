import '../config/app_environment.dart';

class Medicine {
  final int id;
  final String name;
  final String genericName;
  final String description;
  final int quantity;
  final int categoryId;
  final String sku;

  /// Manufacturer barcode / GTIN printed on the pack (not the internal SKU).
  final String? barcode;
  final String units;
  final int reorderLevel;
  final String? imageUrl;

  const Medicine({
    required this.id,
    required this.name,
    required this.genericName,
    required this.description,
    required this.quantity,
    required this.categoryId,
    required this.sku,
    required this.units,
    required this.reorderLevel,
    this.barcode,
    this.imageUrl,
  });

  /// The API origin without the trailing "/api", e.g.
  /// https://pharmacy-stock-app-backend.onrender.com
  static String get _origin =>
      AppEnvironment.apiBaseUrl.replaceFirst(RegExp(r'/api/?$'), '');

  /// Makes whatever the backend returns usable by Image.network:
  ///  * relative "/media/..." paths get the API origin prepended;
  ///  * "http://" URLs for our own host are upgraded to https (Android
  ///    blocks cleartext http, which silently produced a broken image).
  static String? resolveImageUrl(String? raw) {
    if (raw == null) return null;
    final value = raw.trim();
    if (value.isEmpty) return null;

    if (value.startsWith('/')) return '$_origin$value';

    final host = Uri.tryParse(_origin)?.host;
    if (value.startsWith('http://') && host != null && value.contains(host)) {
      return value.replaceFirst('http://', 'https://');
    }

    return value;
  }

  factory Medicine.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawBarcode = (json['barcode'] as String?)?.trim();

    return Medicine(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      genericName: json['generic_name'] ?? '',
      description: json['description'] ?? '',
      quantity: json['quantity'] ?? 0,
      categoryId: json['category'] ?? 0,
      sku: json['sku'] ?? '',
      barcode: (rawBarcode == null || rawBarcode.isEmpty) ? null : rawBarcode,
      units: json['units'] ?? '',
      reorderLevel: json['reorder_level'] ?? 0,
      imageUrl: resolveImageUrl(
        (json['image'] as String?) ?? (json['image_url'] as String?),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'generic_name': genericName,
      'description': description,
      'category': categoryId,
      'sku': sku,
      if (barcode != null && barcode!.isNotEmpty) 'barcode': barcode,
      'units': units,
      'reorder_level': reorderLevel,
    };
  }
}
