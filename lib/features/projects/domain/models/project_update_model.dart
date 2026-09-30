class ProjectUpdateModel {
  final String id;
  final String projectId;
  final String note;
  final int progressPct;
  final String? createdBy;
  final String? authorName;
  final List<String> photoUrls;
  final DateTime createdAt;

  const ProjectUpdateModel({
    required this.id,
    required this.projectId,
    required this.note,
    required this.progressPct,
    this.createdBy,
    this.authorName,
    this.photoUrls = const [],
    required this.createdAt,
  });

  factory ProjectUpdateModel.fromJson(Map<String, dynamic> json) {
    return ProjectUpdateModel(
      id: json['id'] as String,
      projectId: json['project_id'] as String,
      note: json['note'] as String,
      progressPct: (json['progress_pct'] as num).toInt(),
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
      'project_id': projectId,
      'note': note,
      'progress_pct': progressPct,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
