enum DistrictStatus {
  pending('pending'),
  active('active'),
  rejected('rejected'),
  inactive('inactive');

  final String value;
  const DistrictStatus(this.value);

  static DistrictStatus fromString(String? val) {
    return DistrictStatus.values.firstWhere(
      (s) => s.value == val,
      orElse: () => DistrictStatus.pending,
    );
  }
}

class DistrictModel {
  final String id;
  final String name;
  final DistrictStatus status;
  final String? registeredBy;
  final DateTime? submittedAt;
  final String? decidedBy;
  final DateTime? decidedAt;
  final String? decisionNote;
  final String? activatedBy;
  final DateTime? activatedAt;
  final DateTime createdAt;

  // Joined presentation fields (optional)
  final String? pastorName;
  final String? pastorPhotoUrl;
  final List<String>? assemblyNames;

  const DistrictModel({
    required this.id,
    required this.name,
    this.status = DistrictStatus.pending,
    this.registeredBy,
    this.submittedAt,
    this.decidedBy,
    this.decidedAt,
    this.decisionNote,
    this.activatedBy,
    this.activatedAt,
    required this.createdAt,
    this.pastorName,
    this.pastorPhotoUrl,
    this.assemblyNames,
  });

  bool get isPending => status == DistrictStatus.pending;
  bool get isActive => status == DistrictStatus.active;
  bool get isRejected => status == DistrictStatus.rejected;
  bool get isInactive => status == DistrictStatus.inactive;

  factory DistrictModel.fromJson(Map<String, dynamic> json) {
    // Check if pastor profile was joined
    String? pName;
    String? pPhoto;
    if (json['profiles'] != null && json['profiles'] is Map) {
      final pMap = json['profiles'] as Map<String, dynamic>;
      pName = pMap['full_name'] as String?;
      pPhoto = pMap['avatar_url'] as String?;
    } else if (json['pastor_name'] != null) {
      pName = json['pastor_name'] as String?;
      pPhoto = json['pastor_photo_url'] as String?;
    }

    List<String>? assemblies;
    if (json['assemblies'] != null && json['assemblies'] is List) {
      assemblies = (json['assemblies'] as List)
          .map((a) => a is Map ? (a['name'] as String? ?? '') : a.toString())
          .where((s) => s.isNotEmpty)
          .toList();
    } else if (json['assembly_names'] != null && json['assembly_names'] is List) {
      assemblies = List<String>.from(json['assembly_names'] as List);
    }

    return DistrictModel(
      id: json['id'] as String,
      name: json['name'] as String,
      status: DistrictStatus.fromString(json['status'] as String?),
      registeredBy: json['registered_by'] as String?,
      submittedAt: json['submitted_at'] != null
          ? DateTime.tryParse(json['submitted_at'] as String)
          : null,
      decidedBy: json['decided_by'] as String?,
      decidedAt: json['decided_at'] != null
          ? DateTime.tryParse(json['decided_at'] as String)
          : null,
      decisionNote: json['decision_note'] as String?,
      activatedBy: json['activated_by'] as String?,
      activatedAt: json['activated_at'] != null
          ? DateTime.tryParse(json['activated_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      pastorName: pName,
      pastorPhotoUrl: pPhoto,
      assemblyNames: assemblies,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'status': status.value,
      'registered_by': registeredBy,
      'submitted_at': submittedAt?.toIso8601String(),
      'decided_by': decidedBy,
      'decided_at': decidedAt?.toIso8601String(),
      'decision_note': decisionNote,
      'activated_by': activatedBy,
      'activated_at': activatedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  DistrictModel copyWith({
    String? id,
    String? name,
    DistrictStatus? status,
    String? registeredBy,
    DateTime? submittedAt,
    String? decidedBy,
    DateTime? decidedAt,
    String? decisionNote,
    String? activatedBy,
    DateTime? activatedAt,
    DateTime? createdAt,
    String? pastorName,
    String? pastorPhotoUrl,
    List<String>? assemblyNames,
  }) {
    return DistrictModel(
      id: id ?? this.id,
      name: name ?? this.name,
      status: status ?? this.status,
      registeredBy: registeredBy ?? this.registeredBy,
      submittedAt: submittedAt ?? this.submittedAt,
      decidedBy: decidedBy ?? this.decidedBy,
      decidedAt: decidedAt ?? this.decidedAt,
      decisionNote: decisionNote ?? this.decisionNote,
      activatedBy: activatedBy ?? this.activatedBy,
      activatedAt: activatedAt ?? this.activatedAt,
      createdAt: createdAt ?? this.createdAt,
      pastorName: pastorName ?? this.pastorName,
      pastorPhotoUrl: pastorPhotoUrl ?? this.pastorPhotoUrl,
      assemblyNames: assemblyNames ?? this.assemblyNames,
    );
  }
}
