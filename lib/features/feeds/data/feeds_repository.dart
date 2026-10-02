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
    String? authorAvatarUrl,
    required String title,
    required String body,
    required PostType type,
    required VisibilityLevel visibility,
    String? ministryId,
    String? ministryName,
    String? districtId,
    String? districtName,
    String? tenureId,
    List<String> mediaUrls = const [],
    List<Uint8List> mediaBytes = const [],
    List<String> captions = const [],
  });
}

class SupabaseFeedsRepository implements FeedsRepository {
  final SupabaseClient? _client;

  SupabaseFeedsRepository([this._client]);

  SupabaseClient get _sb => _client ?? SupabaseConfig.client;

  // In-memory runtime storage for offline / mock testing (starts empty)
  static final List<PostModel> _inMemoryPosts = [];

  static void resetState() {
    _inMemoryPosts.clear();
  }

  @override
  Future<List<PostModel>> getFeedPosts({
    required UserRole userRole,
    String? ministryId,
    PostType? postType,
  }) async {
    if (!SupabaseConfig.isInitialized) {
      return _inMemoryPosts.where((post) {
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
      var query = _sb.from('posts').select(
        '*, profiles:author_id(full_name, role, avatar_url), ministries(name), districts(name), media(id, url, caption, sort_order)',
      );
      if (ministryId != null) {
        query = query.eq('ministry_id', ministryId);
      }
      if (postType != null) {
        query = query.eq('type', postType.value);
      }
      final res = await query.order('created_at', ascending: false);

      return (res as List).map((j) {
        final profile = j['profiles'] as Map<String, dynamic>?;
        final ministry = j['ministries'] as Map<String, dynamic>?;
        final district = j['districts'] as Map<String, dynamic>?;
        final mediaList = j['media'] as List<dynamic>?;

        final map = Map<String, dynamic>.from(j);
        if (profile != null) {
          map['author_name'] = profile['full_name'];
          map['author_role'] = profile['role'];
          map['author_avatar_url'] = profile['avatar_url'];
        }
        if (ministry != null) map['ministry_name'] = ministry['name'];
        if (district != null) map['district_name'] = district['name'];

        if (mediaList != null && mediaList.isNotEmpty) {
          map['media_urls'] = mediaList
              .map((m) => m is Map ? m['url'] : m.toString())
              .where((u) => u != null && u.toString().isNotEmpty)
              .toList();
        }

        return PostModel.fromJson(map);
      }).toList();
    } catch (e) {
      debugPrint('[FeedsRepository] Error fetching posts: $e');
      return _inMemoryPosts;
    }
  }

  @override
  Future<PostModel> createPost({
    required String authorId,
    required String authorName,
    required String authorRole,
    String? authorAvatarUrl,
    required String title,
    required String body,
    required PostType type,
    required VisibilityLevel visibility,
    String? ministryId,
    String? ministryName,
    String? districtId,
    String? districtName,
    String? tenureId,
    List<String> mediaUrls = const [],
    List<Uint8List> mediaBytes = const [],
    List<String> captions = const [],
  }) async {
    final postId = 'post-${DateTime.now().millisecondsSinceEpoch}';
    final uploadedUrls = List<String>.from(mediaUrls);

    // If there are raw bytes to upload to Supabase Storage
    if (SupabaseConfig.isInitialized && mediaBytes.isNotEmpty) {
      for (int i = 0; i < mediaBytes.length; i++) {
        try {
          final fileName = 'posts/$authorId/${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
          await _sb.storage.from('post_media').uploadBinary(
            fileName,
            mediaBytes[i],
            fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
          );
          // For private bucket, get signed URL or public URL
          final signedUrlRes = await _sb.storage.from('post_media').createSignedUrl(fileName, 60 * 60 * 24 * 365);
          uploadedUrls.add(signedUrlRes);
        } catch (e) {
          debugPrint('[FeedsRepository] Error uploading post image: $e');
        }
      }
    }

    final newPost = PostModel(
      id: postId,
      authorId: authorId,
      authorName: authorName,
      authorRole: authorRole,
      type: type,
      title: title.trim(),
      body: body.trim(),
      visibility: visibility,
      ministryId: ministryId,
      ministryName: ministryName,
      districtId: districtId,
      districtName: districtName,
      tenureId: tenureId,
      mediaUrls: uploadedUrls,
      createdAt: DateTime.now(),
    );

    _inMemoryPosts.insert(0, newPost);

    if (SupabaseConfig.isInitialized) {
      try {
        final inserted = await _sb.from('posts').insert({
          'author_id': authorId,
          'type': type.value,
          'title': title.trim(),
          'body': body.trim(),
          'visibility': visibility.value,
          'ministry_id': ministryId,
          'district_id': districtId,
          'tenure_id': tenureId,
        }).select().single();

        final actualPostId = inserted['id'] as String;

        // Save media table records
        for (int i = 0; i < uploadedUrls.length; i++) {
          final cap = i < captions.length ? captions[i] : null;
          await _sb.from('media').insert({
            'post_id': actualPostId,
            'owner_type': 'post',
            'owner_id': actualPostId,
            'url': uploadedUrls[i],
            'caption': cap,
            'sort_order': i,
            'created_by': authorId,
          });
        }
      } catch (e) {
        debugPrint('[FeedsRepository] Remote insert error: $e');
        rethrow;
      }
    }

    return newPost;
  }
}
