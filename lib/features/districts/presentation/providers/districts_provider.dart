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
