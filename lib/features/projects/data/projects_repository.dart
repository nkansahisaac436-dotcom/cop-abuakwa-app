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
  Future<ProjectModel> createProject(
    ProjectModel project, {
    List<Uint8List> mediaBytes = const [],
    List<String> captions = const [],
  });
  Future<ProjectModel> updateProject(ProjectModel project);
  Future<List<ProjectUpdateModel>> getProjectUpdates(String projectId);
  Future<ProjectUpdateModel> addProjectUpdate({
    required String projectId,
    required String note,
    required int progressPct,
    required String createdBy,
    required String authorName,
    List<Uint8List> mediaBytes = const [],
    List<String> captions = const [],
  });
}

class SupabaseProjectsRepository implements ProjectsRepository {
  final SupabaseClient? _client;

  SupabaseProjectsRepository([this._client]);

  SupabaseClient get _sb => _client ?? SupabaseConfig.client;

  // In-memory runtime storage for offline / mock testing (starts empty)
  static final List<ProjectModel> _inMemoryProjects = [];
  static final List<ProjectUpdateModel> _inMemoryUpdates = [];

  static void resetState() {
    _inMemoryProjects.clear();
    _inMemoryUpdates.clear();
  }

  @override
  Future<List<ProjectModel>> getProjects({
    required UserRole userRole,
    String? districtId,
    ProjectStatus? status,
    bool onlyPublic = false,
  }) async {
    if (!SupabaseConfig.isInitialized) {
      return _inMemoryProjects.where((p) {
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
      var query = _sb.from('projects').select(
        '*, districts(name), assemblies(name), profiles:created_by(full_name, role, avatar_url)',
      );
      if (districtId != null) query = query.eq('district_id', districtId);
      if (status != null) query = query.eq('status', status.value);
      if (onlyPublic) query = query.eq('visibility', 'public');

      final res = await query.order('created_at', ascending: false);
      return (res as List).map((j) {
        final distName = j['districts'] != null ? j['districts']['name'] as String? : null;
        final assName = j['assemblies'] != null ? j['assemblies']['name'] as String? : null;
        final profile = j['profiles'] as Map<String, dynamic>?;

        final map = Map<String, dynamic>.from(j);
        map['district_name'] = distName;
        map['assembly_name'] = assName;
        if (profile != null) {
          map['author_name'] = profile['full_name'];
          map['author_role'] = profile['role'];
          map['author_avatar_url'] = profile['avatar_url'];
        }
        return ProjectModel.fromJson(map);
      }).toList();
    } catch (e) {
      debugPrint('[ProjectsRepository] Error fetching projects: $e');
      return _inMemoryProjects;
    }
  }

  @override
  Future<ProjectModel> createProject(
    ProjectModel project, {
    List<Uint8List> mediaBytes = const [],
    List<String> captions = const [],
  }) async {
    final photoUrls = List<String>.from(project.photoUrls);

    if (SupabaseConfig.isInitialized && mediaBytes.isNotEmpty && project.createdBy != null) {
      for (int i = 0; i < mediaBytes.length; i++) {
        try {
          final fileName = 'projects/${project.createdBy}/${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
          await _sb.storage.from('post_media').uploadBinary(
            fileName,
            mediaBytes[i],
            fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
          );
          final signedUrl = await _sb.storage.from('post_media').createSignedUrl(fileName, 60 * 60 * 24 * 365);
          photoUrls.add(signedUrl);
        } catch (e) {
          debugPrint('[ProjectsRepository] Error uploading project photo: $e');
        }
      }
    }

    final toSave = ProjectModel(
      id: project.id,
      districtId: project.districtId,
      districtName: project.districtName,
      assemblyId: project.assemblyId,
      assemblyName: project.assemblyName,
      tenureId: project.tenureId,
      title: project.title,
      description: project.description,
      type: project.type,
      status: project.status,
      progressPct: project.progressPct,
      lat: project.lat,
      lng: project.lng,
      startDate: project.startDate,
      endDate: project.endDate,
      visibility: project.visibility,
      createdBy: project.createdBy,
      authorName: project.authorName,
      authorRole: project.authorRole,
      authorAvatarUrl: project.authorAvatarUrl,
      photoUrls: photoUrls,
      createdAt: project.createdAt,
    );

    _inMemoryProjects.insert(0, toSave);

    if (SupabaseConfig.isInitialized) {
      try {
        final res = await _sb.from('projects').insert(toSave.toJson()).select().single();
        final actualId = res['id'] as String;

        // Insert media rows
        for (int i = 0; i < photoUrls.length; i++) {
          final cap = i < captions.length ? captions[i] : null;
          await _sb.from('media').insert({
            'owner_type': 'project',
            'owner_id': actualId,
            'url': photoUrls[i],
            'caption': cap,
            'sort_order': i,
            'created_by': project.createdBy,
          });
        }

        return ProjectModel.fromJson(res);
      } catch (e) {
        debugPrint('[ProjectsRepository] Error creating project: $e');
        rethrow;
      }
    }
    return toSave;
  }

  @override
  Future<ProjectModel> updateProject(ProjectModel project) async {
    final idx = _inMemoryProjects.indexWhere((p) => p.id == project.id);
    if (idx != -1) {
      _inMemoryProjects[idx] = project;
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
      return _inMemoryUpdates.where((u) => u.projectId == projectId).toList();
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
      return _inMemoryUpdates.where((u) => u.projectId == projectId).toList();
    }
  }

  @override
  Future<ProjectUpdateModel> addProjectUpdate({
    required String projectId,
    required String note,
    required int progressPct,
    required String createdBy,
    required String authorName,
    List<Uint8List> mediaBytes = const [],
    List<String> captions = const [],
  }) async {
    final updateId = 'up-${DateTime.now().millisecondsSinceEpoch}';
    final newUpdate = ProjectUpdateModel(
      id: updateId,
      projectId: projectId,
      note: note.trim(),
      progressPct: progressPct,
      createdBy: createdBy,
      authorName: authorName,
      createdAt: DateTime.now(),
    );

    _inMemoryUpdates.insert(0, newUpdate);

    // Update parent project progress percentage in mock
    final projIdx = _inMemoryProjects.indexWhere((p) => p.id == projectId);
    if (projIdx != -1) {
      final old = _inMemoryProjects[projIdx];
      _inMemoryProjects[projIdx] = ProjectModel(
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
        authorRole: old.authorRole,
        authorAvatarUrl: old.authorAvatarUrl,
        photoUrls: old.photoUrls,
        createdAt: old.createdAt,
      );
    }

    if (SupabaseConfig.isInitialized) {
      try {
        final inserted = await _sb.from('project_updates').insert(newUpdate.toJson()).select().single();
        final actualUpdateId = inserted['id'] as String;

        await _sb.from('projects').update({
          'progress_pct': progressPct,
          if (progressPct >= 100) 'status': 'completed',
        }).eq('id', projectId);

        // Upload any media
        for (int i = 0; i < mediaBytes.length; i++) {
          final fileName = 'updates/$createdBy/${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
          await _sb.storage.from('post_media').uploadBinary(
            fileName,
            mediaBytes[i],
            fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
          );
          final signedUrl = await _sb.storage.from('post_media').createSignedUrl(fileName, 60 * 60 * 24 * 365);
          final cap = i < captions.length ? captions[i] : null;

          await _sb.from('media').insert({
            'update_id': actualUpdateId,
            'owner_type': 'project_update',
            'owner_id': actualUpdateId,
            'url': signedUrl,
            'caption': cap,
            'sort_order': i,
            'created_by': createdBy,
          });
        }
      } catch (e) {
        debugPrint('[ProjectsRepository] Error saving update: $e');
      }
    }

    return newUpdate;
  }
}
