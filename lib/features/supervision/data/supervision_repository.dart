import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/network/supabase_client.dart';
import '../../projects/domain/models/project_model.dart';
import '../domain/models/visit_model.dart';

abstract class SupervisionRepository {
  Future<List<VisitModel>> getVisits({String? districtId});
  Future<VisitModel> logVisit({
    String? projectId,
    String? districtId,
    required String visitedBy,
    required String visitorName,
    required DateTime visitDate,
    required String notes,
    VisibilityLevel visibility = VisibilityLevel.areaHead,
  });
}

class SupabaseSupervisionRepository implements SupervisionRepository {
  final SupabaseClient? _client;

  SupabaseSupervisionRepository([this._client]);

  SupabaseClient get _sb => _client ?? SupabaseConfig.client;

  // In-memory runtime storage for offline / mock testing (starts empty)
  static final List<VisitModel> _inMemoryVisits = [];

  static void resetState() {
    _inMemoryVisits.clear();
  }

  @override
  Future<List<VisitModel>> getVisits({String? districtId}) async {
    if (!SupabaseConfig.isInitialized) {
      if (districtId != null) {
        return _inMemoryVisits.where((v) => v.districtId == districtId).toList();
      }
      return List.unmodifiable(_inMemoryVisits);
    }

    try {
      var query = _sb.from('visits').select();
      if (districtId != null) {
        query = query.eq('district_id', districtId);
      }
      final res = await query.order('visit_date', ascending: false);
      return (res as List).map((j) => VisitModel.fromJson(j)).toList();
    } catch (e) {
      debugPrint('[SupervisionRepository] Error fetching visits: $e');
      return _inMemoryVisits;
    }
  }

  @override
  Future<VisitModel> logVisit({
    String? projectId,
    String? districtId,
    required String visitedBy,
    required String visitorName,
    required DateTime visitDate,
    required String notes,
    VisibilityLevel visibility = VisibilityLevel.areaHead,
  }) async {
    final newVisit = VisitModel(
      id: 'vis-${DateTime.now().millisecondsSinceEpoch}',
      projectId: projectId,
      districtId: districtId,
      visitedBy: visitedBy,
      visitorName: visitorName,
      visitDate: visitDate,
      notes: notes.trim(),
      visibility: visibility,
      createdAt: DateTime.now(),
    );

    _inMemoryVisits.insert(0, newVisit);

    if (SupabaseConfig.isInitialized) {
      try {
        await _sb.from('visits').insert(newVisit.toJson());
      } catch (e) {
        debugPrint('[SupervisionRepository] Error saving visit: $e');
      }
    }

    return newVisit;
  }
}
