import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cop_abuakwa_app/features/auth/domain/models/profile_model.dart';
import 'package:cop_abuakwa_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:cop_abuakwa_app/features/projects/data/projects_repository.dart';
import 'package:cop_abuakwa_app/features/projects/domain/models/project_model.dart';
import 'package:cop_abuakwa_app/features/projects/domain/models/project_update_model.dart';

final projectsRepositoryProvider = Provider<ProjectsRepository>((ref) {
  return SupabaseProjectsRepository();
});

final projectsListProvider = AsyncNotifierProvider<ProjectsNotifier, List<ProjectModel>>(() {
  return ProjectsNotifier();
});

class ProjectsNotifier extends AsyncNotifier<List<ProjectModel>> {
  @override
  Future<List<ProjectModel>> build() async {
    final repo = ref.watch(projectsRepositoryProvider);
    final user = ref.watch(authStateProvider).value;
    final role = user?.role ?? UserRole.member;
    return repo.getProjects(
      userRole: role,
      districtId: (user?.isPastor == true) ? user?.districtId : null,
    );
  }

  Future<void> addProject(
    ProjectModel project, {
    List<Uint8List> mediaBytes = const [],
    List<String> captions = const [],
  }) async {
    final repo = ref.read(projectsRepositoryProvider);
    final created = await repo.createProject(
      project,
      mediaBytes: mediaBytes,
      captions: captions,
    );
    state = AsyncValue.data([created, ...?state.value]);
  }

  Future<void> updateProject(ProjectModel project) async {
    final repo = ref.read(projectsRepositoryProvider);
    final updated = await repo.updateProject(project);
    state = AsyncValue.data(
      (state.value ?? []).map((p) => p.id == updated.id ? updated : p).toList(),
    );
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    final repo = ref.read(projectsRepositoryProvider);
    final user = ref.read(authStateProvider).value;
    final role = user?.role ?? UserRole.member;
    state = AsyncValue.data(await repo.getProjects(userRole: role));
  }
}

final projectUpdatesProvider = FutureProvider.family<List<ProjectUpdateModel>, String>((ref, projectId) async {
  final repo = ref.watch(projectsRepositoryProvider);
  return repo.getProjectUpdates(projectId);
});

final allProjectsForAreaHeadProvider = FutureProvider<List<ProjectModel>>((ref) async {
  final repo = ref.watch(projectsRepositoryProvider);
  return repo.getProjects(userRole: UserRole.areaHead);
});
