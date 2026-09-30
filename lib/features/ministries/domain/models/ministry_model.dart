class MinistryModel {
  final String id;
  final String name;
  final String code;
  final String? description;
  final String? iconName;
  final DateTime createdAt;
  final bool isFollowed;

  const MinistryModel({
    required this.id,
    required this.name,
    required this.code,
    this.description,
    this.iconName,
    required this.createdAt,
    this.isFollowed = false,
  });

  factory MinistryModel.fromJson(Map<String, dynamic> json, {bool isFollowed = false}) {
    return MinistryModel(
      id: json['id'] as String,
      name: json['name'] as String,
      code: json['code'] as String? ?? json['name'].toString().toLowerCase(),
      description: json['description'] as String?,
      iconName: json['icon_name'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      isFollowed: isFollowed,
    );
  }

  MinistryModel copyWith({
    String? id,
    String? name,
    String? code,
    String? description,
    String? iconName,
    DateTime? createdAt,
    bool? isFollowed,
  }) {
    return MinistryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      description: description ?? this.description,
      iconName: iconName ?? this.iconName,
      createdAt: createdAt ?? this.createdAt,
      isFollowed: isFollowed ?? this.isFollowed,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'description': description,
      'icon_name': iconName,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
