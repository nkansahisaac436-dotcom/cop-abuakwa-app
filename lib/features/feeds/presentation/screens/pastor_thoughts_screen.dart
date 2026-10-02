import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/author_attribution_header.dart';
import '../../../../core/widgets/image_gallery_viewer.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/post_model.dart';
import '../providers/feeds_provider.dart';
import '../widgets/create_post_sheet.dart';

class PastorThoughtsScreen extends ConsumerWidget {
  const PastorThoughtsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thoughtsAsync = ref.watch(thoughtsFeedProvider);
    final user = ref.watch(authStateProvider).value;
    final canPost = user?.isPastor ?? false || (user?.isAreaHead ?? false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pastoral Thoughts'),
      ),
      floatingActionButton: canPost
          ? FloatingActionButton.extended(
              heroTag: 'pastor_thoughts_fab',
              backgroundColor: AppColors.navy,
              foregroundColor: AppColors.white,
              icon: const Icon(Icons.edit_note),
              label: Text(
                'Share Thought',
                style: GoogleFonts.nunitoSans(fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const CreatePostSheet(
                    defaultType: PostType.thought,
                  ),
                );
              },
            )
          : null,
      body: thoughtsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (thoughts) {
          if (thoughts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.psychology_outlined, size: 56, color: AppColors.softGrey),
                  const SizedBox(height: 12),
                  Text(
                    'No pastoral thoughts shared yet.',
                    style: GoogleFonts.nunitoSans(fontSize: 15, color: AppColors.softGrey),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: thoughts.length,
            separatorBuilder: (_, _) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final thought = thoughts[index];
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AuthorAttributionHeader(
                      authorName: thought.authorName,
                      authorRole: thought.authorRole ?? 'pastor',
                      authorAvatarUrl: thought.authorAvatarUrl,
                      districtName: thought.districtName,
                      ministryName: thought.ministryName,
                      timestamp: thought.createdAt,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      thought.title,
                      style: GoogleFonts.sourceSerif4(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      thought.body,
                      style: GoogleFonts.nunitoSans(
                        fontSize: 14,
                        color: AppColors.text,
                        height: 1.4,
                      ),
                    ),
                    if (thought.mediaUrls.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      FeedImageGallery(imageUrls: thought.mediaUrls),
                    ],
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
