import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../auth/domain/models/profile_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../feeds/domain/models/post_model.dart';
import '../../../feeds/presentation/widgets/create_post_sheet.dart';
import '../../domain/models/ministry_model.dart';
import '../providers/ministries_provider.dart';

class MinistryDetailScreen extends ConsumerWidget {
  final MinistryModel ministry;

  const MinistryDetailScreen({super.key, required this.ministry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(ministryPostsProvider(ministry.id));
    final user = ref.watch(authStateProvider).value;

    // Check if user is leader of this ministry or Area Head
    final canPost = user?.isAreaHead ?? false ||
        (user?.role == UserRole.ministryLeader);

    return Scaffold(
      appBar: AppBar(
        title: Text(ministry.name),
      ),
      floatingActionButton: canPost
          ? FloatingActionButton.extended(
              heroTag: 'ministry_detail_fab',
              backgroundColor: AppColors.navy,
              foregroundColor: AppColors.white,
              icon: const Icon(Icons.edit),
              label: Text(
                'Post to ${ministry.name}',
                style: GoogleFonts.nunitoSans(fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => CreatePostSheet(
                    defaultType: PostType.news,
                    ministryId: ministry.id,
                  ),
                );
              },
            )
          : null,
      body: Column(
        children: [
          // Ministry Overview Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: AppColors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ministry.name,
                  style: GoogleFonts.sourceSerif4(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  ministry.description ?? '',
                  style: GoogleFonts.nunitoSans(fontSize: 13, color: AppColors.softGrey),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ministry.isFollowed ? AppColors.disabled : AppColors.navy,
                    foregroundColor: ministry.isFollowed ? AppColors.text : AppColors.white,
                    minimumSize: const Size(120, 36),
                    shape: const StadiumBorder(),
                  ),
                  icon: Icon(
                    ministry.isFollowed ? Icons.check : Icons.notifications_active_outlined,
                    size: 16,
                  ),
                  label: Text(
                    ministry.isFollowed ? 'Following Updates' : 'Follow Ministry',
                    style: GoogleFonts.nunitoSans(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  onPressed: () {
                    ref.read(ministriesListProvider.notifier).toggleFollow(ministry.id);
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          // Ministry News Feed
          Expanded(
            child: postsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error loading posts: $e')),
              data: (posts) {
                if (posts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.article_outlined, size: 52, color: AppColors.softGrey),
                        const SizedBox(height: 12),
                        Text(
                          'No announcements in ${ministry.name} yet.',
                          style: GoogleFonts.nunitoSans(color: AppColors.softGrey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: posts.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final post = posts[index];
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
                                post.authorName ?? 'Ministry Leader',
                                style: GoogleFonts.nunitoSans(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                DateFormat('MMM d, yyyy').format(post.createdAt),
                                style: GoogleFonts.nunitoSans(
                                  fontSize: 11,
                                  color: AppColors.softGrey,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            post.title,
                            style: GoogleFonts.sourceSerif4(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.navy,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            post.body,
                            style: GoogleFonts.nunitoSans(
                              fontSize: 14,
                              color: AppColors.text,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
