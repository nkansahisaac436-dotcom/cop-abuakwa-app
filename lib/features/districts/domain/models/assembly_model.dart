class AssemblyModel {
  final String id;
  final String districtId;
  final String name;
  final String? locationText;
  final DateTime createdAt;

  const AssemblyModel({
    required this.id,
    required this.districtId,
    required this.name,
    this.locationText,
    required this.createdAt,
  });

  factory AssemblyModel.fromJson(Map<String, dynamic> json) {
    return AssemblyModel(
      id: json['id'] as String,
      districtId: json['district_id'] as String,
      name: json['name'] as String,
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
      'location_text': locationText,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
