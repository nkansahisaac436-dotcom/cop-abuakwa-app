import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../auth/domain/models/profile_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';
import '../../../transfer/presentation/providers/transfer_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  void _confirmPastorTransfer(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Confirm Transfer Request',
          style: GoogleFonts.sourceSerif4(fontWeight: FontWeight.bold),
        ),
        content: Text(
          AppStrings.transferConfirmMessage,
          style: GoogleFonts.nunitoSans(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: GoogleFonts.nunitoSans(color: AppColors.softGrey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.navy,
              foregroundColor: AppColors.white,
              shape: const StadiumBorder(),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref.read(transferNotifierProvider.notifier).requestTransfer();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Transfer request submitted to the Area Head office.'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            },
            child: const Text('Confirm Request'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('No active profile')),
      );
    }

    final isPastor = user.isPastor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile & Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Profile Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
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
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: AppColors.navy,
                    child: Text(
                      user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'U',
                      style: GoogleFonts.sourceSerif4(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user.fullName,
                    style: GoogleFonts.sourceSerif4(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.email,
                    style: GoogleFonts.nunitoSans(fontSize: 13, color: AppColors.softGrey),
                  ),
                  const SizedBox(height: 12),

                  // Role Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.gold),
                    ),
                    child: Text(
                      user.role.value.toUpperCase().replaceAll('_', ' '),
                      style: GoogleFonts.nunitoSans(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.navyDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Pastor Transfer Request Trigger
            if (isPastor) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.warningFill,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.warningBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.transfer_within_a_station, color: AppColors.warningText),
                        const SizedBox(width: 8),
                        Text(
                          'Pastoral Transfer Action',
                          style: GoogleFonts.sourceSerif4(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.warningText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'If you have received an official transfer letter from the Area Head, tap below to request transfer and archive your tenure.',
                      style: GoogleFonts.nunitoSans(fontSize: 12, color: AppColors.warningText),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.navy,
                        foregroundColor: AppColors.white,
                        shape: const StadiumBorder(),
                      ),
                      onPressed: () => _confirmPastorTransfer(context, ref),
                      child: const Text('I am being transferred'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Quick Role Switcher (Developer / QA tool)
            Text(
              'Switch Demo Account Role',
              style: GoogleFonts.sourceSerif4(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 8),
            Material(
              color: AppColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _buildRoleTile(
                    ref,
                    title: 'Apostle Area Head',
                    role: UserRole.areaHead,
                    email: 'areahead@copabuakwa.org',
                  ),
                  const Divider(height: 1),
                  _buildRoleTile(
                    ref,
                    title: 'Pastor Enoch Agyemang',
                    role: UserRole.pastor,
                    email: 'pastor@copabuakwa.org',
                    districtId: 'd0000000-0000-0000-0000-000000000002',
                  ),
                  const Divider(height: 1),
                  _buildRoleTile(
                    ref,
                    title: 'Sister Grace (Women Leader)',
                    role: UserRole.ministryLeader,
                    email: 'womenleader@copabuakwa.org',
                  ),
                  const Divider(height: 1),
                  _buildRoleTile(
                    ref,
                    title: 'Kofi Mensah (Member)',
                    role: UserRole.member,
                    email: 'kofi@example.com',
                    districtId: 'd0000000-0000-0000-0000-000000000002',
                    assemblyId: 'a-5',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Sign Out Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.logout),
                label: Text(
                  'Log Out',
                  style: GoogleFonts.nunitoSans(fontWeight: FontWeight.bold),
                ),
                onPressed: () async {
                  await ref.read(authStateProvider.notifier).signOut();
                  if (context.mounted) {
                    final router = GoRouter.maybeOf(context);
                    if (router != null) {
                      context.go('/login');
                    }
                  }
                },
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleTile(
    WidgetRef ref, {
    required String title,
    required UserRole role,
    required String email,
    String? districtId,
    String? assemblyId,
  }) {
    return ListTile(
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: AppColors.navy.withValues(alpha: 0.1),
        child: Text(
          role.value[0].toUpperCase(),
          style: GoogleFonts.nunitoSans(fontWeight: FontWeight.bold, color: AppColors.navy),
        ),
      ),
      title: Text(title, style: GoogleFonts.nunitoSans(fontWeight: FontWeight.bold, fontSize: 14)),
      subtitle: Text(role.value.toUpperCase(), style: GoogleFonts.nunitoSans(fontSize: 11, color: AppColors.gold)),
      trailing: const Icon(Icons.swap_horiz, color: AppColors.navy),
      onTap: () {
        ref.read(authStateProvider.notifier).setMockProfile(
              UserProfile(
                id: 'mock-${role.value}-id',
                fullName: title,
                email: email,
                role: role,
                districtId: districtId,
                assemblyId: assemblyId,
                createdAt: DateTime.now(),
              ),
            );
      },
    );
  }
}
