import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cop_abuakwa_app/features/auth/domain/models/profile_model.dart';
import 'package:cop_abuakwa_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:cop_abuakwa_app/features/feeds/data/feeds_repository.dart';
import 'package:cop_abuakwa_app/features/feeds/domain/models/post_model.dart';
import 'package:cop_abuakwa_app/features/projects/domain/models/project_model.dart';

final feedsRepositoryProvider = Provider<FeedsRepository>((ref) {
  return SupabaseFeedsRepository();
});

final publicFeedProvider = AsyncNotifierProvider<PublicFeedNotifier, List<PostModel>>(() {
  return PublicFeedNotifier();
});

class PublicFeedNotifier extends AsyncNotifier<List<PostModel>> {
  @override
  Future<List<PostModel>> build() async {
    final repo = ref.watch(feedsRepositoryProvider);
    final user = ref.watch(authStateProvider).value;
    final role = user?.role ?? UserRole.member;
    return repo.getFeedPosts(userRole: role);
  }

  Future<void> createPost({
    required String title,
    required String body,
    required PostType type,
    required VisibilityLevel visibility,
    String? ministryId,
    String? districtId,
  }) async {
    final repo = ref.read(feedsRepositoryProvider);
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    final newPost = await repo.createPost(
      authorId: user.id,
      authorName: user.fullName,
      authorRole: user.role.value,
      title: title,
      body: body,
      type: type,
      visibility: visibility,
      ministryId: ministryId,
      districtId: districtId,
    );

    state = AsyncValue.data([newPost, ...?state.value]);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    final repo = ref.read(feedsRepositoryProvider);
    final user = ref.read(authStateProvider).value;
    final role = user?.role ?? UserRole.member;
    state = AsyncValue.data(await repo.getFeedPosts(userRole: role));
  }
}

final thoughtsFeedProvider = FutureProvider<List<PostModel>>((ref) async {
  final repo = ref.watch(feedsRepositoryProvider);
  final user = ref.watch(authStateProvider).value;
  final role = user?.role ?? UserRole.member;
  return repo.getFeedPosts(userRole: role, postType: PostType.thought);
});
