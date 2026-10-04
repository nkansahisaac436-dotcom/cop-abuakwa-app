import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/models/media_attachment.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/media_picker.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../districts/domain/models/assembly_model.dart';
import '../../../districts/domain/models/district_model.dart';
import '../../../districts/presentation/providers/districts_provider.dart';
import '../../../districts/presentation/screens/district_assemblies_screen.dart';
import '../../domain/models/project_model.dart';
import '../providers/projects_provider.dart';

class AddEditProjectScreen extends ConsumerStatefulWidget {
  final ProjectModel? existingProject;

  const AddEditProjectScreen({super.key, this.existingProject});

  @override
  ConsumerState<AddEditProjectScreen> createState() => _AddEditProjectScreenState();
}

class _AddEditProjectScreenState extends ConsumerState<AddEditProjectScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _latController;
  late TextEditingController _lngController;

  late ProjectType _type;
  late ProjectStatus _status;
  late VisibilityLevel _visibility;
  int _progressPct = 0;
  DistrictModel? _selectedDistrict;
  AssemblyModel? _selectedAssembly;
  bool _isLoading = false;
  List<MediaAttachment> _attachments = [];

  @override
  void initState() {
    super.initState();
    final p = widget.existingProject;
    _titleController = TextEditingController(text: p?.title ?? '');
    _descController = TextEditingController(text: p?.description ?? '');
    _latController = TextEditingController(text: p?.lat?.toString() ?? '6.7020');
    _lngController = TextEditingController(text: p?.lng?.toString() ?? '-1.7250');
    _type = p?.type ?? ProjectType.project;
    _status = p?.status ?? ProjectStatus.planned;
    _visibility = p?.visibility ?? VisibilityLevel.members;
    _progressPct = p?.progressPct ?? 0;
    if (p?.photoUrls != null && p!.photoUrls.isNotEmpty) {
      _attachments = p.photoUrls
          .asMap()
          .entries
          .map((e) => MediaAttachment(id: 'existing-${e.key}', url: e.value, sortOrder: e.key))
          .toList();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(authStateProvider).value;
    final districtId = _selectedDistrict?.id ?? user?.districtId ?? '';

    setState(() {
      _isLoading = true;
    });

    try {
      final project = ProjectModel(
        id: widget.existingProject?.id ?? 'proj-${DateTime.now().millisecondsSinceEpoch}',
        districtId: districtId,
        districtName: _selectedDistrict?.name ?? user?.districtName ?? 'District',
        assemblyId: _selectedAssembly?.id,
        assemblyName: _selectedAssembly?.name ?? 'District Central',
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        type: _type,
        status: _status,
        progressPct: _progressPct,
        lat: double.tryParse(_latController.text),
        lng: double.tryParse(_lngController.text),
        visibility: _visibility,
        createdBy: user?.id,
        authorName: user?.fullName,
        authorAvatarUrl: user?.avatarUrl,
        photoUrls: widget.existingProject?.photoUrls ?? [],
        createdAt: widget.existingProject?.createdAt ?? DateTime.now(),
      );

      final newBytes = _attachments.where((a) => a.bytes != null).map((a) => a.bytes!).toList();
      final captions = _attachments.where((a) => a.bytes != null).map((a) => a.caption ?? '').toList();

      if (widget.existingProject != null) {
        await ref.read(projectsListProvider.notifier).updateProject(project);
      } else {
        await ref.read(projectsListProvider.notifier).addProject(
          project,
          mediaBytes: newBytes,
          captions: captions,
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_type.value.toUpperCase()} saved successfully.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final districtsAsync = ref.watch(districtsListProvider);
    final user = ref.watch(authStateProvider).value;
    final isAreaHead = user?.isAreaHead ?? false;
    final isPastor = user?.isPastor ?? false;
    final targetDistrictId = _selectedDistrict?.id ?? user?.districtId ?? '';
    final assembliesAsync = targetDistrictId.isNotEmpty
        ? ref.watch(activeAssembliesForDistrictProvider(targetDistrictId))
        : const AsyncValue.data(<AssemblyModel>[]);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingProject != null ? 'Edit Activity' : 'Add Project or Event'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: AppDimensions.cardBorderRadius,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Type Selector (Project vs Event)
                Text(
                  'Activity Type',
                  style: GoogleFonts.nunitoSans(
                    fontSize: AppDimensions.fontSizeLabel,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('District Project')),
                        selected: _type == ProjectType.project,
                        selectedColor: AppColors.navy,
                        labelStyle: GoogleFonts.nunitoSans(
                          color: _type == ProjectType.project ? AppColors.white : AppColors.text,
                          fontWeight: FontWeight.bold,
                        ),
                        onSelected: (selected) {
                          if (selected) setState(() => _type = ProjectType.project);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('District Event')),
                        selected: _type == ProjectType.event,
                        selectedColor: AppColors.navy,
                        labelStyle: GoogleFonts.nunitoSans(
                          color: _type == ProjectType.event ? AppColors.white : AppColors.text,
                          fontWeight: FontWeight.bold,
                        ),
                        onSelected: (selected) {
                          if (selected) setState(() => _type = ProjectType.event);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Title
                AppTextField(
                  label: _type == ProjectType.project ? 'Project Title' : 'Event Name',
                  hintText: 'e.g. Mission House Construction',
                  controller: _titleController,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Please enter a title' : null,
                ),
                const SizedBox(height: 16),

                // District Selector (if Area Head)
                if (isAreaHead) ...[
                  Text(
                    'District',
                    style: GoogleFonts.nunitoSans(
                      fontSize: AppDimensions.fontSizeLabel,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  districtsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text('Error: $e'),
                    data: (districts) {
                      final activeDistricts = districts.where((d) => d.isActive).toList();
                      return DropdownButtonFormField<DistrictModel>(
                        initialValue: _selectedDistrict,
                        items: activeDistricts.map((d) {
                          return DropdownMenuItem(value: d, child: Text(d.name));
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedDistrict = val;
                            _selectedAssembly = null;
                          });
                        },
                        decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                // Assembly Selector
                Text(
                  'Local Assembly',
                  style: GoogleFonts.nunitoSans(
                    fontSize: AppDimensions.fontSizeLabel,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                assembliesAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('Error loading assemblies: $e'),
                  data: (assemblies) {
                    if (assemblies.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.warningFill,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.warningBorder),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Text(
                                'Add an assembly first',
                                style: TextStyle(color: AppColors.warningText, fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.navy,
                                foregroundColor: AppColors.white,
                                shape: const StadiumBorder(),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                minimumSize: const Size(60, 32),
                              ),
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => DistrictAssembliesScreen(
                                      districtId: targetDistrictId,
                                      districtName: _selectedDistrict?.name ?? user?.districtName,
                                    ),
                                  ),
                                );
                              },
                              child: const Text('Add assembly', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      );
                    }

                    return DropdownButtonFormField<AssemblyModel>(
                      initialValue: _selectedAssembly,
                      items: assemblies.map((a) {
                        return DropdownMenuItem(
                          value: a,
                          child: Text(a.name),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedAssembly = val),
                      decoration: const InputDecoration(
                        hintText: 'Select Assembly (Optional)',
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Description
                AppTextField(
                  label: 'Description & Scope',
                  hintText: 'Detail what will be accomplished, specifications, and objectives...',
                  controller: _descController,
                  maxLines: 4,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Please enter description' : null,
                ),
                const SizedBox(height: 16),

                // Media Picker (Photos)
                MediaPicker(
                  initialMedia: _attachments,
                  maxImages: 5,
                  onMediaChanged: (list) {
                    setState(() {
                      _attachments = list;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Status Selector
                Text(
                  'Status',
                  style: GoogleFonts.nunitoSans(
                    fontSize: AppDimensions.fontSizeLabel,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<ProjectStatus>(
                  initialValue: _status,
                  items: ProjectStatus.values.map((s) {
                    return DropdownMenuItem(
                      value: s,
                      child: Text(s.value.toUpperCase()),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _status = val);
                  },
                  decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
                ),
                const SizedBox(height: 16),

                // Progress Percentage
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Progress: $_progressPct%',
                      style: GoogleFonts.nunitoSans(
                        fontSize: AppDimensions.fontSizeLabel,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _progressPct.toDouble(),
                  min: 0,
                  max: 100,
                  divisions: 20,
                  activeColor: AppColors.navy,
                  onChanged: (val) {
                    setState(() {
                      _progressPct = val.toInt();
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Visibility Selector
                Text(
                  'Visibility Tag',
                  style: GoogleFonts.nunitoSans(
                    fontSize: AppDimensions.fontSizeLabel,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<VisibilityLevel>(
                  initialValue: _visibility,
                  items: [
                    const DropdownMenuItem(
                      value: VisibilityLevel.public,
                      child: Text('Public (Visible to all app users & members)'),
                    ),
                    const DropdownMenuItem(
                      value: VisibilityLevel.members,
                      child: Text('Members (All logged-in users)'),
                    ),
                    if (isPastor || isAreaHead)
                      const DropdownMenuItem(
                        value: VisibilityLevel.pastors,
                        child: Text('Pastors (Pastors & Area Head only)'),
                      ),
                    if (isAreaHead)
                      const DropdownMenuItem(
                        value: VisibilityLevel.areaHead,
                        child: Text('Area Head (Area Head office only)'),
                      ),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _visibility = val);
                  },
                  decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
                ),
                const SizedBox(height: 28),

                PrimaryButton(
                  text: widget.existingProject != null ? 'Save Changes' : 'Create Activity',
                  isLoading: _isLoading,
                  onPressed: _handleSave,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
