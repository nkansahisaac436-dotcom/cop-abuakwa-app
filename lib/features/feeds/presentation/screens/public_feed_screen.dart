import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/author_attribution_header.dart';
import '../../../../core/widgets/image_gallery_viewer.dart';
import '../../../auth/domain/models/profile_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/post_model.dart';
import '../providers/feeds_provider.dart';
import '../widgets/create_post_sheet.dart';

class PublicFeedScreen extends ConsumerWidget {
  const PublicFeedScreen({super.key});

  void _openCreatePost(BuildContext context, UserRole role) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreatePostSheet(
        defaultType: role == UserRole.areaHead
            ? PostType.announcement
            : role == UserRole.pastor
                ? PostType.thought
                : PostType.news,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(publicFeedProvider);
    final user = ref.watch(authStateProvider).value;
    final role = user?.role ?? UserRole.member;
    final canPost = role == UserRole.areaHead || role == UserRole.pastor || role == UserRole.ministryLeader;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(publicFeedProvider.notifier).refresh(),
          ),
        ],
      ),
      floatingActionButton: canPost
          ? FloatingActionButton.extended(
              heroTag: 'public_feed_fab',
              backgroundColor: AppColors.navy,
              foregroundColor: AppColors.white,
              icon: const Icon(Icons.edit),
              label: Text(
                role == UserRole.areaHead ? 'Announcement' : 'Post',
                style: GoogleFonts.nunitoSans(fontWeight: FontWeight.bold),
              ),
              onPressed: () => _openCreatePost(context, role),
            )
          : null,
      body: feedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text('Failed to load feed: $err'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.read(publicFeedProvider.notifier).refresh(),
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
        data: (posts) {
          if (posts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.feed_outlined, size: 56, color: AppColors.softGrey),
                  const SizedBox(height: 12),
                  Text(
                    'No posts in the Area feed yet.',
                    style: GoogleFonts.nunitoSans(
                      fontSize: 15,
                      color: AppColors.softGrey,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: posts.length,
            separatorBuilder: (_, _) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final post = posts[index];
              return _buildPostCard(context, post);
            },
          );
        },
      ),
    );
  }

  Widget _buildPostCard(BuildContext context, PostModel post) {
    final isAnnouncement = post.isAnnouncement;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isAnnouncement ? AppColors.gold.withValues(alpha: 0.5) : AppColors.border,
          width: isAnnouncement ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author Attribution Header with profile card modal
          AuthorAttributionHeader(
            authorName: post.authorName,
            authorRole: post.authorRole,
            authorAvatarUrl: post.authorAvatarUrl,
            districtName: post.districtName,
            ministryName: post.ministryName,
            timestamp: post.createdAt,
          ),
          const SizedBox(height: 12),

          // Title
          Text(
            post.title,
            style: GoogleFonts.sourceSerif4(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 8),

          // Body
          Text(
            post.body,
            style: GoogleFonts.nunitoSans(
              fontSize: 14,
              color: AppColors.text,
              height: 1.45,
            ),
          ),

          // Image Gallery Viewer if photos exist
          if (post.mediaUrls.isNotEmpty) ...[
            const SizedBox(height: 8),
            FeedImageGallery(imageUrls: post.mediaUrls),
          ],
        ],
      ),
    );
  }
}
