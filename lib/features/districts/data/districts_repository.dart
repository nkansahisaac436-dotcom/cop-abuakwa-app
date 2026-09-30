import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/network/supabase_client.dart';
import '../domain/models/assembly_model.dart';
import '../domain/models/district_model.dart';

abstract class DistrictsRepository {
  Future<List<DistrictModel>> getDistricts();
  Future<List<AssemblyModel>> getAssembliesForDistrict(String districtId);
  Future<void> activateDistrict(String districtId, String activatedByUserId);
  Future<void> deactivateDistrict(String districtId);
}

class SupabaseDistrictsRepository implements DistrictsRepository {
  final SupabaseClient? _client;

  SupabaseDistrictsRepository([this._client]);

  SupabaseClient get _sb => _client ?? SupabaseConfig.client;

  // Local fallback cache for offline or demo use
  static final List<DistrictModel> _mockDistricts = [
    DistrictModel(id: 'd0000000-0000-0000-0000-000000000001', name: 'Abuakwa Central', status: DistrictStatus.inactive, createdAt: DateTime(2026, 1, 1)),
    DistrictModel(id: 'd0000000-0000-0000-0000-000000000002', name: 'Abuakwa North', status: DistrictStatus.active, createdAt: DateTime(2026, 1, 1)),
    DistrictModel(id: 'd0000000-0000-0000-0000-000000000003', name: 'Abuakwa South', status: DistrictStatus.active, createdAt: DateTime(2026, 1, 1)),
    DistrictModel(id: 'd0000000-0000-0000-0000-000000000004', name: 'Tanoso', status: DistrictStatus.active, createdAt: DateTime(2026, 1, 1)),
    DistrictModel(id: 'd0000000-0000-0000-0000-000000000005', name: 'Akropong', status: DistrictStatus.active, createdAt: DateTime(2026, 1, 1)),
    DistrictModel(id: 'd0000000-0000-0000-0000-000000000006', name: 'Sepaase', status: DistrictStatus.inactive, createdAt: DateTime(2026, 1, 1)),
    DistrictModel(id: 'd0000000-0000-0000-0000-000000000007', name: 'Nkawie', status: DistrictStatus.inactive, createdAt: DateTime(2026, 1, 1)),
    DistrictModel(id: 'd0000000-0000-0000-0000-000000000008', name: 'Toase', status: DistrictStatus.inactive, createdAt: DateTime(2026, 1, 1)),
    DistrictModel(id: 'd0000000-0000-0000-0000-000000000009', name: 'Nyinahini', status: DistrictStatus.inactive, createdAt: DateTime(2026, 1, 1)),
    DistrictModel(id: 'd0000000-0000-0000-0000-000000000010', name: 'Barekese', status: DistrictStatus.inactive, createdAt: DateTime(2026, 1, 1)),
    DistrictModel(id: 'd0000000-0000-0000-0000-000000000011', name: 'Asuofua', status: DistrictStatus.inactive, createdAt: DateTime(2026, 1, 1)),
    DistrictModel(id: 'd0000000-0000-0000-0000-000000000012', name: 'Atwima Koforidua', status: DistrictStatus.inactive, createdAt: DateTime(2026, 1, 1)),
    DistrictModel(id: 'd0000000-0000-0000-0000-000000000013', name: 'Denkyemuoso', status: DistrictStatus.inactive, createdAt: DateTime(2026, 1, 1)),
    DistrictModel(id: 'd0000000-0000-0000-0000-000000000014', name: 'Agogo - Abuakwa', status: DistrictStatus.inactive, createdAt: DateTime(2026, 1, 1)),
    DistrictModel(id: 'd0000000-0000-0000-0000-000000000015', name: 'Nwabiagya East', status: DistrictStatus.inactive, createdAt: DateTime(2026, 1, 1)),
    DistrictModel(id: 'd0000000-0000-0000-0000-000000000016', name: 'Nwabiagya South', status: DistrictStatus.inactive, createdAt: DateTime(2026, 1, 1)),
    DistrictModel(id: 'd0000000-0000-0000-0000-000000000017', name: 'Mpasatia', status: DistrictStatus.inactive, createdAt: DateTime(2026, 1, 1)),
    DistrictModel(id: 'd0000000-0000-0000-0000-000000000018', name: 'Agogo Central', status: DistrictStatus.inactive, createdAt: DateTime(2026, 1, 1)),
    DistrictModel(id: 'd0000000-0000-0000-0000-000000000019', name: 'Achiase', status: DistrictStatus.inactive, createdAt: DateTime(2026, 1, 1)),
    DistrictModel(id: 'd0000000-0000-0000-0000-000000000020', name: 'Manhyia - Abuakwa', status: DistrictStatus.inactive, createdAt: DateTime(2026, 1, 1)),
    DistrictModel(id: 'd0000000-0000-0000-0000-000000000021', name: 'Bokankye', status: DistrictStatus.inactive, createdAt: DateTime(2026, 1, 1)),
    DistrictModel(id: 'd0000000-0000-0000-0000-000000000022', name: 'Fufuo', status: DistrictStatus.inactive, createdAt: DateTime(2026, 1, 1)),
    DistrictModel(id: 'd0000000-0000-0000-0000-000000000023', name: 'Amanchia', status: DistrictStatus.inactive, createdAt: DateTime(2026, 1, 1)),
    DistrictModel(id: 'd0000000-0000-0000-0000-000000000024', name: 'Adankwame', status: DistrictStatus.inactive, createdAt: DateTime(2026, 1, 1)),
    DistrictModel(id: 'd0000000-0000-0000-0000-000000000025', name: 'Darbaa', status: DistrictStatus.inactive, createdAt: DateTime(2026, 1, 1)),
    DistrictModel(id: 'd0000000-0000-0000-0000-000000000026', name: 'Adwumakase', status: DistrictStatus.inactive, createdAt: DateTime(2026, 1, 1)),
    DistrictModel(id: 'd0000000-0000-0000-0000-000000000027', name: 'Asakraka', status: DistrictStatus.inactive, createdAt: DateTime(2026, 1, 1)),
    DistrictModel(id: 'd0000000-0000-0000-0000-000000000028', name: 'Hiawu Besease', status: DistrictStatus.inactive, createdAt: DateTime(2026, 1, 1)),
    DistrictModel(id: 'd0000000-0000-0000-0000-000000000029', name: 'Tabere', status: DistrictStatus.inactive, createdAt: DateTime(2026, 1, 1)),
    DistrictModel(id: 'd0000000-0000-0000-0000-000000000030', name: 'Owhim', status: DistrictStatus.inactive, createdAt: DateTime(2026, 1, 1)),
    DistrictModel(id: 'd0000000-0000-0000-0000-000000000031', name: 'Ntobroso', status: DistrictStatus.inactive, createdAt: DateTime(2026, 1, 1)),
    DistrictModel(id: 'd0000000-0000-0000-0000-000000000032', name: 'Gyankobaa', status: DistrictStatus.inactive, createdAt: DateTime(2026, 1, 1)),
    DistrictModel(id: 'd0000000-0000-0000-0000-000000000033', name: 'Dabaa New Site', status: DistrictStatus.inactive, createdAt: DateTime(2026, 1, 1)),
  ];

  static final Map<String, List<AssemblyModel>> _mockAssemblies = {
    'd0000000-0000-0000-0000-000000000001': [
      AssemblyModel(id: 'a-1', districtId: 'd0000000-0000-0000-0000-000000000001', name: 'Central Assembly', locationText: 'Abuakwa Main Road', createdAt: DateTime.now()),
      AssemblyModel(id: 'a-2', districtId: 'd0000000-0000-0000-0000-000000000001', name: 'Bethel Assembly', locationText: 'Abuakwa Block 4', createdAt: DateTime.now()),
      AssemblyModel(id: 'a-3', districtId: 'd0000000-0000-0000-0000-000000000001', name: 'Emmanuel Assembly', locationText: 'Abuakwa Low Cost', createdAt: DateTime.now()),
      AssemblyModel(id: 'a-4', districtId: 'd0000000-0000-0000-0000-000000000001', name: 'Grace Assembly', locationText: 'Abuakwa Housing Area', createdAt: DateTime.now()),
    ],
    'd0000000-0000-0000-0000-000000000002': [
      AssemblyModel(id: 'a-5', districtId: 'd0000000-0000-0000-0000-000000000002', name: 'Peniel Assembly', locationText: 'North Abuakwa Junction', createdAt: DateTime.now()),
      AssemblyModel(id: 'a-6', districtId: 'd0000000-0000-0000-0000-000000000002', name: 'Shalom Assembly', locationText: 'Near Presby School', createdAt: DateTime.now()),
    ],
    'd0000000-0000-0000-0000-000000000003': [
      AssemblyModel(id: 'a-7', districtId: 'd0000000-0000-0000-0000-000000000003', name: 'Calvary Assembly', locationText: 'Abuakwa South Station', createdAt: DateTime.now()),
      AssemblyModel(id: 'a-8', districtId: 'd0000000-0000-0000-0000-000000000003', name: 'Hebron Assembly', locationText: 'South Bypass Road', createdAt: DateTime.now()),
    ],
    'd0000000-0000-0000-0000-000000000004': [
      AssemblyModel(id: 'a-9', districtId: 'd0000000-0000-0000-0000-000000000004', name: 'Tanoso Central Assembly', locationText: 'Tanoso Main Highway', createdAt: DateTime.now()),
      AssemblyModel(id: 'a-10', districtId: 'd0000000-0000-0000-0000-000000000004', name: 'Moriah Assembly', locationText: 'Tanoso New Site', createdAt: DateTime.now()),
    ],
    'd0000000-0000-0000-0000-000000000005': [
      AssemblyModel(id: 'a-11', districtId: 'd0000000-0000-0000-0000-000000000005', name: 'Akropong Central Assembly', locationText: 'Akropong Market Area', createdAt: DateTime.now()),
      AssemblyModel(id: 'a-12', districtId: 'd0000000-0000-0000-0000-000000000005', name: 'Rehoboth Assembly', locationText: 'Akropong Hill View', createdAt: DateTime.now()),
    ],
  };

  @override
  Future<List<DistrictModel>> getDistricts() async {
    if (!SupabaseConfig.isInitialized) {
      return List.unmodifiable(_mockDistricts);
    }
    try {
      final res = await _sb.from('districts').select().order('name');
      return (res as List).map((json) => DistrictModel.fromJson(json)).toList();
    } catch (e) {
      debugPrint('[DistrictsRepository] Error fetching districts: $e. Falling back to local cache.');
      return List.unmodifiable(_mockDistricts);
    }
  }

  @override
  Future<List<AssemblyModel>> getAssembliesForDistrict(String districtId) async {
    if (!SupabaseConfig.isInitialized) {
      return _mockAssemblies[districtId] ?? [
        AssemblyModel(
          id: 'mock-gen-$districtId',
          districtId: districtId,
          name: 'Central Assembly',
          locationText: 'Main Town Road',
          createdAt: DateTime.now(),
        ),
      ];
    }
    try {
      final res = await _sb.from('assemblies').select().eq('district_id', districtId).order('name');
      return (res as List).map((json) => AssemblyModel.fromJson(json)).toList();
    } catch (e) {
      debugPrint('[DistrictsRepository] Error fetching assemblies: $e');
      return _mockAssemblies[districtId] ?? [];
    }
  }

  @override
  Future<void> activateDistrict(String districtId, String activatedByUserId) async {
    final idx = _mockDistricts.indexWhere((d) => d.id == districtId);
    if (idx != -1) {
      _mockDistricts[idx] = _mockDistricts[idx].copyWith(
        status: DistrictStatus.active,
        activatedBy: activatedByUserId,
        activatedAt: DateTime.now(),
      );
    }

    if (SupabaseConfig.isInitialized) {
      await _sb.from('districts').update({
        'status': DistrictStatus.active.value,
        'activated_by': activatedByUserId,
        'activated_at': DateTime.now().toIso8601String(),
      }).eq('id', districtId);
    }
  }

  @override
  Future<void> deactivateDistrict(String districtId) async {
    final idx = _mockDistricts.indexWhere((d) => d.id == districtId);
    if (idx != -1) {
      _mockDistricts[idx] = _mockDistricts[idx].copyWith(
        status: DistrictStatus.inactive,
        activatedBy: null,
        activatedAt: null,
      );
    }

    if (SupabaseConfig.isInitialized) {
      await _sb.from('districts').update({
        'status': DistrictStatus.inactive.value,
        'activated_by': null,
        'activated_at': null,
      }).eq('id', districtId);
    }
  }
}
