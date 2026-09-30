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

  static final List<VisitModel> _mockVisits = [
    VisitModel(
      id: 'vis-1',
      districtId: 'd0000000-0000-0000-0000-000000000004',
      districtName: 'Tanoso District',
      projectId: 'proj-2',
      projectTitle: 'Youth Chapel Auditorium Expansion',
      visitedBy: 'mock-area-head-id',
      visitorName: 'Apostle Area Head',
      visitDate: DateTime.now().subtract(const Duration(days: 2)),
      notes: 'Conducted field supervision of the youth chapel project. Contractor on site. Advised pastor on proper auditing of building levy.',
      visibility: VisibilityLevel.areaHead,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
  ];

  @override
  Future<List<VisitModel>> getVisits({String? districtId}) async {
    if (!SupabaseConfig.isInitialized) {
      if (districtId != null) {
        return _mockVisits.where((v) => v.districtId == districtId).toList();
      }
      return List.unmodifiable(_mockVisits);
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
      return _mockVisits;
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

    _mockVisits.insert(0, newVisit);

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
