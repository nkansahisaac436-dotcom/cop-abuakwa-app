import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/districts_repository.dart';
import '../../domain/models/assembly_model.dart';
import '../../domain/models/district_model.dart';

final districtsRepositoryProvider = Provider<DistrictsRepository>((ref) {
  return SupabaseDistrictsRepository();
});

final districtsListProvider = AsyncNotifierProvider<DistrictsNotifier, List<DistrictModel>>(() {
  return DistrictsNotifier();
});

class DistrictsNotifier extends AsyncNotifier<List<DistrictModel>> {
  @override
  Future<List<DistrictModel>> build() async {
    final repo = ref.watch(districtsRepositoryProvider);
    return repo.getDistricts();
  }

  Future<void> toggleDistrictActivation(String districtId, String currentUserId) async {
    final repo = ref.read(districtsRepositoryProvider);
    final currentList = state.value ?? [];
    final target = currentList.firstWhere((d) => d.id == districtId);

    if (target.isActive) {
      await repo.deactivateDistrict(districtId);
    } else {
      await repo.activateDistrict(districtId, currentUserId);
    }

    state = AsyncValue.data(await repo.getDistricts());
  }

  Future<void> approveDistrict(String districtId, {String? note}) async {
    final repo = ref.read(districtsRepositoryProvider);
    await repo.approveDistrict(districtId, note: note);
    state = AsyncValue.data(await repo.getDistricts());
  }

  Future<void> rejectDistrict(String districtId, {required String note}) async {
    final repo = ref.read(districtsRepositoryProvider);
    await repo.rejectDistrict(districtId, note: note);
    state = AsyncValue.data(await repo.getDistricts());
  }

  Future<AssemblyModel> addAssembly(String districtId, String name) async {
    final repo = ref.read(districtsRepositoryProvider);
    final asm = await repo.addAssembly(districtId: districtId, name: name);
    ref.invalidate(assembliesForDistrictProvider(districtId));
    ref.invalidate(activeAssembliesForDistrictProvider(districtId));
    state = AsyncValue.data(await repo.getDistricts());
    return asm;
  }

  Future<AssemblyModel> renameAssembly(String districtId, String assemblyId, String newName) async {
    final repo = ref.read(districtsRepositoryProvider);
    final asm = await repo.renameAssembly(assemblyId: assemblyId, newName: newName);
    ref.invalidate(assembliesForDistrictProvider(districtId));
    ref.invalidate(activeAssembliesForDistrictProvider(districtId));
    state = AsyncValue.data(await repo.getDistricts());
    return asm;
  }

  Future<void> toggleAssemblyStatus(String districtId, String assemblyId, bool isActive) async {
    final repo = ref.read(districtsRepositoryProvider);
    await repo.toggleAssemblyStatus(assemblyId: assemblyId, isActive: isActive);
    ref.invalidate(assembliesForDistrictProvider(districtId));
    ref.invalidate(activeAssembliesForDistrictProvider(districtId));
    state = AsyncValue.data(await repo.getDistricts());
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    final repo = ref.read(districtsRepositoryProvider);
    state = AsyncValue.data(await repo.getDistricts());
  }
}

final assembliesForDistrictProvider = FutureProvider.family<List<AssemblyModel>, String>((ref, districtId) async {
  if (districtId.isEmpty) return [];
  final repo = ref.watch(districtsRepositoryProvider);
  return repo.getAssembliesForDistrict(districtId);
});

final activeAssembliesForDistrictProvider = FutureProvider.family<List<AssemblyModel>, String>((ref, districtId) async {
  if (districtId.isEmpty) return [];
  final repo = ref.watch(districtsRepositoryProvider);
  return repo.getAssembliesForDistrict(districtId, activeOnly: true);
});
