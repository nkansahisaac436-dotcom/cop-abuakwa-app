import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/auth_repository.dart';
import '../../domain/models/profile_model.dart';
import '../../domain/models/invite_model.dart';
import '../../../districts/presentation/providers/districts_provider.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final districtsRepo = ref.watch(districtsRepositoryProvider);
  return SupabaseAuthRepository(districtsRepo: districtsRepo);
});

final authStateProvider = AsyncNotifierProvider<AuthNotifier, UserProfile?>(() {
  return AuthNotifier();
});

class AuthNotifier extends AsyncNotifier<UserProfile?> {
  @override
  Future<UserProfile?> build() async {
    final repo = ref.watch(authRepositoryProvider);
    return repo.getCurrentProfile();
  }

  Future<void> signIn({
    required String email,
    required String password,
    required UserRole selectedRole,
  }) async {
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(authRepositoryProvider);
      final profile = await repo.signIn(
        email: email,
        password: password,
        selectedRole: selectedRole,
      );
      state = AsyncValue.data(profile);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> signUpMember({
    required String fullName,
    required String email,
    required String password,
    required String districtId,
    required String assemblyId,
  }) async {
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(authRepositoryProvider);
      final profile = await repo.signUpMember(
        fullName: fullName,
        email: email,
        password: password,
        districtId: districtId,
        assemblyId: assemblyId,
      );
      state = AsyncValue.data(profile);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> redeemInvite({
    required String code,
    required String email,
    required String password,
    required String fullName,
  }) async {
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(authRepositoryProvider);
      final profile = await repo.redeemInvite(
        code: code,
        email: email,
        password: password,
        fullName: fullName,
      );
      state = AsyncValue.data(profile);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    final repo = ref.read(authRepositoryProvider);
    await repo.signOut();
    state = const AsyncValue.data(null);
  }

  void setMockProfile(UserProfile profile) {
    state = AsyncValue.data(profile);
  }
}

final invitesListProvider = AsyncNotifierProvider<InvitesNotifier, List<InviteModel>>(() {
  return InvitesNotifier();
});

class InvitesNotifier extends AsyncNotifier<List<InviteModel>> {
  @override
  Future<List<InviteModel>> build() async {
    final repo = ref.watch(authRepositoryProvider);
    return repo.getInvites();
  }

  Future<InviteModel> createInvite({
    required UserRole role,
    required String targetName,
    String? districtId,
    String? districtName,
    String? ministryId,
    String? ministryName,
  }) async {
    final repo = ref.read(authRepositoryProvider);
    final invite = await repo.createInvite(
      role: role,
      targetName: targetName,
      districtId: districtId,
      districtName: districtName,
      ministryId: ministryId,
      ministryName: ministryName,
    );
    ref.invalidateSelf();
    return invite;
  }

  Future<void> cancelInvite(String inviteId) async {
    final repo = ref.read(authRepositoryProvider);
    await repo.cancelInvite(inviteId);
    ref.invalidateSelf();
  }
}
