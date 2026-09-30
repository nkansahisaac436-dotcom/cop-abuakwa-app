import 'package:cop_abuakwa_app/features/auth/domain/models/profile_model.dart';

class MeetingModel {
  final String id;
  final String title;
  final String roomLink;
  final DateTime scheduledAt;
  final UserRole audience;
  final String createdBy;
  final String? creatorName;
  final DateTime createdAt;

  const MeetingModel({
    required this.id,
    required this.title,
    required this.roomLink,
    required this.scheduledAt,
    this.audience = UserRole.pastor,
    required this.createdBy,
    this.creatorName,
    required this.createdAt,
  });

  factory MeetingModel.fromJson(Map<String, dynamic> json) {
    return MeetingModel(
      id: json['id'] as String,
      title: json['title'] as String,
      roomLink: json['room_link'] as String,
      scheduledAt: DateTime.parse(json['scheduled_at'] as String),
      audience: UserRole.fromString(json['audience'] as String?),
      createdBy: json['created_by'] as String,
      creatorName: json['creator_name'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'room_link': roomLink,
      'scheduled_at': scheduledAt.toIso8601String(),
      'audience': audience.value,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
