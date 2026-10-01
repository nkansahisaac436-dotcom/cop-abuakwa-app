import 'profile_model.dart';

class InviteModel {
  final String id;
  final String code;
  final UserRole role;
  final String targetName;
  final String? districtId;
  final String? districtName;
  final String? ministryId;
  final String? ministryName;
  final String status; // pending, redeemed, cancelled, expired
  final DateTime createdAt;
  final DateTime expiresAt;
  final String? redeemedBy;
  final DateTime? redeemedAt;

  const InviteModel({
    required this.id,
    required this.code,
    required this.role,
    required this.targetName,
    this.districtId,
    this.districtName,
    this.ministryId,
    this.ministryName,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    this.redeemedBy,
    this.redeemedAt,
  });

  bool get isPending => status == 'pending' && expiresAt.isAfter(DateTime.now());
  bool get isRedeemed => status == 'redeemed';
  bool get isCancelled => status == 'cancelled';
  bool get isExpired => status == 'expired' || (status == 'pending' && expiresAt.isBefore(DateTime.now()));

  String get roleDisplay {
    switch (role) {
      case UserRole.pastor:
        return 'Pastor, ${districtName ?? 'Assigned District'}';
      case UserRole.ministryLeader:
        return 'Ministry Leader, ${ministryName ?? 'Assigned Ministry'}';
      default:
        return role.label;
    }
  }

  factory InviteModel.fromJson(Map<String, dynamic> json) {
    return InviteModel(
      id: json['id'] as String? ?? '',
      code: json['code_display'] as String? ?? json['code'] as String? ?? '',
      role: UserRole.fromString(json['role'] as String? ?? 'member'),
      targetName: json['target_name'] as String? ?? '',
      districtId: json['district_id'] as String?,
      districtName: json['district_name'] as String?,
      ministryId: json['ministry_id'] as String?,
      ministryName: json['ministry_name'] as String?,
      status: json['status'] as String? ?? 'pending',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
      expiresAt: json['expires_at'] != null ? DateTime.parse(json['expires_at'] as String) : DateTime.now().add(const Duration(days: 7)),
      redeemedBy: json['redeemed_by'] as String?,
      redeemedAt: json['redeemed_at'] != null ? DateTime.parse(json['redeemed_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code_display': code,
      'role': role.name,
      'target_name': targetName,
      'district_id': districtId,
      'district_name': districtName,
      'ministry_id': ministryId,
      'ministry_name': ministryName,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
      'redeemed_by': redeemedBy,
      'redeemed_at': redeemedAt?.toIso8601String(),
    };
  }
}
