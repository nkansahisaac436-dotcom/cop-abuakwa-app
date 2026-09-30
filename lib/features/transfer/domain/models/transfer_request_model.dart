enum TransferStatus {
  pending('pending'),
  approved('approved'),
  rejected('rejected');

  final String value;
  const TransferStatus(this.value);

  static TransferStatus fromString(String? val) {
    return TransferStatus.values.firstWhere(
      (s) => s.value == val,
      orElse: () => TransferStatus.pending,
    );
  }
}

class TransferRequestModel {
  final String id;
  final String pastorId;
  final String? pastorName;
  final String? pastorEmail;
  final String tenureId;
  final String? districtName;
  final DateTime requestedAt;
  final TransferStatus status;
  final String? decidedBy;
  final DateTime? decidedAt;
  final String? note;

  const TransferRequestModel({
    required this.id,
    required this.pastorId,
    this.pastorName,
    this.pastorEmail,
    required this.tenureId,
    this.districtName,
    required this.requestedAt,
    this.status = TransferStatus.pending,
    this.decidedBy,
    this.decidedAt,
    this.note,
  });

  bool get isPending => status == TransferStatus.pending;
  bool get isApproved => status == TransferStatus.approved;
  bool get isRejected => status == TransferStatus.rejected;

  factory TransferRequestModel.fromJson(Map<String, dynamic> json) {
    return TransferRequestModel(
      id: json['id'] as String,
      pastorId: json['pastor_id'] as String,
      pastorName: json['pastor_name'] as String?,
      pastorEmail: json['pastor_email'] as String?,
      tenureId: json['tenure_id'] as String,
      districtName: json['district_name'] as String?,
      requestedAt: json['requested_at'] != null
          ? DateTime.parse(json['requested_at'] as String)
          : DateTime.now(),
      status: TransferStatus.fromString(json['status'] as String?),
      decidedBy: json['decided_by'] as String?,
      decidedAt: json['decided_at'] != null
          ? DateTime.parse(json['decided_at'] as String)
          : null,
      note: json['note'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pastor_id': pastorId,
      'tenure_id': tenureId,
      'requested_at': requestedAt.toIso8601String(),
      'status': status.value,
      'decided_by': decidedBy,
      'decided_at': decidedAt?.toIso8601String(),
      'note': note,
    };
  }
}
