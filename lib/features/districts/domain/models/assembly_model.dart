class AssemblyModel {
  final String id;
  final String districtId;
  final String name;
  final bool isActive;
  final String? locationText;
  final DateTime createdAt;

  const AssemblyModel({
    required this.id,
    required this.districtId,
    required this.name,
    this.isActive = true,
    this.locationText,
    required this.createdAt,
  });

  factory AssemblyModel.fromJson(Map<String, dynamic> json) {
    return AssemblyModel(
      id: json['id'] as String,
      districtId: json['district_id'] as String,
      name: json['name'] as String,
      isActive: json['is_active'] as bool? ?? true,
      locationText: json['location_text'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'district_id': districtId,
      'name': name,
      'is_active': isActive,
      'location_text': locationText,
      'created_at': createdAt.toIso8601String(),
    };
  }

  AssemblyModel copyWith({
    String? id,
    String? districtId,
    String? name,
    bool? isActive,
    String? locationText,
    DateTime? createdAt,
  }) {
    return AssemblyModel(
      id: id ?? this.id,
      districtId: districtId ?? this.districtId,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
      locationText: locationText ?? this.locationText,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
