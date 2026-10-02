import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../constants/app_colors.dart';
import '../utils/image_compressor.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';

class AvatarOnboardingPrompt {
  AvatarOnboardingPrompt._();

  static Future<void> showIfNoAvatar(BuildContext context, WidgetRef ref) async {
    final user = ref.read(authStateProvider).value;
    if (user == null || (user.avatarUrl != null && user.avatarUrl!.isNotEmpty)) {
      return;
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _AvatarPromptDialog(),
    );
  }
}

class _AvatarPromptDialog extends ConsumerStatefulWidget {
  const _AvatarPromptDialog();

  @override
  ConsumerState<_AvatarPromptDialog> createState() => _AvatarPromptDialogState();
}

class _AvatarPromptDialogState extends ConsumerState<_AvatarPromptDialog> {
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source);
      if (picked == null) return;

      setState(() => _isUploading = true);

      final rawBytes = await picked.readAsBytes();
      final compressed = await ImageCompressor.compressAvatar(rawBytes, size: 512);

      await ref.read(authStateProvider.notifier).uploadAvatar(compressed);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo added! Members will now recognize your posts and updates.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading photo: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.disabled,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_a_photo_outlined, size: 40, color: AppColors.navy),
            ),
            const SizedBox(height: 16),
            Text(
              'Add your photo so members know you',
              style: GoogleFonts.sourceSerif4(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.navyDark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Having a profile picture helps church members and pastors easily recognize you on district updates and announcements.',
              style: TextStyle(fontSize: 13, color: AppColors.softGrey, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (_isUploading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: CircularProgressIndicator(color: AppColors.gold),
              )
            else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navy,
                    foregroundColor: AppColors.white,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.camera_alt, size: 18),
                  label: const Text('Take photo', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () => _pickPhoto(ImageSource.camera),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.photo_library, size: 18, color: AppColors.navy),
                  label: const Text('Choose from gallery', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold)),
                  onPressed: () => _pickPhoto(ImageSource.gallery),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Skip for now', style: TextStyle(color: AppColors.softGrey, fontSize: 13)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
