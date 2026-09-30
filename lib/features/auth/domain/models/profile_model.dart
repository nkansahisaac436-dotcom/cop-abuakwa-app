enum UserRole {
  areaHead('area_head'),
  pastor('pastor'),
  ministryLeader('ministry_leader'),
  member('member');

  final String value;
  const UserRole(this.value);

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
  final String? assemblyId;
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
    this.assemblyId,
    this.avatarUrl,
    this.dataConsentAccepted = true,
    required this.createdAt,
  });

  bool get isAreaHead => role == UserRole.areaHead;
  bool get isPastor => role == UserRole.pastor;
  bool get isMinistryLeader => role == UserRole.ministryLeader;
  bool get isMember => role == UserRole.member;
  bool get isTransferred => status == ProfileStatus.transferred;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String?,
      role: UserRole.fromString(json['role'] as String?),
      status: ProfileStatus.fromString(json['status'] as String?),
      districtId: json['district_id'] as String?,
      assemblyId: json['assembly_id'] as String?,
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
      'assembly_id': assemblyId,
      'avatar_url': avatarUrl,
      'data_consent_accepted': dataConsentAccepted,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
