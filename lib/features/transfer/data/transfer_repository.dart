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

  // In-memory runtime storage for offline / mock testing (starts empty)
  static final List<TransferRequestModel> _inMemoryRequests = [];
  static final List<TenureArchiveModel> _inMemoryArchives = [];

  static void resetState() {
    _inMemoryRequests.clear();
    _inMemoryArchives.clear();
  }

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

    _inMemoryRequests.insert(0, newReq);

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
      return _inMemoryRequests.where((r) => r.isPending).toList();
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
      return _inMemoryRequests.where((r) => r.isPending).toList();
    }
  }

  @override
  Future<void> approveTransfer({
    required String requestId,
    required String decidedByUserId,
    String? note,
  }) async {
    final reqIdx = _inMemoryRequests.indexWhere((r) => r.id == requestId);
    if (reqIdx != -1) {
      final req = _inMemoryRequests[reqIdx];
      _inMemoryRequests[reqIdx] = TransferRequestModel(
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

      final currentYear = DateTime.now().year;
      final startYear = currentYear - 4;
      final archiveTitle = 'Pastor ${req.pastorName ?? "Minister"}, $startYear-$currentYear';

      _inMemoryArchives.insert(
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
            'total_projects': 0,
            'total_events': 0,
            'total_updates': 0,
            'total_thoughts': 0,
          },
          createdAt: DateTime.now(),
        ),
      );
    }

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
    final reqIdx = _inMemoryRequests.indexWhere((r) => r.id == requestId);
    if (reqIdx != -1) {
      final req = _inMemoryRequests[reqIdx];
      _inMemoryRequests[reqIdx] = TransferRequestModel(
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
        return _inMemoryArchives.where((a) {
          return a.title.toLowerCase().contains(query) ||
              a.pastorName.toLowerCase().contains(query) ||
              a.districtName.toLowerCase().contains(query);
        }).toList();
      }
      return List.unmodifiable(_inMemoryArchives);
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
      return _inMemoryArchives;
    }
  }

  @override
  Future<TenureArchiveModel?> getArchiveDetail(String archiveId) async {
    if (!SupabaseConfig.isInitialized) {
      return _inMemoryArchives.firstWhere(
        (a) => a.id == archiveId,
        orElse: () => _inMemoryArchives.first,
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
