import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../districts/presentation/providers/districts_provider.dart';
import '../../domain/models/project_model.dart';
import '../providers/projects_provider.dart';
import 'project_detail_screen.dart';

class AreaHeadProjectsMapScreen extends ConsumerStatefulWidget {
  const AreaHeadProjectsMapScreen({super.key});

  @override
  ConsumerState<AreaHeadProjectsMapScreen> createState() => _AreaHeadProjectsMapScreenState();
}

class _AreaHeadProjectsMapScreenState extends ConsumerState<AreaHeadProjectsMapScreen> {
  bool _isMapView = false;
  String _selectedDistrictId = 'all';
  String _selectedStatus = 'all';

  @override
  Widget build(BuildContext context) {
    final projectsAsync = ref.watch(allProjectsForAreaHeadProvider);
    final districtsAsync = ref.watch(districtsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Area Projects & Events'),
        actions: [
          IconButton(
            icon: Icon(_isMapView ? Icons.view_list : Icons.map),
            tooltip: _isMapView ? 'Switch to List View' : 'Switch to Map View',
            onPressed: () {
              setState(() {
                _isMapView = !_isMapView;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Bar
          Container(
            color: AppColors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                // District Filter
                Expanded(
                  child: districtsAsync.maybeWhen(
                    data: (districts) => DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _selectedDistrictId,
                        items: [
                          const DropdownMenuItem(value: 'all', child: Text('All 33 Districts')),
                          ...districts.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name))),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedDistrictId = val);
                        },
                      ),
                    ),
                    orElse: () => const SizedBox(),
                  ),
                ),
                const SizedBox(width: 12),
                // Status Filter
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedStatus,
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All Status')),
                      DropdownMenuItem(value: 'planned', child: Text('Planned')),
                      DropdownMenuItem(value: 'ongoing', child: Text('Ongoing')),
                      DropdownMenuItem(value: 'completed', child: Text('Completed')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedStatus = val);
                    },
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          // Content
          Expanded(
            child: projectsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (projects) {
                final filtered = projects.where((p) {
                  if (_selectedDistrictId != 'all' && p.districtId != _selectedDistrictId) return false;
                  if (_selectedStatus != 'all' && p.status.value != _selectedStatus) return false;
                  return true;
                }).toList();

                if (_isMapView) {
                  return _buildMapSimulationView(context, filtered);
                }

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      'No projects match the selected filters.',
                      style: GoogleFonts.nunitoSans(color: AppColors.softGrey),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final p = filtered[index];
                    return _buildProjectListTile(context, p);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapSimulationView(BuildContext context, List<ProjectModel> projects) {
    return Stack(
      children: [
        // Simulated Interactive Map Surface
        Container(
          width: double.infinity,
          height: double.infinity,
          color: const Color(0xFFE2E8F0),
          child: Stack(
            children: [
              Positioned.fill(
                child: Opacity(
                  opacity: 0.15,
                  child: GridPaper(
                    color: AppColors.navy,
                    divisions: 2,
                    subdivisions: 4,
                  ),
                ),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.map_outlined, size: 80, color: AppColors.softGrey),
                    const SizedBox(height: 8),
                    Text(
                      'Abuakwa Area Geographic Map',
                      style: GoogleFonts.sourceSerif4(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.navy,
                      ),
                    ),
                    Text(
                      'Showing ${projects.length} pinned district projects and events',
                      style: GoogleFonts.nunitoSans(fontSize: 13, color: AppColors.softGrey),
                    ),
                  ],
                ),
              ),

              // Interactive Project Pins on Map
              ...projects.asMap().entries.map((entry) {
                final idx = entry.key;
                final p = entry.value;
                // Distributed positioning for visual clarity
                final top = 80.0 + (idx * 90.0) % 350;
                final left = 40.0 + (idx * 110.0) % 280;

                return Positioned(
                  top: top,
                  left: left,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => ProjectDetailScreen(project: p)),
                      );
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.navy,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4),
                            ],
                          ),
                          child: Text(
                            p.title,
                            style: GoogleFonts.nunitoSans(
                              color: AppColors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const Icon(Icons.location_on, color: AppColors.gold, size: 32),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),

        // Bottom Map Legend
        Positioned(
          bottom: 16,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildLegendItem(AppColors.success, 'Completed'),
                _buildLegendItem(AppColors.gold, 'Ongoing'),
                _buildLegendItem(AppColors.softGrey, 'Planned'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: GoogleFonts.nunitoSans(fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildProjectListTile(BuildContext context, ProjectModel p) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ProjectDetailScreen(project: p)),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  p.districtName ?? 'District',
                  style: GoogleFonts.nunitoSans(
                    fontWeight: FontWeight.bold,
                    color: AppColors.gold,
                    fontSize: 12,
                  ),
                ),
                Text(
                  '${p.progressPct}%',
                  style: GoogleFonts.nunitoSans(fontWeight: FontWeight.bold, color: AppColors.navy),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              p.title,
              style: GoogleFonts.sourceSerif4(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              p.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.nunitoSans(fontSize: 13, color: AppColors.softGrey),
            ),
          ],
        ),
      ),
    );
  }
}
