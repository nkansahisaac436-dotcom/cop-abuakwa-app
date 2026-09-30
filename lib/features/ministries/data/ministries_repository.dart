import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/network/supabase_client.dart';
import '../domain/models/ministry_model.dart';

abstract class MinistriesRepository {
  Future<List<MinistryModel>> getMinistries({String? userId});
  Future<void> toggleFollowMinistry({required String userId, required String ministryId, required bool follow});
}

class SupabaseMinistriesRepository implements MinistriesRepository {
  final SupabaseClient? _client;

  SupabaseMinistriesRepository([this._client]);

  SupabaseClient get _sb => _client ?? SupabaseConfig.client;

  static final List<MinistryModel> _mockMinistries = [
    MinistryModel(
      id: 'a0000000-0000-0000-0000-000000000001',
      name: 'Youth Ministry',
      code: 'youth',
      description: 'Equipping youth for Christ, excellence, and Area evangelism.',
      iconName: 'people',
      createdAt: DateTime(2026, 1, 1),
    ),
    MinistryModel(
      id: 'a0000000-0000-0000-0000-000000000002',
      name: 'Evangelism Ministry',
      code: 'evangelism',
      description: 'Reaching every community and soul-winning across Abuakwa Area.',
      iconName: 'campaign',
      createdAt: DateTime(2026, 1, 1),
    ),
    MinistryModel(
      id: 'a0000000-0000-0000-0000-000000000003',
      name: "Children's Ministry",
      code: 'childrens',
      description: 'Nurturing the faith and biblical foundation of children.',
      iconName: 'child_care',
      createdAt: DateTime(2026, 1, 1),
    ),
    MinistryModel(
      id: 'a0000000-0000-0000-0000-000000000004',
      name: 'Pentecost Men\'s Movement (PEMEM)',
      code: 'pemem',
      description: 'Fostering godly brotherhood, leadership, and family integrity.',
      iconName: 'shield',
      createdAt: DateTime(2026, 1, 1),
    ),
    MinistryModel(
      id: 'a0000000-0000-0000-0000-000000000005',
      name: "Women's Ministry",
      code: 'womens',
      description: 'Empowering women in faith, discipleship, and practical ministry.',
      iconName: 'favorite',
      createdAt: DateTime(2026, 1, 1),
    ),
  ];

  static final Set<String> _mockFollowed = {};

  @override
  Future<List<MinistryModel>> getMinistries({String? userId}) async {
    if (!SupabaseConfig.isInitialized) {
      return _mockMinistries.map((m) {
        final key = '${userId}_${m.id}';
        return m.copyWith(isFollowed: _mockFollowed.contains(key));
      }).toList();
    }

    try {
      final res = await _sb.from('ministries').select().order('name');
      final list = (res as List).map((j) => MinistryModel.fromJson(j)).toList();

      if (userId != null) {
        final followsRes = await _sb
            .from('ministry_follows')
            .select('ministry_id')
            .eq('user_id', userId);
        final followedIds = (followsRes as List).map((f) => f['ministry_id'] as String).toSet();
        return list.map((m) => m.copyWith(isFollowed: followedIds.contains(m.id))).toList();
      }

      return list;
    } catch (e) {
      debugPrint('[MinistriesRepository] Error fetching ministries: $e');
      return _mockMinistries;
    }
  }

  @override
  Future<void> toggleFollowMinistry({
    required String userId,
    required String ministryId,
    required bool follow,
  }) async {
    final key = '${userId}_$ministryId';
    if (follow) {
      _mockFollowed.add(key);
    } else {
      _mockFollowed.remove(key);
    }

    if (SupabaseConfig.isInitialized) {
      try {
        if (follow) {
          await _sb.from('ministry_follows').insert({
            'user_id': userId,
            'ministry_id': ministryId,
          });
        } else {
          await _sb
              .from('ministry_follows')
              .delete()
              .eq('user_id', userId)
              .eq('ministry_id', ministryId);
        }
      } catch (e) {
        debugPrint('[MinistriesRepository] Error toggling follow: $e');
      }
    }
  }
}
