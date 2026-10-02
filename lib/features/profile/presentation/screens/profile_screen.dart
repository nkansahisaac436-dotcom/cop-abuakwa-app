import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/image_compressor.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';
import '../../../transfer/presentation/providers/transfer_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isUploadingAvatar = false;

  Future<void> _pickAndUploadAvatar(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source);
      if (picked == null) return;

      setState(() => _isUploadingAvatar = true);

      final rawBytes = await picked.readAsBytes();
      final compressed = await ImageCompressor.compressAvatar(rawBytes, size: 512);

      await ref.read(authStateProvider.notifier).uploadAvatar(compressed);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo updated successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating photo: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
      }
    }
  }

  void _showAvatarOptionsSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Change Profile Photo',
                style: GoogleFonts.sourceSerif4(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.disabled,
                  child: Icon(Icons.camera_alt, color: AppColors.navy),
                ),
                title: const Text('Take photo', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadAvatar(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.disabled,
                  child: Icon(Icons.photo_library, color: AppColors.navy),
                ),
                title: const Text('Choose from gallery', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadAvatar(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmPastorTransfer() {
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
              if (mounted) {
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

  void _showChangePasswordDialog() {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;
    String? errorMessage;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Change Password',
            style: GoogleFonts.sourceSerif4(fontWeight: FontWeight.bold, color: AppColors.navy),
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.error),
                      ),
                      child: Text(
                        errorMessage!,
                        style: const TextStyle(color: AppColors.error, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                  AppTextField(
                    label: 'New Password',
                    hintText: 'Enter new password',
                    controller: passwordController,
                    isPassword: true,
                    validator: (val) {
                      if (val == null || val.trim().length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    label: 'Confirm New Password',
                    hintText: 'Re-enter new password',
                    controller: confirmController,
                    isPassword: true,
                    validator: (val) {
                      if (val != passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.of(ctx).pop(),
              child: Text('Cancel', style: GoogleFonts.nunitoSans(color: AppColors.softGrey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navy,
                foregroundColor: AppColors.white,
                shape: const StadiumBorder(),
              ),
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() {
                        isSaving = true;
                        errorMessage = null;
                      });

                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        await ref.read(authStateProvider.notifier).changePassword(passwordController.text.trim());
                        if (ctx.mounted) {
                          Navigator.of(ctx).pop();
                        }
                        if (mounted) {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Password changed successfully!'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() {
                          isSaving = false;
                          errorMessage = e.toString().replaceAll('Exception: ', '');
                        });
                      }
                    },
              child: isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Update Password'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('No active profile')),
      );
    }

    final isPastor = user.isPastor;
    final hasAvatar = user.avatarUrl != null && user.avatarUrl!.isNotEmpty;

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
              padding: const EdgeInsets.all(24),
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
                  // Avatar with Tap to Change
                  GestureDetector(
                    onTap: _showAvatarOptionsSheet,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 46,
                          backgroundColor: AppColors.navy,
                          backgroundImage: hasAvatar
                              ? CachedNetworkImageProvider(user.avatarUrl!)
                              : null,
                          child: _isUploadingAvatar
                              ? const CircularProgressIndicator(color: AppColors.gold)
                              : (!hasAvatar
                                  ? Text(
                                      user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'U',
                                      style: GoogleFonts.sourceSerif4(
                                        fontSize: 36,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.white,
                                      ),
                                    )
                                  : null),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.gold,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.white, width: 2),
                            ),
                            child: const Icon(Icons.camera_alt, color: AppColors.navyDark, size: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _showAvatarOptionsSheet,
                    child: const Text('Change photo', style: TextStyle(fontSize: 13, color: AppColors.navy, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 4),

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
                      onPressed: _confirmPastorTransfer,
                      child: const Text('I am being transferred'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Change Password Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.navy,
                  side: const BorderSide(color: AppColors.navy),
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.lock_outline),
                label: Text(
                  'Change Password',
                  style: GoogleFonts.nunitoSans(fontWeight: FontWeight.bold),
                ),
                onPressed: _showChangePasswordDialog,
              ),
            ),
            const SizedBox(height: 14),

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
}
