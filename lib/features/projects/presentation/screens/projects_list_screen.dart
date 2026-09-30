import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/project_model.dart';
import '../providers/projects_provider.dart';
import 'add_edit_project_screen.dart';
import 'project_detail_screen.dart';

class ProjectsListScreen extends ConsumerStatefulWidget {
  final bool onlyPublic;

  const ProjectsListScreen({super.key, this.onlyPublic = false});

  @override
  ConsumerState<ProjectsListScreen> createState() => _ProjectsListScreenState();
}

class _ProjectsListScreenState extends ConsumerState<ProjectsListScreen> {
  String _filterType = 'all'; // 'all', 'project', 'event'

  @override
  Widget build(BuildContext context) {
    final projectsAsync = ref.watch(projectsListProvider);
    final user = ref.watch(authStateProvider).value;
    final canAddProject = user?.isPastor ?? false || (user?.isAreaHead ?? false);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          user?.isPastor ?? false
              ? 'My District Projects'
              : 'District Projects & Events',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(projectsListProvider.notifier).refresh(),
          ),
        ],
      ),
      floatingActionButton: canAddProject && !widget.onlyPublic
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.navy,
              foregroundColor: AppColors.white,
              icon: const Icon(Icons.add),
              label: Text(
                'New Project / Event',
                style: GoogleFonts.nunitoSans(fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AddEditProjectScreen(),
                  ),
                );
              },
            )
          : null,
      body: Column(
        children: [
          // Filter Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: AppColors.white,
            child: Row(
              children: [
                _buildFilterChip('All Activities', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('Projects', 'project'),
                const SizedBox(width: 8),
                _buildFilterChip('Events', 'event'),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          Expanded(
            child: projectsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error loading projects: $err')),
              data: (projects) {
                final filtered = projects.where((p) {
                  if (widget.onlyPublic && p.visibility != VisibilityLevel.public) {
                    return false;
                  }
                  if (_filterType == 'project') return p.isProject;
                  if (_filterType == 'event') return p.isEvent;
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.assignment_outlined, size: 56, color: AppColors.softGrey),
                        const SizedBox(height: 12),
                        Text(
                          'No projects or events found.',
                          style: GoogleFonts.nunitoSans(fontSize: 15, color: AppColors.softGrey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final project = filtered[index];
                    return _buildProjectCard(context, project);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterType == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _filterType = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.navy : AppColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppColors.navy : AppColors.border),
        ),
        child: Text(
          label,
          style: GoogleFonts.nunitoSans(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? AppColors.white : AppColors.softGrey,
          ),
        ),
      ),
    );
  }

  Widget _buildProjectCard(BuildContext context, ProjectModel project) {
    Color statusColor;
    switch (project.status) {
      case ProjectStatus.completed:
        statusColor = AppColors.success;
        break;
      case ProjectStatus.ongoing:
        statusColor = AppColors.gold;
        break;
      case ProjectStatus.planned:
        statusColor = AppColors.softGrey;
        break;
    }

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProjectDetailScreen(project: project),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Type & Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      project.isEvent ? Icons.event : Icons.construction,
                      size: 16,
                      color: AppColors.navy,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      project.type.value.toUpperCase(),
                      style: GoogleFonts.nunitoSans(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.navy,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    project.status.value.toUpperCase(),
                    style: GoogleFonts.nunitoSans(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Title
            Text(
              project.title,
              style: GoogleFonts.sourceSerif4(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 4),

            // District & Assembly Tag
            Row(
              children: [
                const Icon(Icons.place_outlined, size: 14, color: AppColors.softGrey),
                const SizedBox(width: 4),
                Text(
                  '${project.districtName ?? "District"} • ${project.assemblyName ?? "Assembly"}',
                  style: GoogleFonts.nunitoSans(
                    fontSize: 12,
                    color: AppColors.softGrey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Description
            Text(
              project.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.nunitoSans(
                fontSize: 13,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 14),

            // Progress Bar
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: project.progressPct / 100.0,
                      minHeight: 8,
                      backgroundColor: AppColors.disabled,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        project.progressPct >= 100 ? AppColors.success : AppColors.navy,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${project.progressPct}%',
                  style: GoogleFonts.nunitoSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppColors.navy,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
