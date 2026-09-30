import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../districts/domain/models/district_model.dart';
import '../../../districts/presentation/providers/districts_provider.dart';
import '../../data/supervision_repository.dart';
import '../../domain/models/visit_model.dart';

final supervisionRepositoryProvider = Provider<SupervisionRepository>((ref) {
  return SupabaseSupervisionRepository();
});

final supervisionVisitsProvider = AsyncNotifierProvider<SupervisionNotifier, List<VisitModel>>(() {
  return SupervisionNotifier();
});

class SupervisionNotifier extends AsyncNotifier<List<VisitModel>> {
  @override
  Future<List<VisitModel>> build() async {
    final repo = ref.watch(supervisionRepositoryProvider);
    return repo.getVisits();
  }

  Future<void> logVisit({
    required String districtId,
    required String notes,
    required DateTime date,
  }) async {
    final repo = ref.read(supervisionRepositoryProvider);
    final user = ref.read(authStateProvider).value;

    final newVisit = await repo.logVisit(
      districtId: districtId,
      visitedBy: user?.id ?? 'area-head-user',
      visitorName: user?.fullName ?? 'Apostle Area Head',
      visitDate: date,
      notes: notes,
    );

    state = AsyncValue.data([newVisit, ...?state.value]);
  }
}

class SupervisionVisitsScreen extends ConsumerStatefulWidget {
  const SupervisionVisitsScreen({super.key});

  @override
  ConsumerState<SupervisionVisitsScreen> createState() => _SupervisionVisitsScreenState();
}

class _SupervisionVisitsScreenState extends ConsumerState<SupervisionVisitsScreen> {
  void _openLogVisitSheet() {
    final notesController = TextEditingController();
    DistrictModel? selectedDistrict;
    DateTime visitDate = DateTime.now();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final districtsAsync = ref.watch(districtsListProvider);

          return Container(
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
                    'Log District Supervision Visit',
                    style: GoogleFonts.sourceSerif4(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // District dropdown
                  Text(
                    'District Visited',
                    style: GoogleFonts.nunitoSans(
                      fontSize: AppDimensions.fontSizeLabel,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  districtsAsync.maybeWhen(
                    data: (districts) => DropdownButtonFormField<DistrictModel>(
                      initialValue: selectedDistrict,
                      items: districts.map((d) => DropdownMenuItem(value: d, child: Text(d.name))).toList(),
                      onChanged: (val) => setSheetState(() => selectedDistrict = val),
                      decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
                    ),
                    orElse: () => const SizedBox(),
                  ),
                  const SizedBox(height: 14),

                  // Notes field
                  AppTextField(
                    label: 'Supervision Observations & Notes',
                    hintText: 'Record district administration state, ongoing construction progress, pastoral welfare...',
                    controller: notesController,
                    maxLines: 4,
                  ),
                  const SizedBox(height: 20),

                  PrimaryButton(
                    text: 'Save Supervision Log',
                    isLoading: isSaving,
                    onPressed: () async {
                      if (selectedDistrict == null || notesController.text.trim().isEmpty) return;

                      setSheetState(() => isSaving = true);

                      await ref.read(supervisionVisitsProvider.notifier).logVisit(
                            districtId: selectedDistrict!.id,
                            notes: notesController.text,
                            date: visitDate,
                          );

                      if (ctx.mounted) {
                        Navigator.of(ctx).pop();
                      }
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Supervision visit recorded.'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visitsAsync = ref.watch(supervisionVisitsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Area Supervision Log'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.navy,
        foregroundColor: AppColors.white,
        icon: const Icon(Icons.add_location_alt),
        label: Text('Log Visit', style: GoogleFonts.nunitoSans(fontWeight: FontWeight.bold)),
        onPressed: _openLogVisitSheet,
      ),
      body: visitsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (visits) {
          if (visits.isEmpty) {
            return Center(
              child: Text(
                'No supervision visits logged yet.',
                style: GoogleFonts.nunitoSans(color: AppColors.softGrey),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: visits.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final v = visits[index];
              return Container(
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
                          v.districtName ?? 'District Visit',
                          style: GoogleFonts.sourceSerif4(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.navy,
                          ),
                        ),
                        Text(
                          DateFormat('MMM d, yyyy').format(v.visitDate),
                          style: GoogleFonts.nunitoSans(fontSize: 12, color: AppColors.softGrey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      v.notes,
                      style: GoogleFonts.nunitoSans(fontSize: 13, color: AppColors.text, height: 1.4),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
