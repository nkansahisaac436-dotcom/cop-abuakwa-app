import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/project_model.dart';
import '../providers/projects_provider.dart';

class ProjectDetailScreen extends ConsumerStatefulWidget {
  final ProjectModel project;

  const ProjectDetailScreen({super.key, required this.project});

  @override
  ConsumerState<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends ConsumerState<ProjectDetailScreen> {
  late ProjectModel _project;

  @override
  void initState() {
    super.initState();
    _project = widget.project;
  }

  void _openAddUpdateDialog() {
    final noteController = TextEditingController();
    int newPct = _project.progressPct;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Add Project Progress Update',
                  style: GoogleFonts.sourceSerif4(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 16),

                // Note Field
                AppTextField(
                  label: 'Progress Note',
                  hintText: 'Describe current milestone reached, work done, or next steps...',
                  controller: noteController,
                  maxLines: 3,
                ),
                const SizedBox(height: 16),

                // Percentage Slider
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Updated Progress Percentage',
                      style: GoogleFonts.nunitoSans(
                        fontSize: AppDimensions.fontSizeLabel,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '$newPct%',
                      style: GoogleFonts.nunitoSans(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.navy,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: newPct.toDouble(),
                  min: 0,
                  max: 100,
                  divisions: 20,
                  activeColor: AppColors.navy,
                  onChanged: (val) {
                    setSheetState(() {
                      newPct = val.toInt();
                    });
                  },
                ),
                const SizedBox(height: 20),

                PrimaryButton(
                  text: 'Save Progress Update',
                  isLoading: isSaving,
                  onPressed: () async {
                    if (noteController.text.trim().isEmpty) return;

                    setSheetState(() {
                      isSaving = true;
                    });

                    final user = ref.read(authStateProvider).value;
                    await ref.read(projectsRepositoryProvider).addProjectUpdate(
                          projectId: _project.id,
                          note: noteController.text,
                          progressPct: newPct,
                          createdBy: user?.id ?? 'pastor-user',
                          authorName: user?.fullName ?? 'Pastor',
                        );

                    setState(() {
                      _project = ProjectModel(
                        id: _project.id,
                        districtId: _project.districtId,
                        districtName: _project.districtName,
                        assemblyId: _project.assemblyId,
                        assemblyName: _project.assemblyName,
                        tenureId: _project.tenureId,
                        title: _project.title,
                        description: _project.description,
                        type: _project.type,
                        status: newPct >= 100 ? ProjectStatus.completed : _project.status,
                        progressPct: newPct,
                        lat: _project.lat,
                        lng: _project.lng,
                        startDate: _project.startDate,
                        endDate: _project.endDate,
                        visibility: _project.visibility,
                        createdBy: _project.createdBy,
                        authorName: _project.authorName,
                        photoUrls: _project.photoUrls,
                        createdAt: _project.createdAt,
                      );
                    });

                    ref.invalidate(projectUpdatesProvider(_project.id));
                    ref.read(projectsListProvider.notifier).refresh();

                    if (ctx.mounted) {
                      Navigator.of(ctx).pop();
                    }
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Progress update recorded.'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final updatesAsync = ref.watch(projectUpdatesProvider(_project.id));
    final user = ref.watch(authStateProvider).value;
    final canUpdate = user?.isPastor ?? false || (user?.isAreaHead ?? false);
    final dateFormat = DateFormat('MMM d, yyyy');

    return Scaffold(
      appBar: AppBar(
        title: Text(_project.type == ProjectType.event ? 'Event Details' : 'Project Details'),
      ),
      floatingActionButton: canUpdate
          ? FloatingActionButton.extended(
              heroTag: 'project_detail_fab',
              backgroundColor: AppColors.navy,
              foregroundColor: AppColors.white,
              icon: const Icon(Icons.add_task),
              label: Text(
                'Post Update',
                style: GoogleFonts.nunitoSans(fontWeight: FontWeight.bold),
              ),
              onPressed: _openAddUpdateDialog,
            )
          : null,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Info Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              color: AppColors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.navy.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _project.type.value.toUpperCase(),
                          style: GoogleFonts.nunitoSans(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.navy,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.warningFill,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.warningBorder),
                        ),
                        child: Text(
                          _project.status.value.toUpperCase(),
                          style: GoogleFonts.nunitoSans(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.warningText,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _project.title,
                    style: GoogleFonts.sourceSerif4(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.place, size: 16, color: AppColors.gold),
                      const SizedBox(width: 4),
                      Text(
                        '${_project.districtName ?? "District"} • ${_project.assemblyName ?? "Assembly"}',
                        style: GoogleFonts.nunitoSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.softGrey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Progress Bar
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Completion Progress',
                            style: GoogleFonts.nunitoSans(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${_project.progressPct}%',
                            style: GoogleFonts.nunitoSans(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.navy,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: _project.progressPct / 100.0,
                          minHeight: 10,
                          backgroundColor: AppColors.disabled,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _project.progressPct >= 100 ? AppColors.success : AppColors.navy,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  Text(
                    'About this activity',
                    style: GoogleFonts.nunitoSans(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _project.description,
                    style: GoogleFonts.nunitoSans(
                      fontSize: 14,
                      color: AppColors.text,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 14),

                  if (_project.lat != null && _project.lng != null)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.gps_fixed, size: 16, color: AppColors.navy),
                          const SizedBox(width: 8),
                          Text(
                            'GPS Location: ${_project.lat!.toStringAsFixed(4)}, ${_project.lng!.toStringAsFixed(4)}',
                            style: GoogleFonts.nunitoSans(
                              fontSize: 12,
                              color: AppColors.text,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Timeline of Updates
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Progress Updates & History',
                style: GoogleFonts.sourceSerif4(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.navy,
                ),
              ),
            ),
            const SizedBox(height: 10),

            updatesAsync.when(
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
              error: (err, _) => Padding(padding: const EdgeInsets.all(16), child: Text('Error: $err')),
              data: (updates) {
                if (updates.isEmpty) {
                  return Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        'No progress updates logged yet.',
                        style: GoogleFonts.nunitoSans(color: AppColors.softGrey),
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: updates.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final up = updates[index];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${up.progressPct}% Reached',
                                style: GoogleFonts.nunitoSans(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.navy,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                dateFormat.format(up.createdAt),
                                style: GoogleFonts.nunitoSans(
                                  fontSize: 11,
                                  color: AppColors.softGrey,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            up.note,
                            style: GoogleFonts.nunitoSans(
                              fontSize: 13,
                              color: AppColors.text,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
