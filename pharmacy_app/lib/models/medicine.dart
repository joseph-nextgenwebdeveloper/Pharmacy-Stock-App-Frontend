class Medicine {
  final int id;
  final String name;
  final String genericName;
  final String description;
  final int categoryId;
  final String sku;
  final String barcode;
  final String units;
  final int reorderLevel;

  const Medicine({
    required this.id,
    required this.name,
    required this.genericName,
    required this.description,
    required this.categoryId,
    required this.sku,
    required this.barcode,
    required this.units,
    required this.reorderLevel,
  });

  factory Medicine.fromJson(Map<String, dynamic> json) {
    return Medicine(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      genericName: json['generic_name'] ?? '',
      description: json['description'] ?? '',
      categoryId: json['category'] ?? 0,
      sku: json['sku'] ?? '',
      barcode: json['barcode'] ?? '',
      units: json['units'] ?? '',
      reorderLevel: json['reorder_level'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'generic_name': genericName,
      'description': description,
      'category': categoryId,
      'sku': sku,
      'barcode': barcode,
      'units': units,
      'reorder_level': reorderLevel,
    };
  }
}