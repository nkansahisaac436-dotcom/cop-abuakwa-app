import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/network/supabase_client.dart';
import '../../auth/domain/models/profile_model.dart';
import '../../projects/domain/models/project_model.dart';
import '../domain/models/post_model.dart';

abstract class FeedsRepository {
  Future<List<PostModel>> getFeedPosts({
    required UserRole userRole,
    String? ministryId,
    PostType? postType,
  });
  Future<PostModel> createPost({
    required String authorId,
    required String authorName,
    required String authorRole,
    required String title,
    required String body,
    required PostType type,
    required VisibilityLevel visibility,
    String? ministryId,
    String? districtId,
    String? tenureId,
  });
}

class SupabaseFeedsRepository implements FeedsRepository {
  final SupabaseClient? _client;

  SupabaseFeedsRepository([this._client]);

  SupabaseClient get _sb => _client ?? SupabaseConfig.client;

  static final List<PostModel> _mockPosts = [
    PostModel(
      id: 'post-1',
      authorId: 'area-head-user',
      authorName: 'Apostle Area Head',
      authorRole: 'area_head',
      type: PostType.announcement,
      title: '2026 Abuakwa Area Half-Year Ministers & Officers Conference',
      body: 'Grace and peace be unto you in Jesus name. The Area Head Office announces the upcoming ministers and officers retreat scheduled for 15th-18th October at the Area Central Auditorium.',
      visibility: VisibilityLevel.public,
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    PostModel(
      id: 'post-2',
      authorId: 'pastor-1',
      authorName: 'Pastor Enoch Agyemang',
      authorRole: 'pastor',
      type: PostType.thought,
      title: 'Leading with Endurance in Ministry',
      body: 'Reflecting on 2 Timothy 4:5 this morning. Ministry in our 33 districts requires staying watchful and enduring hardships while fulfilling our sacred calling with joy.',
      visibility: VisibilityLevel.pastors,
      districtId: 'd0000000-0000-0000-0000-000000000002',
      districtName: 'Abuakwa North',
      createdAt: DateTime.now().subtract(const Duration(hours: 6)),
    ),
    PostModel(
      id: 'post-3',
      authorId: 'leader-women',
      authorName: 'Deaconess Mary Mensah',
      authorRole: 'ministry_leader',
      type: PostType.news,
      title: 'Women\'s Ministry Area Outreach at Sepaase',
      body: 'The Women\'s Ministry held a powerful medical and spiritual outreach at Sepaase District yesterday. Over 250 women and mothers were ministered to with supplies and the gospel.',
      visibility: VisibilityLevel.public,
      ministryId: 'a0000000-0000-0000-0000-000000000005',
      ministryName: 'Women\'s Ministry',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  @override
  Future<List<PostModel>> getFeedPosts({
    required UserRole userRole,
    String? ministryId,
    PostType? postType,
  }) async {
    if (!SupabaseConfig.isInitialized) {
      return _mockPosts.where((post) {
        if (ministryId != null && post.ministryId != ministryId) return false;
        if (postType != null && post.type != postType) return false;

        // Apply RLS Visibility Logic in Mock mode
        if (userRole == UserRole.member) {
          return post.visibility == VisibilityLevel.public ||
              post.visibility == VisibilityLevel.members;
        } else if (userRole == UserRole.pastor) {
          return post.visibility != VisibilityLevel.areaHead;
        }
        return true; // Area Head sees all
      }).toList();
    }

    try {
      var query = _sb.from('posts').select();
      if (ministryId != null) {
        query = query.eq('ministry_id', ministryId);
      }
      if (postType != null) {
        query = query.eq('type', postType.value);
      }
      final res = await query.order('created_at', ascending: false);
      return (res as List).map((j) => PostModel.fromJson(j)).toList();
    } catch (e) {
      debugPrint('[FeedsRepository] Error fetching posts: $e');
      return _mockPosts;
    }
  }

  @override
  Future<PostModel> createPost({
    required String authorId,
    required String authorName,
    required String authorRole,
    required String title,
    required String body,
    required PostType type,
    required VisibilityLevel visibility,
    String? ministryId,
    String? districtId,
    String? tenureId,
  }) async {
    final newPost = PostModel(
      id: 'post-${DateTime.now().millisecondsSinceEpoch}',
      authorId: authorId,
      authorName: authorName,
      authorRole: authorRole,
      type: type,
      title: title.trim(),
      body: body.trim(),
      visibility: visibility,
      ministryId: ministryId,
      districtId: districtId,
      tenureId: tenureId,
      createdAt: DateTime.now(),
    );

    _mockPosts.insert(0, newPost);

    if (SupabaseConfig.isInitialized) {
      try {
        await _sb.from('posts').insert(newPost.toJson());
      } catch (e) {
        debugPrint('[FeedsRepository] Remote insert error: $e');
      }
    }

    return newPost;
  }
}
