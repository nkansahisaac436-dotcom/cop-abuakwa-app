import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/network/supabase_client.dart';
import '../domain/models/tenure_archive_model.dart';
import '../domain/models/transfer_request_model.dart';

abstract class TransferRepository {
  Future<TransferRequestModel> requestTransfer({
    required String pastorId,
    required String tenureId,
  });
  Future<List<TransferRequestModel>> getPendingTransferRequests();
  Future<void> approveTransfer({
    required String requestId,
    required String decidedByUserId,
    String? note,
  });
  Future<void> rejectTransfer({
    required String requestId,
    required String decidedByUserId,
    required String note,
  });
  Future<List<TenureArchiveModel>> getArchives({String? searchQuery});
  Future<TenureArchiveModel?> getArchiveDetail(String archiveId);
}

class SupabaseTransferRepository implements TransferRepository {
  final SupabaseClient? _client;

  SupabaseTransferRepository([this._client]);

  SupabaseClient get _sb => _client ?? SupabaseConfig.client;

  static final List<TransferRequestModel> _mockRequests = [
    TransferRequestModel(
      id: 'req-1',
      pastorId: 'mock-pastor-id',
      pastorName: 'Pastor Enoch Agyemang',
      pastorEmail: 'pastor@copabuakwa.org',
      tenureId: 't0000000-0000-0000-0000-000000000001',
      districtName: 'Abuakwa North',
      requestedAt: DateTime.now().subtract(const Duration(hours: 4)),
      status: TransferStatus.pending,
    ),
  ];

  static final List<TenureArchiveModel> _mockArchives = [
    TenureArchiveModel(
      id: 'arch-1',
      tenureId: 't0000000-0000-0000-0000-000000000099',
      title: 'Pastor Enoch Agyemang, 2021-2026',
      summaryJson: {
        'pastor_name': 'Pastor Enoch Agyemang',
        'pastor_email': 'pastor@copabuakwa.org',
        'district_name': 'Abuakwa North',
        'start_date': '2021-09-01',
        'end_date': '2026-09-30',
        'total_projects': 4,
        'total_events': 14,
        'total_updates': 32,
        'total_thoughts': 18,
        'projects_summary': [
          {'title': 'Peniel Mission House Construction', 'status': 'ongoing', 'progress_pct': 65},
          {'title': 'North Abuakwa Children Block', 'status': 'completed', 'progress_pct': 100},
          {'title': 'District Bus Acquisition', 'status': 'completed', 'progress_pct': 100},
        ],
        'thoughts_summary': [
          {'title': 'Leading with Endurance in Ministry', 'created_at': '2026-09-29'},
          {'title': 'Fostering Prayer in Local Assemblies', 'created_at': '2026-08-15'},
        ],
      },
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
    ),
  ];

  @override
  Future<TransferRequestModel> requestTransfer({
    required String pastorId,
    required String tenureId,
  }) async {
    final newReq = TransferRequestModel(
      id: 'req-${DateTime.now().millisecondsSinceEpoch}',
      pastorId: pastorId,
      pastorName: 'Pastor',
      tenureId: tenureId,
      requestedAt: DateTime.now(),
      status: TransferStatus.pending,
    );

    _mockRequests.insert(0, newReq);

    if (SupabaseConfig.isInitialized) {
      try {
        final res = await _sb.from('transfer_requests').insert({
          'pastor_id': pastorId,
          'tenure_id': tenureId,
          'status': 'pending',
        }).select().single();
        return TransferRequestModel.fromJson(res);
      } catch (e) {
        debugPrint('[TransferRepository] Error creating transfer request: $e');
      }
    }

    return newReq;
  }

  @override
  Future<List<TransferRequestModel>> getPendingTransferRequests() async {
    if (!SupabaseConfig.isInitialized) {
      return _mockRequests.where((r) => r.isPending).toList();
    }
    try {
      final res = await _sb
          .from('transfer_requests')
          .select('*, profiles(full_name, email)')
          .eq('status', 'pending')
          .order('requested_at', ascending: false);

      return (res as List).map((j) {
        final profile = j['profiles'];
        final map = Map<String, dynamic>.from(j);
        if (profile != null) {
          map['pastor_name'] = profile['full_name'];
          map['pastor_email'] = profile['email'];
        }
        return TransferRequestModel.fromJson(map);
      }).toList();
    } catch (e) {
      debugPrint('[TransferRepository] Error fetching requests: $e');
      return _mockRequests.where((r) => r.isPending).toList();
    }
  }

  @override
  Future<void> approveTransfer({
    required String requestId,
    required String decidedByUserId,
    String? note,
  }) async {
    // 1. Update mock records
    final reqIdx = _mockRequests.indexWhere((r) => r.id == requestId);
    if (reqIdx != -1) {
      final req = _mockRequests[reqIdx];
      _mockRequests[reqIdx] = TransferRequestModel(
        id: req.id,
        pastorId: req.pastorId,
        pastorName: req.pastorName,
        pastorEmail: req.pastorEmail,
        tenureId: req.tenureId,
        districtName: req.districtName,
        requestedAt: req.requestedAt,
        status: TransferStatus.approved,
        decidedBy: decidedByUserId,
        decidedAt: DateTime.now(),
        note: note,
      );

      // Create Mock Tenure Archive row titled "Pastor <Full Name>, <startYear>-<endYear>"
      final currentYear = DateTime.now().year;
      final startYear = currentYear - 4;
      final archiveTitle = 'Pastor ${req.pastorName ?? "Minister"}, $startYear-$currentYear';

      _mockArchives.insert(
        0,
        TenureArchiveModel(
          id: 'arch-${DateTime.now().millisecondsSinceEpoch}',
          tenureId: req.tenureId,
          title: archiveTitle,
          summaryJson: {
            'pastor_name': req.pastorName,
            'pastor_email': req.pastorEmail,
            'district_name': req.districtName ?? 'District',
            'start_date': '$startYear-09-01',
            'end_date': DateTime.now().toIso8601String().substring(0, 10),
            'total_projects': 3,
            'total_events': 8,
            'total_updates': 18,
            'total_thoughts': 12,
          },
          createdAt: DateTime.now(),
        ),
      );
    }

    // 2. Call Supabase Atomic Procedure
    if (SupabaseConfig.isInitialized) {
      try {
        await _sb.rpc('approve_pastor_transfer', params: {
          'p_request_id': requestId,
          'p_decided_by': decidedByUserId,
          'p_note': note,
        });
      } catch (e) {
        debugPrint('[TransferRepository] Error calling approve_pastor_transfer: $e');
      }
    }
  }

  @override
  Future<void> rejectTransfer({
    required String requestId,
    required String decidedByUserId,
    required String note,
  }) async {
    final reqIdx = _mockRequests.indexWhere((r) => r.id == requestId);
    if (reqIdx != -1) {
      final req = _mockRequests[reqIdx];
      _mockRequests[reqIdx] = TransferRequestModel(
        id: req.id,
        pastorId: req.pastorId,
        pastorName: req.pastorName,
        pastorEmail: req.pastorEmail,
        tenureId: req.tenureId,
        districtName: req.districtName,
        requestedAt: req.requestedAt,
        status: TransferStatus.rejected,
        decidedBy: decidedByUserId,
        decidedAt: DateTime.now(),
        note: note,
      );
    }

    if (SupabaseConfig.isInitialized) {
      try {
        await _sb.from('transfer_requests').update({
          'status': 'rejected',
          'decided_by': decidedByUserId,
          'decided_at': DateTime.now().toIso8601String(),
          'note': note,
        }).eq('id', requestId);
      } catch (e) {
        debugPrint('[TransferRepository] Error rejecting request: $e');
      }
    }
  }

  @override
  Future<List<TenureArchiveModel>> getArchives({String? searchQuery}) async {
    if (!SupabaseConfig.isInitialized) {
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        return _mockArchives.where((a) {
          return a.title.toLowerCase().contains(query) ||
              a.pastorName.toLowerCase().contains(query) ||
              a.districtName.toLowerCase().contains(query);
        }).toList();
      }
      return List.unmodifiable(_mockArchives);
    }

    try {
      final res = await _sb.from('tenure_archives').select().order('created_at', ascending: false);
      final list = (res as List).map((j) => TenureArchiveModel.fromJson(j)).toList();

      if (searchQuery != null && searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        return list.where((a) {
          return a.title.toLowerCase().contains(query) ||
              a.pastorName.toLowerCase().contains(query) ||
              a.districtName.toLowerCase().contains(query);
        }).toList();
      }

      return list;
    } catch (e) {
      debugPrint('[TransferRepository] Error fetching archives: $e');
      return _mockArchives;
    }
  }

  @override
  Future<TenureArchiveModel?> getArchiveDetail(String archiveId) async {
    if (!SupabaseConfig.isInitialized) {
      return _mockArchives.firstWhere(
        (a) => a.id == archiveId,
        orElse: () => _mockArchives.first,
      );
    }

    try {
      final res = await _sb.from('tenure_archives').select().eq('id', archiveId).maybeSingle();
      if (res == null) return null;
      return TenureArchiveModel.fromJson(res);
    } catch (e) {
      debugPrint('[TransferRepository] Error fetching archive detail: $e');
      return null;
    }
  }
}
