import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/network/supabase_client.dart';
import '../../auth/domain/models/profile_model.dart';
import '../domain/models/project_model.dart';
import '../domain/models/project_update_model.dart';

abstract class ProjectsRepository {
  Future<List<ProjectModel>> getProjects({
    required UserRole userRole,
    String? districtId,
    ProjectStatus? status,
    bool onlyPublic = false,
  });
  Future<ProjectModel> createProject(ProjectModel project);
  Future<ProjectModel> updateProject(ProjectModel project);
  Future<List<ProjectUpdateModel>> getProjectUpdates(String projectId);
  Future<ProjectUpdateModel> addProjectUpdate({
    required String projectId,
    required String note,
    required int progressPct,
    required String createdBy,
    required String authorName,
  });
}

class SupabaseProjectsRepository implements ProjectsRepository {
  final SupabaseClient? _client;

  SupabaseProjectsRepository([this._client]);

  SupabaseClient get _sb => _client ?? SupabaseConfig.client;

  static final List<ProjectModel> _mockProjects = [
    ProjectModel(
      id: 'proj-1',
      districtId: 'd0000000-0000-0000-0000-000000000002',
      districtName: 'Abuakwa North',
      assemblyId: 'a-5',
      assemblyName: 'Peniel Assembly',
      title: 'Peniel Mission House Construction',
      description: 'Building a permanent 4-bedroom mission house for the local assembly minister.',
      type: ProjectType.project,
      status: ProjectStatus.ongoing,
      progressPct: 65,
      lat: 6.7020,
      lng: -1.7250,
      startDate: DateTime(2025, 4, 1),
      endDate: DateTime(2026, 12, 31),
      visibility: VisibilityLevel.members,
      createdBy: 'mock-pastor-id',
      authorName: 'Pastor Enoch Agyemang',
      createdAt: DateTime(2025, 4, 1),
    ),
    ProjectModel(
      id: 'proj-2',
      districtId: 'd0000000-0000-0000-0000-000000000004',
      districtName: 'Tanoso',
      assemblyId: 'a-9',
      assemblyName: 'Tanoso Central Assembly',
      title: 'Youth Chapel Auditorium Expansion',
      description: 'Modernizing and expanding the youth auditorium seating capacity from 200 to 500.',
      type: ProjectType.project,
      status: ProjectStatus.ongoing,
      progressPct: 40,
      lat: 6.6950,
      lng: -1.7080,
      startDate: DateTime(2026, 1, 10),
      endDate: DateTime(2026, 11, 30),
      visibility: VisibilityLevel.public,
      createdBy: 'mock-pastor-2',
      authorName: 'Pastor Samuel Appiah',
      createdAt: DateTime(2026, 1, 10),
    ),
    ProjectModel(
      id: 'proj-3',
      districtId: 'd0000000-0000-0000-0000-000000000005',
      districtName: 'Akropong',
      assemblyId: 'a-11',
      assemblyName: 'Akropong Central Assembly',
      title: 'Community Clean Water Borehole Project',
      description: 'Drilling an industrial mechanized borehole to serve the church premises and neighboring community.',
      type: ProjectType.project,
      status: ProjectStatus.completed,
      progressPct: 100,
      lat: 6.7150,
      lng: -1.7450,
      startDate: DateTime(2025, 8, 1),
      endDate: DateTime(2026, 2, 20),
      visibility: VisibilityLevel.public,
      createdBy: 'mock-pastor-3',
      authorName: 'Pastor David Mensah',
      createdAt: DateTime(2025, 8, 1),
    ),
  ];

  static final List<ProjectUpdateModel> _mockUpdates = [
    ProjectUpdateModel(
      id: 'up-1',
      projectId: 'proj-1',
      note: 'Roofing and electrical piping completed. Plastering in progress.',
      progressPct: 65,
      createdBy: 'mock-pastor-id',
      authorName: 'Pastor Enoch Agyemang',
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
    ProjectUpdateModel(
      id: 'up-2',
      projectId: 'proj-1',
      note: 'Lintel level reached and cured. Preparing for wooden truss fabrication.',
      progressPct: 45,
      createdBy: 'mock-pastor-id',
      authorName: 'Pastor Enoch Agyemang',
      createdAt: DateTime.now().subtract(const Duration(days: 35)),
    ),
  ];

  @override
  Future<List<ProjectModel>> getProjects({
    required UserRole userRole,
    String? districtId,
    ProjectStatus? status,
    bool onlyPublic = false,
  }) async {
    if (!SupabaseConfig.isInitialized) {
      return _mockProjects.where((p) {
        if (districtId != null && p.districtId != districtId) return false;
        if (status != null && p.status != status) return false;
        if (onlyPublic) return p.visibility == VisibilityLevel.public;

        if (userRole == UserRole.member) {
          return p.visibility == VisibilityLevel.public || p.visibility == VisibilityLevel.members;
        } else if (userRole == UserRole.pastor) {
          return p.visibility != VisibilityLevel.areaHead;
        }
        return true;
      }).toList();
    }

    try {
      var query = _sb.from('projects').select('*, districts(name), assemblies(name)');
      if (districtId != null) query = query.eq('district_id', districtId);
      if (status != null) query = query.eq('status', status.value);
      if (onlyPublic) query = query.eq('visibility', 'public');

      final res = await query.order('created_at', ascending: false);
      return (res as List).map((j) {
        final distName = j['districts'] != null ? j['districts']['name'] as String? : null;
        final assName = j['assemblies'] != null ? j['assemblies']['name'] as String? : null;
        final map = Map<String, dynamic>.from(j);
        map['district_name'] = distName;
        map['assembly_name'] = assName;
        return ProjectModel.fromJson(map);
      }).toList();
    } catch (e) {
      debugPrint('[ProjectsRepository] Error fetching projects: $e');
      return _mockProjects;
    }
  }

  @override
  Future<ProjectModel> createProject(ProjectModel project) async {
    _mockProjects.insert(0, project);

    if (SupabaseConfig.isInitialized) {
      try {
        final res = await _sb.from('projects').insert(project.toJson()).select().single();
        return ProjectModel.fromJson(res);
      } catch (e) {
        debugPrint('[ProjectsRepository] Error creating project: $e');
      }
    }
    return project;
  }

  @override
  Future<ProjectModel> updateProject(ProjectModel project) async {
    final idx = _mockProjects.indexWhere((p) => p.id == project.id);
    if (idx != -1) {
      _mockProjects[idx] = project;
    }

    if (SupabaseConfig.isInitialized) {
      try {
        await _sb.from('projects').update(project.toJson()).eq('id', project.id);
      } catch (e) {
        debugPrint('[ProjectsRepository] Error updating project: $e');
      }
    }
    return project;
  }

  @override
  Future<List<ProjectUpdateModel>> getProjectUpdates(String projectId) async {
    if (!SupabaseConfig.isInitialized) {
      return _mockUpdates.where((u) => u.projectId == projectId).toList();
    }
    try {
      final res = await _sb
          .from('project_updates')
          .select('*, profiles(full_name)')
          .eq('project_id', projectId)
          .order('created_at', ascending: false);

      return (res as List).map((j) {
        final author = j['profiles'] != null ? j['profiles']['full_name'] as String? : null;
        final map = Map<String, dynamic>.from(j);
        map['author_name'] = author;
        return ProjectUpdateModel.fromJson(map);
      }).toList();
    } catch (e) {
      debugPrint('[ProjectsRepository] Error fetching updates: $e');
      return _mockUpdates.where((u) => u.projectId == projectId).toList();
    }
  }

  @override
  Future<ProjectUpdateModel> addProjectUpdate({
    required String projectId,
    required String note,
    required int progressPct,
    required String createdBy,
    required String authorName,
  }) async {
    final newUpdate = ProjectUpdateModel(
      id: 'up-${DateTime.now().millisecondsSinceEpoch}',
      projectId: projectId,
      note: note.trim(),
      progressPct: progressPct,
      createdBy: createdBy,
      authorName: authorName,
      createdAt: DateTime.now(),
    );

    _mockUpdates.insert(0, newUpdate);

    // Update parent project progress percentage
    final projIdx = _mockProjects.indexWhere((p) => p.id == projectId);
    if (projIdx != -1) {
      final old = _mockProjects[projIdx];
      _mockProjects[projIdx] = ProjectModel(
        id: old.id,
        districtId: old.districtId,
        districtName: old.districtName,
        assemblyId: old.assemblyId,
        assemblyName: old.assemblyName,
        tenureId: old.tenureId,
        title: old.title,
        description: old.description,
        type: old.type,
        status: progressPct >= 100 ? ProjectStatus.completed : old.status,
        progressPct: progressPct,
        lat: old.lat,
        lng: old.lng,
        startDate: old.startDate,
        endDate: old.endDate,
        visibility: old.visibility,
        createdBy: old.createdBy,
        authorName: old.authorName,
        photoUrls: old.photoUrls,
        createdAt: old.createdAt,
      );
    }

    if (SupabaseConfig.isInitialized) {
      try {
        await _sb.from('project_updates').insert(newUpdate.toJson());
        await _sb.from('projects').update({
          'progress_pct': progressPct,
          if (progressPct >= 100) 'status': 'completed',
        }).eq('id', projectId);
      } catch (e) {
        debugPrint('[ProjectsRepository] Error saving update: $e');
      }
    }

    return newUpdate;
  }
}
