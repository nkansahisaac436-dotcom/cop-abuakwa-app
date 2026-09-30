enum DistrictStatus {
  inactive('inactive'),
  active('active');

  final String value;
  const DistrictStatus(this.value);

  static DistrictStatus fromString(String? val) {
    return DistrictStatus.values.firstWhere(
      (s) => s.value == val,
      orElse: () => DistrictStatus.inactive,
    );
  }
}

class DistrictModel {
  final String id;
  final String name;
  final DistrictStatus status;
  final String? activatedBy;
  final DateTime? activatedAt;
  final DateTime createdAt;

  const DistrictModel({
    required this.id,
    required this.name,
    this.status = DistrictStatus.inactive,
    this.activatedBy,
    this.activatedAt,
    required this.createdAt,
  });

  bool get isActive => status == DistrictStatus.active;
  bool get isInactive => status == DistrictStatus.inactive;

  factory DistrictModel.fromJson(Map<String, dynamic> json) {
    return DistrictModel(
      id: json['id'] as String,
      name: json['name'] as String,
      status: DistrictStatus.fromString(json['status'] as String?),
      activatedBy: json['activated_by'] as String?,
      activatedAt: json['activated_at'] != null
          ? DateTime.parse(json['activated_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'status': status.value,
      'activated_by': activatedBy,
      'activated_at': activatedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  DistrictModel copyWith({
    String? id,
    String? name,
    DistrictStatus? status,
    String? activatedBy,
    DateTime? activatedAt,
    DateTime? createdAt,
  }) {
    return DistrictModel(
      id: id ?? this.id,
      name: name ?? this.name,
      status: status ?? this.status,
      activatedBy: activatedBy ?? this.activatedBy,
      activatedAt: activatedAt ?? this.activatedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
