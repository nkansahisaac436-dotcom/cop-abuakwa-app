import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/network/supabase_client.dart';
import '../domain/models/profile_model.dart';
import '../../districts/data/districts_repository.dart';

abstract class AuthRepository {
  Future<UserProfile> signIn({required String email, required String password});
  Future<UserProfile> signUpMember({
    required String fullName,
    required String email,
    required String password,
    required String districtId,
    required String assemblyId,
  });
  Future<void> invitePastor({
    required String fullName,
    required String email,
    required String districtId,
  });
  Future<void> signOut();
  Future<UserProfile?> getCurrentProfile();
  Stream<AuthState> get authStateChanges;
}

class SupabaseAuthRepository implements AuthRepository {
  final SupabaseClient? _client;
  final DistrictsRepository _districtsRepo;

  SupabaseAuthRepository({
    SupabaseClient? client,
    DistrictsRepository? districtsRepo,
  })  : _client = client,
        _districtsRepo = districtsRepo ?? SupabaseDistrictsRepository();

  SupabaseClient get _sb => _client ?? SupabaseConfig.client;

  // Mock in-memory profiles for offline/demo testing
  static UserProfile? _currentMockUser;

  static final List<UserProfile> _mockUsers = [
    UserProfile(
      id: 'mock-area-head-id',
      fullName: 'Apostle Area Head',
      email: 'areahead@copabuakwa.org',
      role: UserRole.areaHead,
      status: ProfileStatus.active,
      createdAt: DateTime(2026, 1, 1),
    ),
    UserProfile(
      id: 'mock-pastor-id',
      fullName: 'Pastor Enoch Agyemang',
      email: 'pastor@copabuakwa.org',
      role: UserRole.pastor,
      status: ProfileStatus.active,
      districtId: 'd0000000-0000-0000-0000-000000000002', // Abuakwa North
      createdAt: DateTime(2026, 1, 1),
    ),
    UserProfile(
      id: 'mock-member-id',
      fullName: 'Kofi Mensah',
      email: 'kofi@example.com',
      role: UserRole.member,
      status: ProfileStatus.active,
      districtId: 'd0000000-0000-0000-0000-000000000002',
      assemblyId: 'a-5',
      createdAt: DateTime(2026, 1, 1),
    ),
    UserProfile(
      id: 'mock-leader-id',
      fullName: 'Sister Grace Osei',
      email: 'womenleader@copabuakwa.org',
      role: UserRole.ministryLeader,
      status: ProfileStatus.active,
      createdAt: DateTime(2026, 1, 1),
    ),
  ];

  @override
  Stream<AuthState> get authStateChanges {
    if (!SupabaseConfig.isInitialized) {
      return const Stream.empty();
    }
    return _sb.auth.onAuthStateChange;
  }

  @override
  Future<UserProfile> signIn({required String email, required String password}) async {
    final cleanEmail = email.trim().toLowerCase();

    // 1. If Supabase is offline/demo mode, verify against demo users
    if (!SupabaseConfig.isInitialized) {
      final user = _mockUsers.firstWhere(
        (u) => u.email.toLowerCase() == cleanEmail,
        orElse: () => throw Exception(AppStrings.invalidCredentialsMessage),
      );
      _currentMockUser = user;
      return user;
    }

    try {
      final res = await _sb.auth.signInWithPassword(
        email: cleanEmail,
        password: password,
      );

      final user = res.user;
      if (user == null) {
        throw Exception(AppStrings.invalidCredentialsMessage);
      }

      final profile = await _fetchProfileById(user.id);
      if (profile == null) {
        throw Exception(AppStrings.invalidCredentialsMessage);
      }
      return profile;
    } on AuthException {
      throw Exception(AppStrings.invalidCredentialsMessage);
    } catch (e) {
      if (e.toString().contains(AppStrings.invalidCredentialsMessage)) {
        rethrow;
      }
      throw Exception(AppStrings.invalidCredentialsMessage);
    }
  }

  @override
  Future<UserProfile> signUpMember({
    required String fullName,
    required String email,
    required String password,
    required String districtId,
    required String assemblyId,
  }) async {
    final cleanEmail = email.trim().toLowerCase();

    // 1. Check District Status: If Inactive, BLOCK registration immediately
    final districts = await _districtsRepo.getDistricts();
    final district = districts.firstWhere(
      (d) => d.id == districtId,
      orElse: () => throw Exception(AppStrings.districtInactiveBlockedToast),
    );

    if (district.isInactive) {
      throw Exception(AppStrings.districtInactiveBlockedToast);
    }

    // 2. Demo / Mock Mode Registration
    if (!SupabaseConfig.isInitialized) {
      final newMember = UserProfile(
        id: 'mock-user-${DateTime.now().millisecondsSinceEpoch}',
        fullName: fullName.trim(),
        email: cleanEmail,
        role: UserRole.member,
        status: ProfileStatus.active,
        districtId: districtId,
        assemblyId: assemblyId,
        createdAt: DateTime.now(),
      );
      _mockUsers.add(newMember);
      _currentMockUser = newMember;
      return newMember;
    }

    // 3. Supabase Auth Registration
    try {
      final res = await _sb.auth.signUp(
        email: cleanEmail,
        password: password,
        data: {
          'full_name': fullName.trim(),
          'role': 'member',
          'district_id': districtId,
          'assembly_id': assemblyId,
        },
      );

      final user = res.user;
      if (user == null) {
        throw Exception('Account creation failed. Please try again.');
      }

      final newProfile = UserProfile(
        id: user.id,
        fullName: fullName.trim(),
        email: cleanEmail,
        role: UserRole.member,
        status: ProfileStatus.active,
        districtId: districtId,
        assemblyId: assemblyId,
        createdAt: DateTime.now(),
      );

      await _sb.from('profiles').upsert(newProfile.toJson());
      return newProfile;
    } catch (e) {
      debugPrint('[AuthRepository] Sign up error: $e');
      rethrow;
    }
  }

  @override
  Future<void> invitePastor({
    required String fullName,
    required String email,
    required String districtId,
  }) async {
    final cleanEmail = email.trim().toLowerCase();

    if (!SupabaseConfig.isInitialized) {
      final newPastor = UserProfile(
        id: 'mock-pastor-${DateTime.now().millisecondsSinceEpoch}',
        fullName: fullName.trim(),
        email: cleanEmail,
        role: UserRole.pastor,
        status: ProfileStatus.active,
        districtId: districtId,
        createdAt: DateTime.now(),
      );
      _mockUsers.add(newPastor);
      return;
    }

    try {
      // Create user tenure in database
      final inviteRes = await _sb.from('pastor_tenures').insert({
        'district_id': districtId,
        'start_date': DateTime.now().toIso8601String().substring(0, 10),
        'status': 'active',
      }).select();

      debugPrint('[AuthRepository] Pastor tenure created: $inviteRes');
    } catch (e) {
      debugPrint('[AuthRepository] Error creating pastor invite: $e');
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    _currentMockUser = null;
    if (SupabaseConfig.isInitialized) {
      await _sb.auth.signOut();
    }
  }

  @override
  Future<UserProfile?> getCurrentProfile() async {
    if (!SupabaseConfig.isInitialized) {
      return _currentMockUser;
    }

    final user = _sb.auth.currentUser;
    if (user == null) return null;

    return _fetchProfileById(user.id);
  }

  Future<UserProfile?> _fetchProfileById(String userId) async {
    try {
      final res = await _sb.from('profiles').select().eq('id', userId).maybeSingle();
      if (res == null) return null;
      return UserProfile.fromJson(res);
    } catch (e) {
      debugPrint('[AuthRepository] Error fetching profile: $e');
      return null;
    }
  }
}
