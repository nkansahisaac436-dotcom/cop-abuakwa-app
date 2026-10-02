import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../constants/app_colors.dart';
import '../models/media_attachment.dart';
import '../utils/image_compressor.dart';

class MediaPicker extends StatefulWidget {
  final List<MediaAttachment> initialMedia;
  final ValueChanged<List<MediaAttachment>> onMediaChanged;
  final int maxImages;
  final bool isUploading;
  final double? uploadProgress;

  const MediaPicker({
    super.key,
    this.initialMedia = const [],
    required this.onMediaChanged,
    this.maxImages = 5,
    this.isUploading = false,
    this.uploadProgress,
  });

  @override
  State<MediaPicker> createState() => _MediaPickerState();
}

class _MediaPickerState extends State<MediaPicker> {
  final ImagePicker _picker = ImagePicker();
  late List<MediaAttachment> _mediaList;

  @override
  void initState() {
    super.initState();
    _mediaList = List.from(widget.initialMedia);
  }

  @override
  void didUpdateWidget(covariant MediaPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialMedia != oldWidget.initialMedia && widget.initialMedia != _mediaList) {
      _mediaList = List.from(widget.initialMedia);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_mediaList.length >= widget.maxImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You can add up to ${widget.maxImages} photos.')),
      );
      return;
    }

    try {
      if (source == ImageSource.gallery) {
        final remaining = widget.maxImages - _mediaList.length;
        if (remaining > 1) {
          final pickedFiles = await _picker.pickMultiImage(limit: remaining);
          if (pickedFiles.isNotEmpty) {
            for (final file in pickedFiles) {
              await _processAndAddFile(file);
            }
            return;
          }
        }
      }

      final picked = await _picker.pickImage(source: source);
      if (picked != null) {
        await _processAndAddFile(picked);
      }
    } catch (e) {
      debugPrint('[MediaPicker] Error picking image: $e');
      if (mounted) {
        _showPermissionErrorDialog();
      }
    }
  }

  Future<void> _processAndAddFile(XFile file) async {
    final rawBytes = await file.readAsBytes();
    final compressed = await ImageCompressor.compressPostImage(rawBytes);

    final newAttachment = MediaAttachment(
      id: const Uuid().v4(),
      localPath: file.path,
      bytes: compressed,
      sortOrder: _mediaList.length,
    );

    setState(() {
      _mediaList.add(newAttachment);
    });
    widget.onMediaChanged(_mediaList);
  }

  void _removeMedia(int index) {
    setState(() {
      _mediaList.removeAt(index);
      for (int i = 0; i < _mediaList.length; i++) {
        _mediaList[i] = _mediaList[i].copyWith(sortOrder: i);
      }
    });
    widget.onMediaChanged(_mediaList);
  }

  void _editCaption(int index) {
    final current = _mediaList[index];
    final controller = TextEditingController(text: current.caption ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Photo Caption', style: TextStyle(fontFamily: 'Source Serif 4', fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Add a brief caption (optional)...',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.navy,
              foregroundColor: AppColors.white,
            ),
            onPressed: () {
              setState(() {
                _mediaList[index] = current.copyWith(caption: controller.text.trim());
              });
              widget.onMediaChanged(_mediaList);
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showSourcePicker() {
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
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.disabled,
                  child: Icon(Icons.camera_alt, color: AppColors.navy),
                ),
                title: const Text('Take photo', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
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
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPermissionErrorDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Permission Required'),
        content: const Text(
          'Please allow camera and photo library permissions in your device settings to attach photos to your posts and projects.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Photos (${_mediaList.length}/${widget.maxImages})',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            if (_mediaList.length < widget.maxImages)
              TextButton.icon(
                onPressed: widget.isUploading ? null : _showSourcePicker,
                icon: const Icon(Icons.add_a_photo_outlined, size: 18, color: AppColors.navy),
                label: const Text('Add Photo', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        if (widget.isUploading) ...[
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: widget.uploadProgress,
            backgroundColor: AppColors.disabled,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.gold),
          ),
          const SizedBox(height: 4),
          const Text('Uploading photos...', style: TextStyle(fontSize: 12, color: AppColors.softGrey)),
        ],
        if (_mediaList.isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 110,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _mediaList.length,
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final item = _mediaList[index];
                return Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                        color: AppColors.disabled,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => _editCaption(index),
                        child: item.bytes != null
                            ? Image.memory(item.bytes!, fit: BoxFit.cover)
                            : (item.url != null
                                ? Image.network(item.url!, fit: BoxFit.cover)
                                : const Center(child: Icon(Icons.image, color: AppColors.softGrey))),
                      ),
                    ),
                    PositionTileCaptionBadge(
                      hasCaption: item.caption != null && item.caption!.isNotEmpty,
                      onTap: () => _editCaption(index),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => _removeMedia(index),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class PositionTileCaptionBadge extends StatelessWidget {
  final bool hasCaption;
  final VoidCallback onTap;

  const PositionTileCaptionBadge({
    super.key,
    required this.hasCaption,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 4,
      left: 4,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: hasCaption ? AppColors.gold : Colors.black45,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                hasCaption ? Icons.chat_bubble : Icons.chat_bubble_outline,
                size: 10,
                color: Colors.white,
              ),
              const SizedBox(width: 3),
              Text(
                hasCaption ? 'Caption' : '+Cap',
                style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
