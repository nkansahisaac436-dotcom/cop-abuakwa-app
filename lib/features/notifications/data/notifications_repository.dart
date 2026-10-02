import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/network/supabase_client.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../domain/models/notification_model.dart';

abstract class NotificationsRepository {
  Future<List<AppNotificationModel>> getNotifications(String userId);
  Future<void> markAsRead(String notificationId);
}

class SupabaseNotificationsRepository implements NotificationsRepository {
  final SupabaseClient? _client;

  SupabaseNotificationsRepository([this._client]);

  SupabaseClient get _sb => _client ?? SupabaseConfig.client;

  // In-memory runtime storage for offline / mock testing (starts empty)
  static final List<AppNotificationModel> _inMemoryNotifications = [];

  static void resetState() {
    _inMemoryNotifications.clear();
  }

  @override
  Future<List<AppNotificationModel>> getNotifications(String userId) async {
    if (!SupabaseConfig.isInitialized) {
      return List.unmodifiable(_inMemoryNotifications.where((n) => n.userId == userId).toList());
    }
    try {
      final res = await _sb
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return (res as List).map((j) => AppNotificationModel.fromJson(j)).toList();
    } catch (e) {
      debugPrint('[NotificationsRepository] Error fetching notifications: $e');
      return _inMemoryNotifications.where((n) => n.userId == userId).toList();
    }
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    final idx = _inMemoryNotifications.indexWhere((n) => n.id == notificationId);
    if (idx != -1) {
      _inMemoryNotifications[idx] = _inMemoryNotifications[idx].copyWith(read: true);
    }

    if (SupabaseConfig.isInitialized) {
      try {
        await _sb.from('notifications').update({'read': true}).eq('id', notificationId);
      } catch (e) {
        debugPrint('[NotificationsRepository] Error marking read: $e');
      }
    }
  }
}

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  return SupabaseNotificationsRepository();
});

final userNotificationsProvider = FutureProvider<List<AppNotificationModel>>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return [];
  final repo = ref.watch(notificationsRepositoryProvider);
  return repo.getNotifications(user.id);
});
