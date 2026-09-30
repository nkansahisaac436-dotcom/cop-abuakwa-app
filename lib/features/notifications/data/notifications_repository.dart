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

  static final List<AppNotificationModel> _mockNotifications = [
    AppNotificationModel(
      id: 'notif-1',
      userId: 'mock-pastor-id',
      title: 'Area Announcements Released',
      body: 'Apostle Area Head posted the 2026 Half-Year Ministers & Officers Conference schedule.',
      read: false,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    AppNotificationModel(
      id: 'notif-2',
      userId: 'mock-pastor-id',
      title: 'Upcoming Fellowship Call',
      body: 'Monthly Abuakwa Pastors Fellowship Call is scheduled for 3:00 PM today.',
      read: true,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  @override
  Future<List<AppNotificationModel>> getNotifications(String userId) async {
    if (!SupabaseConfig.isInitialized) {
      return List.unmodifiable(_mockNotifications);
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
      return _mockNotifications;
    }
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    final idx = _mockNotifications.indexWhere((n) => n.id == notificationId);
    if (idx != -1) {
      _mockNotifications[idx] = _mockNotifications[idx].copyWith(read: true);
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
