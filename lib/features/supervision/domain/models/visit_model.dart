import 'package:cop_abuakwa_app/features/projects/domain/models/project_model.dart';

class VisitModel {
  final String id;
  final String? projectId;
  final String? projectTitle;
  final String? districtId;
  final String? districtName;
  final String visitedBy;
  final String? visitorName;
  final DateTime visitDate;
  final String notes;
  final VisibilityLevel visibility;
  final DateTime createdAt;

  const VisitModel({
    required this.id,
    this.projectId,
    this.projectTitle,
    this.districtId,
    this.districtName,
    required this.visitedBy,
    this.visitorName,
    required this.visitDate,
    required this.notes,
    this.visibility = VisibilityLevel.areaHead,
    required this.createdAt,
  });

  factory VisitModel.fromJson(Map<String, dynamic> json) {
    return VisitModel(
      id: json['id'] as String,
      projectId: json['project_id'] as String?,
      projectTitle: json['project_title'] as String?,
      districtId: json['district_id'] as String?,
      districtName: json['district_name'] as String?,
      visitedBy: json['visited_by'] as String,
      visitorName: json['visitor_name'] as String?,
      visitDate: json['visit_date'] != null
          ? DateTime.parse(json['visit_date'] as String)
          : DateTime.now(),
      notes: json['notes'] as String? ?? '',
      visibility: VisibilityLevel.fromString(json['visibility'] as String?),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'project_id': projectId,
      'district_id': districtId,
      'visited_by': visitedBy,
      'visit_date': visitDate.toIso8601String(),
      'notes': notes,
      'visibility': visibility.value,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
