import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/media_attachment.dart';

class FeedImageGallery extends StatefulWidget {
  final List<String> imageUrls;
  final List<MediaAttachment>? mediaItems;
  final double height;

  const FeedImageGallery({
    super.key,
    required this.imageUrls,
    this.mediaItems,
    this.height = 240,
  });

  @override
  State<FeedImageGallery> createState() => _FeedImageGalleryState();
}

class _FeedImageGalleryState extends State<FeedImageGallery> {
  int _currentPage = 0;
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _openFullScreen(int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => FullScreenGalleryViewer(
          imageUrls: widget.imageUrls,
          mediaItems: widget.mediaItems,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrls.isEmpty) return const SizedBox.shrink();

    final count = widget.imageUrls.length;

    return Container(
      height: widget.height,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.black12,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: count,
            onPageChanged: (idx) => setState(() => _currentPage = idx),
            itemBuilder: (context, index) {
              final url = widget.imageUrls[index];
              return GestureDetector(
                onTap: () => _openFullScreen(index),
                child: Hero(
                  tag: 'gallery_img_$url',
                  child: CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: AppColors.disabled,
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: AppColors.disabled,
                      child: const Icon(Icons.broken_image_outlined, color: AppColors.softGrey, size: 36),
                    ),
                  ),
                ),
              );
            },
          ),
          if (count > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(count, (index) {
                  final isSelected = index == _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: isSelected ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.gold : Colors.white70,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}

class FullScreenGalleryViewer extends StatefulWidget {
  final List<String> imageUrls;
  final List<MediaAttachment>? mediaItems;
  final int initialIndex;

  const FullScreenGalleryViewer({
    super.key,
    required this.imageUrls,
    this.mediaItems,
    this.initialIndex = 0,
  });

  @override
  State<FullScreenGalleryViewer> createState() => _FullScreenGalleryViewerState();
}

class _FullScreenGalleryViewerState extends State<FullScreenGalleryViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.imageUrls.length;

    String? currentCaption;
    if (widget.mediaItems != null && _currentIndex < widget.mediaItems!.length) {
      currentCaption = widget.mediaItems![_currentIndex].caption;
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: count > 1
            ? Text(
                '${_currentIndex + 1} / $count',
                style: const TextStyle(fontSize: 16, color: Colors.white70),
              )
            : null,
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: count,
            onPageChanged: (idx) => setState(() => _currentIndex = idx),
            itemBuilder: (context, index) {
              final url = widget.imageUrls[index];
              return InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: Center(
                  child: Hero(
                    tag: 'gallery_img_$url',
                    child: CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.contain,
                      placeholder: (context, url) => const CircularProgressIndicator(color: AppColors.gold),
                      errorWidget: (context, url, error) => const Icon(Icons.broken_image, color: Colors.white54, size: 48),
                    ),
                  ),
                ),
              );
            },
          ),
          if (currentCaption != null && currentCaption.isNotEmpty)
            Positioned(
              left: 16,
              right: 16,
              bottom: 32,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  currentCaption,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
