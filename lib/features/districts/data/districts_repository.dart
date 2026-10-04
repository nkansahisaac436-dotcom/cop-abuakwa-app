import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/network/supabase_client.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/models/assembly_model.dart';
import '../domain/models/district_model.dart';

abstract class DistrictsRepository {
  Future<List<DistrictModel>> getDistricts();
  Future<List<DistrictModel>> getActiveDistricts();
  Future<DistrictModel?> getDistrictById(String districtId);
  Future<List<AssemblyModel>> getAssembliesForDistrict(String districtId, {bool activeOnly = false});
  Future<DistrictModel> registerDistrict({
    required String name,
    required DateTime startDate,
  });
  Future<DistrictModel> resubmitDistrict({
    required String districtId,
    required String name,
    required DateTime startDate,
  });
  Future<void> approveDistrict(String districtId, {String? note});
  Future<void> rejectDistrict(String districtId, {required String note});
  Future<DistrictModel> addDistrictDirectly({
    required String name,
    List<String>? assemblies,
  });
  Future<AssemblyModel> addAssembly({
    required String districtId,
    required String name,
  });
  Future<AssemblyModel> renameAssembly({
    required String assemblyId,
    required String newName,
  });
  Future<void> toggleAssemblyStatus({
    required String assemblyId,
    required bool isActive,
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
          .select('*, profiles:registered_by(full_name, avatar_url), assemblies(name, is_active)')
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
          .select('*, profiles:registered_by(full_name, avatar_url), assemblies(name, is_active)')
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
  Future<List<AssemblyModel>> getAssembliesForDistrict(String districtId, {bool activeOnly = false}) async {
    if (!SupabaseConfig.isInitialized) {
      final list = _inMemoryAssemblies[districtId] ?? [];
      if (activeOnly) {
        return list.where((a) => a.isActive).toList();
      }
      return List.unmodifiable(list);
    }
    try {
      var query = _sb.from('assemblies').select().eq('district_id', districtId);
      if (activeOnly) {
        query = query.eq('is_active', true);
      }
      final res = await query.order('name');
      return (res as List).map((json) => AssemblyModel.fromJson(json)).toList();
    } catch (e) {
      debugPrint('[DistrictsRepository] Error fetching assemblies: $e');
      final list = _inMemoryAssemblies[districtId] ?? [];
      if (activeOnly) {
        return list.where((a) => a.isActive).toList();
      }
      return List.unmodifiable(list);
    }
  }

  @override
  Future<DistrictModel> registerDistrict({
    required String name,
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
      final currentMock = SupabaseAuthRepository.currentMockUser;
      final districtId = 'dist-${DateTime.now().microsecondsSinceEpoch}-${_inMemoryDistricts.length}';
      final newDistrict = DistrictModel(
        id: districtId,
        name: cleanName,
        status: DistrictStatus.pending,
        registeredBy: currentMock?.id,
        pastorName: currentMock?.fullName,
        pastorPhotoUrl: currentMock?.avatarUrl,
        submittedAt: DateTime.now(),
        startDate: startDate,
        createdAt: DateTime.now(),
        assemblyNames: const [],
      );
      _inMemoryDistricts.insert(0, newDistrict);
      _inMemoryAssemblies[districtId] = [];

      // Link mock user to registered district
      if (currentMock != null) {
        final updated = currentMock.copyWith(
          districtId: districtId,
          districtName: cleanName,
          districtStatus: DistrictStatus.pending,
        );
        SupabaseAuthRepository.updateCurrentMockUser(updated);
      }

      return newDistrict;
    }

    try {
      final res = await _sb.rpc('register_district_by_pastor', params: {
        'p_name': cleanName,
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
            startDate: startDate,
            createdAt: DateTime.now(),
            assemblyNames: const [],
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
    required DateTime startDate,
  }) async {
    final cleanName = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (cleanName.length < 2) {
      throw Exception('Please enter a valid district name.');
    }

    // Check duplicate name excluding current
    final existingDistricts = await getDistricts();
    final isDuplicate = existingDistricts.any(
      (d) => d.id != districtId && _normalize(d.name) == _normalize(cleanName),
    );
    if (isDuplicate) {
      throw Exception('This district is already registered. Contact the Area Head office.');
    }

    if (!SupabaseConfig.isInitialized) {
      final idx = _inMemoryDistricts.indexWhere((d) => d.id == districtId);
      final currentMock = SupabaseAuthRepository.currentMockUser;
      final updated = DistrictModel(
        id: districtId,
        name: cleanName,
        status: DistrictStatus.pending,
        registeredBy: currentMock?.id,
        pastorName: currentMock?.fullName,
        pastorPhotoUrl: currentMock?.avatarUrl,
        submittedAt: DateTime.now(),
        startDate: startDate,
        decisionNote: null,
        decidedBy: null,
        decidedAt: null,
        createdAt: DateTime.now(),
        assemblyNames: _inMemoryDistricts.isNotEmpty && idx != -1
            ? _inMemoryDistricts[idx].assemblyNames
            : const [],
      );
      if (idx != -1) {
        _inMemoryDistricts[idx] = updated;
      } else {
        _inMemoryDistricts.add(updated);
      }

      if (currentMock != null && currentMock.districtId == districtId) {
        SupabaseAuthRepository.updateCurrentMockUser(
          currentMock.copyWith(
            districtName: cleanName,
            districtStatus: DistrictStatus.pending,
          ),
        );
      }

      return updated;
    }

    try {
      await _sb.from('districts').update({
        'name': cleanName,
        'status': DistrictStatus.pending.value,
        'start_date': startDate.toIso8601String().split('T').first,
        'submitted_at': DateTime.now().toIso8601String(),
        'decision_note': null,
        'decided_by': null,
        'decided_at': null,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', districtId);

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
          decisionNote: note,
          decidedAt: DateTime.now(),
          activatedAt: DateTime.now(),
        );
      }
      final currentMock = SupabaseAuthRepository.currentMockUser;
      if (currentMock != null && currentMock.districtId == districtId) {
        SupabaseAuthRepository.updateCurrentMockUser(
          currentMock.copyWith(districtStatus: DistrictStatus.active),
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
      final currentMock = SupabaseAuthRepository.currentMockUser;
      if (currentMock != null && currentMock.districtId == districtId) {
        SupabaseAuthRepository.updateCurrentMockUser(
          currentMock.copyWith(districtStatus: DistrictStatus.rejected),
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
    List<String>? assemblies,
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
      final id = 'dist-${DateTime.now().microsecondsSinceEpoch}-${_inMemoryDistricts.length}';
      final newDist = DistrictModel(
        id: id,
        name: cleanName,
        status: DistrictStatus.active,
        activatedAt: DateTime.now(),
        createdAt: DateTime.now(),
        assemblyNames: assemblies ?? const [],
      );
      _inMemoryDistricts.insert(0, newDist);
      if (assemblies != null && assemblies.isNotEmpty) {
        _inMemoryAssemblies[id] = assemblies
            .map((a) => AssemblyModel(
                  id: 'asm-${DateTime.now().microsecondsSinceEpoch}-$a',
                  districtId: id,
                  name: a.trim(),
                  isActive: true,
                  createdAt: DateTime.now(),
                ))
            .toList();
      } else {
        _inMemoryAssemblies[id] = [];
      }
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
      if (assemblies != null && assemblies.isNotEmpty) {
        for (final a in assemblies) {
          if (a.trim().isNotEmpty) {
            await _sb.from('assemblies').insert({
              'district_id': distId,
              'name': a.trim(),
              'is_active': true,
            });
          }
        }
      }

      return (await getDistrictById(distId))!;
    } catch (e) {
      debugPrint('[DistrictsRepository] Error adding district directly: $e');
      rethrow;
    }
  }

  @override
  Future<AssemblyModel> addAssembly({
    required String districtId,
    required String name,
  }) async {
    final cleanName = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (cleanName.length < 2) {
      throw Exception('Please enter a valid assembly name.');
    }

    // Check duplicate name inside the same district (case-insensitive & space-normalized)
    final existing = await getAssembliesForDistrict(districtId);
    if (existing.any((a) => _normalize(a.name) == _normalize(cleanName))) {
      throw Exception('An assembly with this name already exists in your district.');
    }

    if (!SupabaseConfig.isInitialized) {
      final newAsm = AssemblyModel(
        id: 'asm-${DateTime.now().microsecondsSinceEpoch}-$cleanName',
        districtId: districtId,
        name: cleanName,
        isActive: true,
        createdAt: DateTime.now(),
      );
      final currentList = _inMemoryAssemblies[districtId] ?? [];
      _inMemoryAssemblies[districtId] = [...currentList, newAsm];

      final distIdx = _inMemoryDistricts.indexWhere((d) => d.id == districtId);
      if (distIdx != -1) {
        final dist = _inMemoryDistricts[distIdx];
        final names = <String>[...(dist.assemblyNames ?? []), cleanName];
        _inMemoryDistricts[distIdx] = dist.copyWith(assemblyNames: names);
      }
      return newAsm;
    }

    try {
      final res = await _sb.rpc('add_assembly_by_pastor', params: {
        'p_district_id': districtId,
        'p_name': cleanName,
      });

      final asmId = res['id'] as String;
      return AssemblyModel(
        id: asmId,
        districtId: districtId,
        name: cleanName,
        isActive: true,
        createdAt: DateTime.now(),
      );
    } catch (e) {
      final errStr = e.toString().replaceAll('Exception: ', '');
      if (errStr.contains('already exists')) {
        throw Exception('An assembly with this name already exists in your district.');
      }
      debugPrint('[DistrictsRepository] Error adding assembly: $e');
      rethrow;
    }
  }

  @override
  Future<AssemblyModel> renameAssembly({
    required String assemblyId,
    required String newName,
  }) async {
    final cleanName = newName.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (cleanName.length < 2) {
      throw Exception('Please enter a valid assembly name.');
    }

    if (!SupabaseConfig.isInitialized) {
      String? foundDistrictId;
      AssemblyModel? updated;

      for (final entry in _inMemoryAssemblies.entries) {
        final idx = entry.value.indexWhere((a) => a.id == assemblyId);
        if (idx != -1) {
          foundDistrictId = entry.key;
          // Check uniqueness in this district
          final isDuplicate = entry.value.any(
            (a) => a.id != assemblyId && _normalize(a.name) == _normalize(cleanName),
          );
          if (isDuplicate) {
            throw Exception('An assembly with this name already exists in your district.');
          }

          updated = entry.value[idx].copyWith(name: cleanName);
          final updatedList = List<AssemblyModel>.from(entry.value);
          updatedList[idx] = updated;
          _inMemoryAssemblies[foundDistrictId] = updatedList;
          break;
        }
      }

      if (updated == null) {
        throw Exception('Assembly not found.');
      }
      return updated;
    }

    try {
      await _sb.rpc('update_assembly_by_pastor', params: {
        'p_assembly_id': assemblyId,
        'p_name': cleanName,
      });

      final res = await _sb.from('assemblies').select().eq('id', assemblyId).single();
      return AssemblyModel.fromJson(res);
    } catch (e) {
      final errStr = e.toString().replaceAll('Exception: ', '');
      if (errStr.contains('already exists')) {
        throw Exception('An assembly with this name already exists in your district.');
      }
      debugPrint('[DistrictsRepository] Error renaming assembly: $e');
      rethrow;
    }
  }

  @override
  Future<void> toggleAssemblyStatus({
    required String assemblyId,
    required bool isActive,
  }) async {
    if (!SupabaseConfig.isInitialized) {
      for (final entry in _inMemoryAssemblies.entries) {
        final idx = entry.value.indexWhere((a) => a.id == assemblyId);
        if (idx != -1) {
          final updated = entry.value[idx].copyWith(isActive: isActive);
          final updatedList = List<AssemblyModel>.from(entry.value);
          updatedList[idx] = updated;
          _inMemoryAssemblies[entry.key] = updatedList;
          break;
        }
      }
      return;
    }

    try {
      await _sb.rpc('update_assembly_by_pastor', params: {
        'p_assembly_id': assemblyId,
        'p_is_active': isActive,
      });
    } catch (e) {
      debugPrint('[DistrictsRepository] Error toggling assembly status: $e');
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
