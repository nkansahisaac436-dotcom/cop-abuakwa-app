enum ProjectType {
  project('project'),
  event('event');

  final String value;
  const ProjectType(this.value);

  static ProjectType fromString(String? val) {
    return ProjectType.values.firstWhere(
      (t) => t.value == val,
      orElse: () => ProjectType.project,
    );
  }
}

enum ProjectStatus {
  planned('planned'),
  ongoing('ongoing'),
  completed('completed');

  final String value;
  const ProjectStatus(this.value);

  static ProjectStatus fromString(String? val) {
    return ProjectStatus.values.firstWhere(
      (s) => s.value == val,
      orElse: () => ProjectStatus.planned,
    );
  }
}

enum VisibilityLevel {
  public('public', 'Anyone with the app, including public members'),
  members('members', 'Any logged-in church user'),
  pastors('pastors', 'Pastors and the Area Head only'),
  areaHead('area_head', 'Area Head office only');

  final String value;
  final String description;
  const VisibilityLevel(this.value, this.description);

  static VisibilityLevel fromString(String? val) {
    return VisibilityLevel.values.firstWhere(
      (v) => v.value == val,
      orElse: () => VisibilityLevel.members,
    );
  }
}

class ProjectModel {
  final String id;
  final String districtId;
  final String? districtName;
  final String? assemblyId;
  final String? assemblyName;
  final String? tenureId;
  final String title;
  final String description;
  final ProjectType type;
  final ProjectStatus status;
  final int progressPct;
  final double? lat;
  final double? lng;
  final DateTime? startDate;
  final DateTime? endDate;
  final VisibilityLevel visibility;
  final String? createdBy;
  final String? authorName;
  final List<String> photoUrls;
  final DateTime createdAt;

  const ProjectModel({
    required this.id,
    required this.districtId,
    this.districtName,
    this.assemblyId,
    this.assemblyName,
    this.tenureId,
    required this.title,
    required this.description,
    this.type = ProjectType.project,
    this.status = ProjectStatus.planned,
    this.progressPct = 0,
    this.lat,
    this.lng,
    this.startDate,
    this.endDate,
    this.visibility = VisibilityLevel.members,
    this.createdBy,
    this.authorName,
    this.photoUrls = const [],
    required this.createdAt,
  });

  bool get isEvent => type == ProjectType.event;
  bool get isProject => type == ProjectType.project;

  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    return ProjectModel(
      id: json['id'] as String,
      districtId: json['district_id'] as String,
      districtName: json['district_name'] as String?,
      assemblyId: json['assembly_id'] as String?,
      assemblyName: json['assembly_name'] as String?,
      tenureId: json['tenure_id'] as String?,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      type: ProjectType.fromString(json['type'] as String?),
      status: ProjectStatus.fromString(json['status'] as String?),
      progressPct: (json['progress_pct'] as num?)?.toInt() ?? 0,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      startDate: json['start_date'] != null
          ? DateTime.parse(json['start_date'] as String)
          : null,
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'] as String)
          : null,
      visibility: VisibilityLevel.fromString(json['visibility'] as String?),
      createdBy: json['created_by'] as String?,
      authorName: json['author_name'] as String?,
      photoUrls: (json['photo_urls'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'district_id': districtId,
      'assembly_id': assemblyId,
      'tenure_id': tenureId,
      'title': title,
      'description': description,
      'type': type.value,
      'status': status.value,
      'progress_pct': progressPct,
      'lat': lat,
      'lng': lng,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'visibility': visibility.value,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
