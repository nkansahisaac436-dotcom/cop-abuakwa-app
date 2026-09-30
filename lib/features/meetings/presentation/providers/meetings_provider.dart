import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cop_abuakwa_app/features/auth/domain/models/profile_model.dart';
import 'package:cop_abuakwa_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:cop_abuakwa_app/features/meetings/data/meetings_repository.dart';
import 'package:cop_abuakwa_app/features/meetings/domain/models/meeting_model.dart';

final meetingsRepositoryProvider = Provider<MeetingsRepository>((ref) {
  return SupabaseMeetingsRepository();
});

final meetingsListProvider = AsyncNotifierProvider<MeetingsNotifier, List<MeetingModel>>(() {
  return MeetingsNotifier();
});

class MeetingsNotifier extends AsyncNotifier<List<MeetingModel>> {
  @override
  Future<List<MeetingModel>> build() async {
    final repo = ref.watch(meetingsRepositoryProvider);
    final user = ref.watch(authStateProvider).value;
    return repo.getMeetings(userRole: user?.role ?? UserRole.pastor);
  }

  Future<void> startInstantMeeting(String title) async {
    final user = ref.read(authStateProvider).value;
    final repo = ref.read(meetingsRepositoryProvider);
    final created = await repo.createInstantMeeting(
      title: title,
      createdBy: user?.id ?? 'pastor-user',
      creatorName: user?.fullName ?? 'Pastor',
    );
    state = AsyncValue.data([created, ...?state.value]);
    await repo.launchMeetingUrl(created.roomLink);
  }

  Future<void> scheduleMeeting(String title, DateTime scheduledAt) async {
    final user = ref.read(authStateProvider).value;
    final repo = ref.read(meetingsRepositoryProvider);
    final scheduled = await repo.scheduleMeeting(
      title: title,
      scheduledAt: scheduledAt,
      createdBy: user?.id ?? 'pastor-user',
      creatorName: user?.fullName ?? 'Pastor',
    );
    state = AsyncValue.data([...?state.value, scheduled]);
  }
}
