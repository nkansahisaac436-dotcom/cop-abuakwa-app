import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '../../../core/network/supabase_client.dart';
import '../../auth/domain/models/profile_model.dart';
import '../domain/models/meeting_model.dart';

abstract class MeetingsRepository {
  Future<List<MeetingModel>> getMeetings({required UserRole userRole});
  Future<MeetingModel> createInstantMeeting({
    required String title,
    required String createdBy,
    required String creatorName,
    UserRole audience = UserRole.pastor,
  });
  Future<MeetingModel> scheduleMeeting({
    required String title,
    required DateTime scheduledAt,
    required String createdBy,
    required String creatorName,
    UserRole audience = UserRole.pastor,
  });
  Future<void> launchMeetingUrl(String url);
}

class SupabaseMeetingsRepository implements MeetingsRepository {
  final SupabaseClient? _client;

  SupabaseMeetingsRepository([this._client]);

  SupabaseClient get _sb => _client ?? SupabaseConfig.client;

  static final List<MeetingModel> _mockMeetings = [
    MeetingModel(
      id: 'meet-1',
      title: 'Monthly Abuakwa Pastors Fellowship Call',
      roomLink: 'https://meet.jit.si/Abuakwa_Pastors_Fellowship_2026#config.startWithAudioOnly=true',
      scheduledAt: DateTime.now().add(const Duration(hours: 3)),
      audience: UserRole.pastor,
      createdBy: 'area-head-user',
      creatorName: 'Apostle Area Head',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  @override
  Future<List<MeetingModel>> getMeetings({required UserRole userRole}) async {
    if (!SupabaseConfig.isInitialized) {
      return List.unmodifiable(_mockMeetings);
    }
    try {
      final res = await _sb.from('meetings').select().order('scheduled_at', ascending: true);
      return (res as List).map((j) => MeetingModel.fromJson(j)).toList();
    } catch (e) {
      debugPrint('[MeetingsRepository] Error fetching meetings: $e');
      return _mockMeetings;
    }
  }

  @override
  Future<MeetingModel> createInstantMeeting({
    required String title,
    required String createdBy,
    required String creatorName,
    UserRole audience = UserRole.pastor,
  }) async {
    final roomId = const Uuid().v4().substring(0, 8);
    final roomName = 'Abuakwa_${title.replaceAll(' ', '_')}_$roomId';
    // Append audio-only default config flags to save data
    final roomLink = 'https://meet.jit.si/$roomName#config.startWithAudioOnly=true&config.startWithVideoMuted=true';

    final newMeeting = MeetingModel(
      id: 'meet-${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      roomLink: roomLink,
      scheduledAt: DateTime.now(),
      audience: audience,
      createdBy: createdBy,
      creatorName: creatorName,
      createdAt: DateTime.now(),
    );

    _mockMeetings.insert(0, newMeeting);

    if (SupabaseConfig.isInitialized) {
      try {
        await _sb.from('meetings').insert(newMeeting.toJson());
      } catch (e) {
        debugPrint('[MeetingsRepository] Remote meeting creation error: $e');
      }
    }

    return newMeeting;
  }

  @override
  Future<MeetingModel> scheduleMeeting({
    required String title,
    required DateTime scheduledAt,
    required String createdBy,
    required String creatorName,
    UserRole audience = UserRole.pastor,
  }) async {
    final roomId = const Uuid().v4().substring(0, 8);
    final roomName = 'Abuakwa_${title.replaceAll(' ', '_')}_$roomId';
    final roomLink = 'https://meet.jit.si/$roomName#config.startWithAudioOnly=true&config.startWithVideoMuted=true';

    final newMeeting = MeetingModel(
      id: 'meet-${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      roomLink: roomLink,
      scheduledAt: scheduledAt,
      audience: audience,
      createdBy: createdBy,
      creatorName: creatorName,
      createdAt: DateTime.now(),
    );

    _mockMeetings.add(newMeeting);

    if (SupabaseConfig.isInitialized) {
      try {
        await _sb.from('meetings').insert(newMeeting.toJson());
      } catch (e) {
        debugPrint('[MeetingsRepository] Remote scheduled meeting error: $e');
      }
    }

    return newMeeting;
  }

  @override
  Future<void> launchMeetingUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('[MeetingsRepository] Error launching URL: $e');
    }
  }
}
