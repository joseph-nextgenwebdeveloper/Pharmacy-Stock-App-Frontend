class Medicine {
  final int id;
  final String name;
  final String genericName;
  final String description;
  final int quantity;
  final int categoryId;
  final String sku;
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
    this.imageUrl,
  });

  factory Medicine.fromJson(
    Map<String, dynamic> json,
  ) {
    return Medicine(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      genericName: json['generic_name'] ?? '',
      description: json['description'] ?? '',
      quantity: json['quantity'] ?? 0,
      categoryId: json['category'] ?? 0,
      sku: json['sku'] ?? '',
      units: json['units'] ?? '',
      reorderLevel: json['reorder_level'] ?? 0,
      // Not on the backend yet — this reads whichever key you add
      // (ImageField serializes as "image" by default in DRF) so the UI
      // picks it up automatically once it exists, no app change needed.
      imageUrl: (json['image'] as String?) ?? (json['image_url'] as String?),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'generic_name': genericName,
      'description': description,
      'category': categoryId,
      'sku': sku,
      'units': units,
      'reorder_level': reorderLevel,
    };
  }
}