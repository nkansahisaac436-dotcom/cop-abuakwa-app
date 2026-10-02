import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/district_model.dart';
import '../providers/districts_provider.dart';
import 'register_district_screen.dart';

final pastorRegisteredDistrictProvider = FutureProvider<DistrictModel?>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return null;
  final repo = ref.watch(districtsRepositoryProvider);
  final all = await repo.getDistricts();

  // Find district registered by current user or matching user's districtId
  return all.cast<DistrictModel?>().firstWhere(
    (d) => d?.registeredBy == user.id || d?.id == user.districtId,
    orElse: () => null,
  );
});

class WaitingApprovalScreen extends ConsumerWidget {
  const WaitingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final districtAsync = ref.watch(pastorRegisteredDistrictProvider);
    final user = ref.watch(authStateProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('District Registration Status'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'My Profile',
            onPressed: () => context.push('/profile'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () => ref.read(authStateProvider.notifier).signOut(),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(pastorRegisteredDistrictProvider);
            await ref.read(districtsListProvider.notifier).refresh();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppDimensions.paddingLarge),
            child: districtAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (err, _) => Center(
                child: Text('Error: $err', style: const TextStyle(color: AppColors.error)),
              ),
              data: (district) {
                if (district == null) {
                  return Column(
                    children: [
                      const Icon(Icons.church_outlined, size: 64, color: AppColors.softGrey),
                      const SizedBox(height: 16),
                      Text(
                        'No District Registered',
                        style: GoogleFonts.sourceSerif4(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Please register your district to begin serving in Abuakwa Area Connect.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.softGrey),
                      ),
                      const SizedBox(height: 24),
                      PrimaryButton(
                        text: 'Register Your District',
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const RegisterDistrictScreen()),
                        ),
                      ),
                    ],
                  );
                }

                final isRejected = district.isRejected;
                final isActive = district.isActive;

                // If approved/active, notify pastor they can proceed
                if (isActive) {
                  return Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.success),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.check_circle, size: 60, color: AppColors.success),
                        const SizedBox(height: 16),
                        Text(
                          'District Approved!',
                          style: GoogleFonts.sourceSerif4(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.success,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${district.name} is now approved and active. You can now post projects, events, and pastoral thoughts.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 14, color: AppColors.text),
                        ),
                        const SizedBox(height: 24),
                        PrimaryButton(
                          text: 'Go to Pastor Home',
                          onPressed: () => context.go('/pastor'),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Status Banner
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isRejected ? AppColors.error.withValues(alpha: 0.08) : AppColors.warningFill,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isRejected ? AppColors.error : AppColors.warningBorder,
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            isRejected ? Icons.warning_amber_rounded : Icons.hourglass_top_rounded,
                            size: 48,
                            color: isRejected ? AppColors.error : AppColors.warningText,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            isRejected
                                ? 'Registration Needs Attention'
                                : 'Waiting for Area Head Approval',
                            style: GoogleFonts.sourceSerif4(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isRejected ? AppColors.error : AppColors.warningText,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isRejected
                                ? 'The Area Head reviewed your district registration and requested the following modifications before it can be approved:'
                                : 'Your district registration has been submitted and is currently awaiting review by the Area Head office.',
                            style: TextStyle(
                              fontSize: 13,
                              color: isRejected ? AppColors.error : AppColors.warningText,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (isRejected && district.decisionNote != null && district.decisionNote!.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Area Head Note:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: AppColors.error,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    district.decisionNote!,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.text,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Submitted Details Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(20),
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
                          Text(
                            'Submitted Details',
                            style: GoogleFonts.sourceSerif4(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: AppColors.text,
                            ),
                          ),
                          const Divider(height: 24, color: AppColors.border),
                          _buildDetailRow('District Name', district.name, Icons.location_city),
                          const SizedBox(height: 12),
                          _buildDetailRow(
                            'Pastor',
                            user?.fullName ?? district.pastorName ?? 'Assigned Pastor',
                            Icons.person,
                          ),
                          const SizedBox(height: 12),
                          if (district.submittedAt != null) ...[
                            _buildDetailRow(
                              'Submitted On',
                              DateFormat.yMMMd().format(district.submittedAt!),
                              Icons.calendar_today,
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (district.assemblyNames != null && district.assemblyNames!.isNotEmpty) ...[
                            const Row(
                              children: [
                                Icon(Icons.home_work_outlined, size: 18, color: AppColors.navy),
                                SizedBox(width: 8),
                                Text(
                                  'Assemblies:',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.text),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: district.assemblyNames!.map((asm) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.background,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Text(
                                    asm,
                                    style: const TextStyle(fontSize: 12, color: AppColors.text),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Actions
                    if (isRejected) ...[
                      PrimaryButton(
                        text: 'Edit & Resubmit District',
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => RegisterDistrictScreen(
                                initialDistrictId: district.id,
                                initialName: district.name,
                                initialAssemblies: district.assemblyNames,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                    ],

                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: const StadiumBorder(),
                      ),
                      onPressed: () => context.push('/profile'),
                      icon: const Icon(Icons.edit, color: AppColors.navy),
                      label: const Text('Edit My Profile', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Note: While pending approval, you can update your profile photo and personal details. Creating district posts, projects, and events will be unlocked once approved.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppColors.softGrey, height: 1.4),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.navy),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.softGrey),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.text),
          ),
        ),
      ],
    );
  }
}
