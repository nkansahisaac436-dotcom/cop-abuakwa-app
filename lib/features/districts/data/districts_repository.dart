import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/network/supabase_client.dart';
import '../domain/models/assembly_model.dart';
import '../domain/models/district_model.dart';

abstract class DistrictsRepository {
  Future<List<DistrictModel>> getDistricts();
  Future<List<DistrictModel>> getActiveDistricts();
  Future<DistrictModel?> getDistrictById(String districtId);
  Future<List<AssemblyModel>> getAssembliesForDistrict(String districtId);
  Future<DistrictModel> registerDistrict({
    required String name,
    required List<String> assemblies,
    required DateTime startDate,
  });
  Future<DistrictModel> resubmitDistrict({
    required String districtId,
    required String name,
    required List<String> assemblies,
    required DateTime startDate,
  });
  Future<void> approveDistrict(String districtId, {String? note});
  Future<void> rejectDistrict(String districtId, {required String note});
  Future<DistrictModel> addDistrictDirectly({
    required String name,
    required List<String> assemblies,
  });
  Future<void> activateDistrict(String districtId, String activatedByUserId);
  Future<void> deactivateDistrict(String districtId);
}

class SupabaseDistrictsRepository implements DistrictsRepository {
  final SupabaseClient? _client;

  SupabaseDistrictsRepository([this._client]);

  SupabaseClient get _sb => _client ?? SupabaseConfig.client;

  // In-memory runtime storage for offline / mock testing (starts empty)
  static final List<DistrictModel> _inMemoryDistricts = [];
  static final Map<String, List<AssemblyModel>> _inMemoryAssemblies = {};

  static void resetState() {
    _inMemoryDistricts.clear();
    _inMemoryAssemblies.clear();
  }

  static String _normalize(String input) {
    return input.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  @override
  Future<List<DistrictModel>> getDistricts() async {
    if (!SupabaseConfig.isInitialized) {
      return List.unmodifiable(_inMemoryDistricts);
    }
    try {
      final res = await _sb
          .from('districts')
          .select('*, profiles:registered_by(full_name, avatar_url), assemblies(name)')
          .order('name');
      return (res as List).map((json) => DistrictModel.fromJson(json)).toList();
    } catch (e) {
      debugPrint('[DistrictsRepository] Error fetching districts: $e');
      return List.unmodifiable(_inMemoryDistricts);
    }
  }

  @override
  Future<List<DistrictModel>> getActiveDistricts() async {
    final all = await getDistricts();
    return all.where((d) => d.isActive).toList();
  }

  @override
  Future<DistrictModel?> getDistrictById(String districtId) async {
    if (!SupabaseConfig.isInitialized) {
      return _inMemoryDistricts.cast<DistrictModel?>().firstWhere(
        (d) => d?.id == districtId,
        orElse: () => null,
      );
    }
    try {
      final res = await _sb
          .from('districts')
          .select('*, profiles:registered_by(full_name, avatar_url), assemblies(name)')
          .eq('id', districtId)
          .maybeSingle();
      if (res == null) return null;
      return DistrictModel.fromJson(res);
    } catch (e) {
      debugPrint('[DistrictsRepository] Error fetching district by id: $e');
      return null;
    }
  }

  @override
  Future<List<AssemblyModel>> getAssembliesForDistrict(String districtId) async {
    if (!SupabaseConfig.isInitialized) {
      return _inMemoryAssemblies[districtId] ?? [];
    }
    try {
      final res = await _sb
          .from('assemblies')
          .select()
          .eq('district_id', districtId)
          .order('name');
      return (res as List).map((json) => AssemblyModel.fromJson(json)).toList();
    } catch (e) {
      debugPrint('[DistrictsRepository] Error fetching assemblies: $e');
      return _inMemoryAssemblies[districtId] ?? [];
    }
  }

  @override
  Future<DistrictModel> registerDistrict({
    required String name,
    required List<String> assemblies,
    required DateTime startDate,
  }) async {
    final cleanName = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (cleanName.length < 2) {
      throw Exception('Please enter a valid district name.');
    }

    // Check duplicate name
    final existingDistricts = await getDistricts();
    final isDuplicate = existingDistricts.any((d) => _normalize(d.name) == _normalize(cleanName));
    if (isDuplicate) {
      throw Exception('This district is already registered. Contact the Area Head office.');
    }

    if (!SupabaseConfig.isInitialized) {
      final districtId = 'dist-${DateTime.now().millisecondsSinceEpoch}';
      final newDistrict = DistrictModel(
        id: districtId,
        name: cleanName,
        status: DistrictStatus.pending,
        submittedAt: DateTime.now(),
        createdAt: DateTime.now(),
        assemblyNames: assemblies,
      );
      _inMemoryDistricts.insert(0, newDistrict);

      final asmList = assemblies.map((asmName) => AssemblyModel(
        id: 'asm-${DateTime.now().microsecondsSinceEpoch}-$asmName',
        districtId: districtId,
        name: asmName.trim(),
        createdAt: DateTime.now(),
      )).toList();
      _inMemoryAssemblies[districtId] = asmList;

      return newDistrict;
    }

    try {
      final res = await _sb.rpc('register_district_by_pastor', params: {
        'p_name': cleanName,
        'p_assemblies': assemblies,
        'p_start_date': startDate.toIso8601String().split('T').first,
      });

      final distId = res['district_id'] as String;
      final dist = await getDistrictById(distId);
      return dist ??
          DistrictModel(
            id: distId,
            name: cleanName,
            status: DistrictStatus.pending,
            submittedAt: DateTime.now(),
            createdAt: DateTime.now(),
            assemblyNames: assemblies,
          );
    } catch (e) {
      final errStr = e.toString().replaceAll('Exception: ', '');
      if (errStr.contains('already registered')) {
        throw Exception('This district is already registered. Contact the Area Head office.');
      }
      rethrow;
    }
  }

  @override
  Future<DistrictModel> resubmitDistrict({
    required String districtId,
    required String name,
    required List<String> assemblies,
    required DateTime startDate,
  }) async {
    final cleanName = name.trim().replaceAll(RegExp(r'\s+'), ' ');

    if (!SupabaseConfig.isInitialized) {
      final idx = _inMemoryDistricts.indexWhere((d) => d.id == districtId);
      final updated = DistrictModel(
        id: districtId,
        name: cleanName,
        status: DistrictStatus.pending,
        submittedAt: DateTime.now(),
        decisionNote: null,
        decidedBy: null,
        decidedAt: null,
        createdAt: DateTime.now(),
        assemblyNames: assemblies,
      );
      if (idx != -1) {
        _inMemoryDistricts[idx] = updated;
      } else {
        _inMemoryDistricts.add(updated);
      }

      final asmList = assemblies.map((asmName) => AssemblyModel(
        id: 'asm-${DateTime.now().microsecondsSinceEpoch}-$asmName',
        districtId: districtId,
        name: asmName.trim(),
        createdAt: DateTime.now(),
      )).toList();
      _inMemoryAssemblies[districtId] = asmList;

      return updated;
    }

    try {
      await _sb.from('districts').update({
        'name': cleanName,
        'status': DistrictStatus.pending.value,
        'submitted_at': DateTime.now().toIso8601String(),
        'decision_note': null,
        'decided_by': null,
        'decided_at': null,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', districtId);

      // Re-insert assemblies
      await _sb.from('assemblies').delete().eq('district_id', districtId);
      for (final a in assemblies) {
        if (a.trim().isNotEmpty) {
          await _sb.from('assemblies').insert({
            'district_id': districtId,
            'name': a.trim(),
          });
        }
      }

      final dist = await getDistrictById(districtId);
      return dist!;
    } catch (e) {
      debugPrint('[DistrictsRepository] Error resubmitting district: $e');
      rethrow;
    }
  }

  @override
  Future<void> approveDistrict(String districtId, {String? note}) async {
    if (!SupabaseConfig.isInitialized) {
      final idx = _inMemoryDistricts.indexWhere((d) => d.id == districtId);
      if (idx != -1) {
        _inMemoryDistricts[idx] = _inMemoryDistricts[idx].copyWith(
          status: DistrictStatus.active,
          decidedAt: DateTime.now(),
          activatedAt: DateTime.now(),
        );
      }
      return;
    }

    try {
      await _sb.rpc('approve_district', params: {
        'p_district_id': districtId,
        'p_decision_note': note,
      });
    } catch (e) {
      debugPrint('[DistrictsRepository] Error approving district: $e');
      rethrow;
    }
  }

  @override
  Future<void> rejectDistrict(String districtId, {required String note}) async {
    if (note.trim().isEmpty) {
      throw Exception('A note explaining the rejection is required.');
    }

    if (!SupabaseConfig.isInitialized) {
      final idx = _inMemoryDistricts.indexWhere((d) => d.id == districtId);
      if (idx != -1) {
        _inMemoryDistricts[idx] = _inMemoryDistricts[idx].copyWith(
          status: DistrictStatus.rejected,
          decisionNote: note.trim(),
          decidedAt: DateTime.now(),
        );
      }
      return;
    }

    try {
      await _sb.rpc('reject_district', params: {
        'p_district_id': districtId,
        'p_decision_note': note.trim(),
      });
    } catch (e) {
      debugPrint('[DistrictsRepository] Error rejecting district: $e');
      rethrow;
    }
  }

  @override
  Future<DistrictModel> addDistrictDirectly({
    required String name,
    required List<String> assemblies,
  }) async {
    final cleanName = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (cleanName.length < 2) {
      throw Exception('Please enter a valid district name.');
    }

    final existing = await getDistricts();
    if (existing.any((d) => _normalize(d.name) == _normalize(cleanName))) {
      throw Exception('This district is already registered.');
    }

    if (!SupabaseConfig.isInitialized) {
      final id = 'dist-${DateTime.now().millisecondsSinceEpoch}';
      final newDist = DistrictModel(
        id: id,
        name: cleanName,
        status: DistrictStatus.active,
        activatedAt: DateTime.now(),
        createdAt: DateTime.now(),
        assemblyNames: assemblies,
      );
      _inMemoryDistricts.insert(0, newDist);
      return newDist;
    }

    try {
      final currentUserId = _sb.auth.currentUser?.id;
      final res = await _sb.from('districts').insert({
        'name': cleanName,
        'status': DistrictStatus.active.value,
        'activated_by': currentUserId,
        'activated_at': DateTime.now().toIso8601String(),
      }).select().single();

      final distId = res['id'] as String;
      for (final a in assemblies) {
        if (a.trim().isNotEmpty) {
          await _sb.from('assemblies').insert({
            'district_id': distId,
            'name': a.trim(),
          });
        }
      }

      return (await getDistrictById(distId))!;
    } catch (e) {
      debugPrint('[DistrictsRepository] Error adding district directly: $e');
      rethrow;
    }
  }

  @override
  Future<void> activateDistrict(String districtId, String activatedByUserId) async {
    final idx = _inMemoryDistricts.indexWhere((d) => d.id == districtId);
    if (idx != -1) {
      _inMemoryDistricts[idx] = _inMemoryDistricts[idx].copyWith(
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
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', districtId);
    }
  }

  @override
  Future<void> deactivateDistrict(String districtId) async {
    final idx = _inMemoryDistricts.indexWhere((d) => d.id == districtId);
    if (idx != -1) {
      _inMemoryDistricts[idx] = _inMemoryDistricts[idx].copyWith(
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
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', districtId);
    }
  }
}
