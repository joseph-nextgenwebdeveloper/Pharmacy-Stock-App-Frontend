class Supplier {
  final int id;
  final String name;
  final String companyName;
  final String contactPerson;
  final String email;
  final String phoneNumber;
  final String address;
  final bool isActive;
  final String createdAt;
  final String updatedAt;

  const Supplier({
    required this.id,
    required this.name,
    required this.companyName,
    required this.contactPerson,
    required this.email,
    required this.phoneNumber,
    required this.address,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Supplier.fromJson(Map<String, dynamic> json) {
    return Supplier(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      companyName: json['company_name'] ?? '',
      contactPerson: json['contact_person'] ?? '',
      email: json['email'] ?? '',
      phoneNumber: json['phone_number'] ?? '',
      address: json['address'] ?? '',
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'company_name': companyName,
      'contact_person': contactPerson,
      'email': email,
      'phone_number': phoneNumber,
      'address': address,
      'is_active': isActive,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}