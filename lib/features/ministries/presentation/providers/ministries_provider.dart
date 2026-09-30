import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cop_abuakwa_app/features/auth/domain/models/profile_model.dart';
import 'package:cop_abuakwa_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:cop_abuakwa_app/features/feeds/domain/models/post_model.dart';
import 'package:cop_abuakwa_app/features/feeds/presentation/providers/feeds_provider.dart';
import 'package:cop_abuakwa_app/features/ministries/data/ministries_repository.dart';
import 'package:cop_abuakwa_app/features/ministries/domain/models/ministry_model.dart';

final ministriesRepositoryProvider = Provider<MinistriesRepository>((ref) {
  return SupabaseMinistriesRepository();
});

final ministriesListProvider = AsyncNotifierProvider<MinistriesNotifier, List<MinistryModel>>(() {
  return MinistriesNotifier();
});

class MinistriesNotifier extends AsyncNotifier<List<MinistryModel>> {
  @override
  Future<List<MinistryModel>> build() async {
    final repo = ref.watch(ministriesRepositoryProvider);
    final user = ref.watch(authStateProvider).value;
    return repo.getMinistries(userId: user?.id);
  }

  Future<void> toggleFollow(String ministryId) async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    final repo = ref.read(ministriesRepositoryProvider);
    final currentList = state.value ?? [];
    final target = currentList.firstWhere((m) => m.id == ministryId);
    final willFollow = !target.isFollowed;

    await repo.toggleFollowMinistry(
      userId: user.id,
      ministryId: ministryId,
      follow: willFollow,
    );

    state = AsyncValue.data(
      currentList.map((m) {
        if (m.id == ministryId) {
          return m.copyWith(isFollowed: willFollow);
        }
        return m;
      }).toList(),
    );
  }
}

final ministryPostsProvider = FutureProvider.family<List<PostModel>, String>((ref, ministryId) async {
  final repo = ref.watch(feedsRepositoryProvider);
  final user = ref.watch(authStateProvider).value;
  return repo.getFeedPosts(
    userRole: user?.role ?? UserRole.member,
    ministryId: ministryId,
  );
});
