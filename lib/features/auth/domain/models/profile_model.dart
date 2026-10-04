import '../../../districts/domain/models/district_model.dart';

enum UserRole {
  areaHead('area_head'),
  pastor('pastor'),
  ministryLeader('ministry_leader'),
  member('member');

  final String value;
  const UserRole(this.value);

  String get label {
    switch (this) {
      case UserRole.areaHead:
        return 'Area Head';
      case UserRole.pastor:
        return 'Pastor';
      case UserRole.ministryLeader:
        return 'Ministry Leader';
      case UserRole.member:
        return 'Member';
    }
  }

  static UserRole fromString(String? val) {
    return UserRole.values.firstWhere(
      (r) => r.value == val,
      orElse: () => UserRole.member,
    );
  }
}

enum ProfileStatus {
  active('active'),
  transferred('transferred'),
  suspended('suspended');

  final String value;
  const ProfileStatus(this.value);

  static ProfileStatus fromString(String? val) {
    return ProfileStatus.values.firstWhere(
      (s) => s.value == val,
      orElse: () => ProfileStatus.active,
    );
  }
}

class UserProfile {
  final String id;
  final String fullName;
  final String email;
  final String? phone;
  final UserRole role;
  final ProfileStatus status;
  final String? districtId;
  final String? districtName;
  final DistrictStatus? districtStatus;
  final String? assemblyId;
  final String? ministryName;
  final String? avatarUrl;
  final bool dataConsentAccepted;
  final DateTime createdAt;

  const UserProfile({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone,
    this.role = UserRole.member,
    this.status = ProfileStatus.active,
    this.districtId,
    this.districtName,
    this.districtStatus,
    this.assemblyId,
    this.ministryName,
    this.avatarUrl,
    this.dataConsentAccepted = true,
    required this.createdAt,
  });

  bool get isAreaHead => role == UserRole.areaHead;
  bool get isPastor => role == UserRole.pastor;
  bool get isMinistryLeader => role == UserRole.ministryLeader;
  bool get isMember => role == UserRole.member;
  bool get isTransferred => status == ProfileStatus.transferred;

  UserProfile copyWith({
    String? id,
    String? fullName,
    String? email,
    String? phone,
    UserRole? role,
    ProfileStatus? status,
    String? districtId,
    String? districtName,
    DistrictStatus? districtStatus,
    String? assemblyId,
    String? ministryName,
    String? avatarUrl,
    bool? dataConsentAccepted,
    DateTime? createdAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      status: status ?? this.status,
      districtId: districtId ?? this.districtId,
      districtName: districtName ?? this.districtName,
      districtStatus: districtStatus ?? this.districtStatus,
      assemblyId: assemblyId ?? this.assemblyId,
      ministryName: ministryName ?? this.ministryName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      dataConsentAccepted: dataConsentAccepted ?? this.dataConsentAccepted,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    String? dName = json['district_name'] as String?;
    DistrictStatus? dStatus;

    if (json['districts'] != null && json['districts'] is Map) {
      final dMap = json['districts'] as Map<String, dynamic>;
      dName ??= dMap['name'] as String?;
      dStatus = DistrictStatus.fromString(dMap['status'] as String?);
    } else if (json['district_status'] != null) {
      dStatus = DistrictStatus.fromString(json['district_status'] as String?);
    }

    return UserProfile(
      id: json['id'] as String,
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String?,
      role: UserRole.fromString(json['role'] as String?),
      status: ProfileStatus.fromString(json['status'] as String?),
      districtId: json['district_id'] as String?,
      districtName: dName,
      districtStatus: dStatus,
      assemblyId: json['assembly_id'] as String?,
      ministryName: json['ministry_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      dataConsentAccepted: json['data_consent_accepted'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'role': role.value,
      'status': status.value,
      'district_id': districtId,
      'district_name': districtName,
      'district_status': districtStatus?.value,
      'assembly_id': assemblyId,
      'ministry_name': ministryName,
      'avatar_url': avatarUrl,
      'data_consent_accepted': dataConsentAccepted,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
