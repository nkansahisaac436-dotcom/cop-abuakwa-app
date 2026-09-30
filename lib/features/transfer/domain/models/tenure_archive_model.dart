class TenureArchiveModel {
  final String id;
  final String tenureId;
  final String title; // e.g. "Pastor Enoch Agyemang, 2021-2026"
  final Map<String, dynamic> summaryJson;
  final String? pdfUrl;
  final DateTime createdAt;

  const TenureArchiveModel({
    required this.id,
    required this.tenureId,
    required this.title,
    required this.summaryJson,
    this.pdfUrl,
    required this.createdAt,
  });

  String get pastorName => summaryJson['pastor_name'] as String? ?? '';
  String get districtName => summaryJson['district_name'] as String? ?? '';
  int get totalProjects => (summaryJson['total_projects'] as num?)?.toInt() ?? 0;
  int get totalEvents => (summaryJson['total_events'] as num?)?.toInt() ?? 0;
  int get totalUpdates => (summaryJson['total_updates'] as num?)?.toInt() ?? 0;
  int get totalThoughts => (summaryJson['total_thoughts'] as num?)?.toInt() ?? 0;

  factory TenureArchiveModel.fromJson(Map<String, dynamic> json) {
    return TenureArchiveModel(
      id: json['id'] as String,
      tenureId: json['tenure_id'] as String,
      title: json['title'] as String,
      summaryJson: json['summary_json'] is Map<String, dynamic>
          ? json['summary_json'] as Map<String, dynamic>
          : {},
      pdfUrl: json['pdf_url'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenure_id': tenureId,
      'title': title,
      'summary_json': summaryJson,
      'pdf_url': pdfUrl,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
