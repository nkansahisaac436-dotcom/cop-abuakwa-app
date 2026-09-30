import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/auth_repository.dart';
import '../../domain/models/profile_model.dart';
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

  Future<void> signIn({required String email, required String password}) async {
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(authRepositoryProvider);
      final profile = await repo.signIn(email: email, password: password);
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

  Future<void> invitePastor({
    required String fullName,
    required String email,
    required String districtId,
  }) async {
    final repo = ref.read(authRepositoryProvider);
    await repo.invitePastor(
      fullName: fullName,
      email: email,
      districtId: districtId,
    );
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
