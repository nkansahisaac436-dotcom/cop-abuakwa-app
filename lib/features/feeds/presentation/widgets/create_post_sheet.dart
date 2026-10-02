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
import '../../../projects/domain/models/project_model.dart';
import '../../domain/models/post_model.dart';
import '../providers/feeds_provider.dart';

class CreatePostSheet extends ConsumerStatefulWidget {
  final PostType defaultType;
  final String? ministryId;

  const CreatePostSheet({
    super.key,
    this.defaultType = PostType.news,
    this.ministryId,
  });

  @override
  ConsumerState<CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends ConsumerState<CreatePostSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  List<MediaAttachment> _mediaAttachments = [];

  late PostType _type;
  late VisibilityLevel _visibility;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _type = widget.defaultType;
    if (_type == PostType.thought) {
      _visibility = VisibilityLevel.pastors;
    } else if (_type == PostType.announcement) {
      _visibility = VisibilityLevel.public;
    } else {
      _visibility = VisibilityLevel.public;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _submitPost() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = ref.read(authStateProvider).value;

      final mediaBytes = _mediaAttachments
          .where((m) => m.bytes != null)
          .map((m) => m.bytes!)
          .toList();

      final captions = _mediaAttachments
          .map((m) => m.caption ?? '')
          .toList();

      await ref.read(publicFeedProvider.notifier).createPost(
            title: _titleController.text,
            body: _bodyController.text,
            type: _type,
            visibility: _visibility,
            ministryId: widget.ministryId,
            districtId: user?.districtId,
            mediaBytes: mediaBytes,
            captions: captions,
          );

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post published successfully.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
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
    final user = ref.watch(authStateProvider).value;
    final isPastor = user?.isPastor ?? false;
    final isAreaHead = user?.isAreaHead ?? false;

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
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
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
              const SizedBox(height: 14),

              Text(
                _type == PostType.thought
                    ? 'Share Pastoral Thought'
                    : _type == PostType.announcement
                        ? 'Post Area Announcement'
                        : 'Create Post',
                style: GoogleFonts.sourceSerif4(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 16),

              // Title Field
              AppTextField(
                label: 'Title',
                hintText: 'Enter title or headline',
                controller: _titleController,
                validator: (v) => v == null || v.trim().isEmpty ? 'Title is required' : null,
              ),
              const SizedBox(height: 14),

              // Body Field
              AppTextField(
                label: 'Message / Content',
                hintText: 'Write your message...',
                controller: _bodyController,
                maxLines: 4,
                validator: (v) => v == null || v.trim().isEmpty ? 'Content is required' : null,
              ),
              const SizedBox(height: 14),

              // Photos Media Picker
              MediaPicker(
                initialMedia: _mediaAttachments,
                onMediaChanged: (list) {
                  setState(() {
                    _mediaAttachments = list;
                  });
                },
              ),
              const SizedBox(height: 14),

              // Visibility Selector with one-line explainer
              Text(
                'Visibility Level',
                style: GoogleFonts.nunitoSans(
                  fontSize: AppDimensions.fontSizeLabel,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: AppDimensions.inputBorderRadius,
                  border: Border.all(color: AppColors.border, width: 1.2),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<VisibilityLevel>(
                    isExpanded: true,
                    value: _visibility,
                    items: [
                      const DropdownMenuItem(
                        value: VisibilityLevel.public,
                        child: Text('Public (Everyone with the app)'),
                      ),
                      const DropdownMenuItem(
                        value: VisibilityLevel.members,
                        child: Text('Members (All logged-in church users)'),
                      ),
                      if (isPastor || isAreaHead)
                        const DropdownMenuItem(
                          value: VisibilityLevel.pastors,
                          child: Text('Pastors (Pastors and Area Head only)'),
                        ),
                      if (isAreaHead)
                        const DropdownMenuItem(
                          value: VisibilityLevel.areaHead,
                          child: Text('Area Head (Area Head office only)'),
                        ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _visibility = val;
                        });
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 6),

              // One-line explainer note
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: AppColors.navy),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _visibility.description,
                        style: GoogleFonts.nunitoSans(
                          fontSize: 12,
                          color: AppColors.softGrey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              PrimaryButton(
                text: 'Publish',
                isLoading: _isLoading,
                onPressed: _submitPost,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
