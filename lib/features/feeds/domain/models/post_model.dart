import 'package:cop_abuakwa_app/features/projects/domain/models/project_model.dart';

enum PostType {
  announcement('announcement', 'Area Announcement'),
  thought('thought', 'Pastoral Thought / Reflection'),
  news('news', 'Ministry or District News');

  final String value;
  final String label;
  const PostType(this.value, this.label);

  static PostType fromString(String? val) {
    return PostType.values.firstWhere(
      (t) => t.value == val,
      orElse: () => PostType.news,
    );
  }
}

class PostModel {
  final String id;
  final String authorId;
  final String? authorName;
  final String? authorRole;
  final PostType type;
  final String title;
  final String body;
  final VisibilityLevel visibility;
  final String? ministryId;
  final String? ministryName;
  final String? districtId;
  final String? districtName;
  final String? tenureId;
  final List<String> mediaUrls;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const PostModel({
    required this.id,
    required this.authorId,
    this.authorName,
    this.authorRole,
    this.type = PostType.news,
    required this.title,
    required this.body,
    this.visibility = VisibilityLevel.public,
    this.ministryId,
    this.ministryName,
    this.districtId,
    this.districtName,
    this.tenureId,
    this.mediaUrls = const [],
    required this.createdAt,
    this.updatedAt,
  });

  bool get isAnnouncement => type == PostType.announcement;
  bool get isThought => type == PostType.thought;

  factory PostModel.fromJson(Map<String, dynamic> json) {
    return PostModel(
      id: json['id'] as String,
      authorId: json['author_id'] as String,
      authorName: json['author_name'] as String?,
      authorRole: json['author_role'] as String?,
      type: PostType.fromString(json['type'] as String?),
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      visibility: VisibilityLevel.fromString(json['visibility'] as String?),
      ministryId: json['ministry_id'] as String?,
      ministryName: json['ministry_name'] as String?,
      districtId: json['district_id'] as String?,
      districtName: json['district_name'] as String?,
      tenureId: json['tenure_id'] as String?,
      mediaUrls: (json['media_urls'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'author_id': authorId,
      'type': type.value,
      'title': title,
      'body': body,
      'visibility': visibility.value,
      'ministry_id': ministryId,
      'district_id': districtId,
      'tenure_id': tenureId,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
