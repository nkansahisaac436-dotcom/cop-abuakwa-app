import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/network/supabase_client.dart';
import '../domain/models/profile_model.dart';
import '../domain/models/invite_model.dart';
import '../../districts/data/districts_repository.dart';

abstract class AuthRepository {
  Future<UserProfile> signIn({
    required String email,
    required String password,
    required UserRole selectedRole,
  });

  Future<UserProfile> signUpMember({
    required String fullName,
    required String email,
    required String password,
    required String districtId,
    required String assemblyId,
  });

  Future<InviteModel> verifyInviteCode(String code);

  Future<UserProfile> redeemInvite({
    required String code,
    required String email,
    required String password,
    required String fullName,
  });

  Future<InviteModel> createInvite({
    required UserRole role,
    required String targetName,
    String? districtId,
    String? districtName,
    String? ministryId,
    String? ministryName,
  });

  Future<List<InviteModel>> getInvites();

  Future<void> cancelInvite(String inviteId);

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

  // Rate limiting tracker for invite code attempts (5 wrong tries -> 15 min lock)
  static int _failedInviteAttempts = 0;
  static DateTime? _inviteLockoutUntil;

  // Mock in-memory profiles for offline testing
  static UserProfile? _currentMockUser;

  static void resetMockState() {
    _currentMockUser = null;
    _failedInviteAttempts = 0;
    _inviteLockoutUntil = null;
  }

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

  // In-memory invites store
  static final List<InviteModel> _mockInvites = [
    InviteModel(
      id: 'inv-1',
      code: 'ABK-7K4P-2M',
      role: UserRole.pastor,
      targetName: 'Pastor Kwabena Darko',
      districtId: 'd0000000-0000-0000-0000-000000000001',
      districtName: 'Abuakwa Central District',
      status: 'pending',
      createdAt: DateTime.now().subtract(const Duration(hours: 4)),
      expiresAt: DateTime.now().add(const Duration(days: 7)),
    ),
    InviteModel(
      id: 'inv-2',
      code: 'ABK-3Y9W-8T',
      role: UserRole.ministryLeader,
      targetName: 'Brother Emmanuel Addo',
      ministryId: 'm-youth',
      ministryName: 'Youth Ministry',
      status: 'pending',
      createdAt: DateTime.now().subtract(const Duration(hours: 12)),
      expiresAt: DateTime.now().add(const Duration(days: 7)),
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
  Future<UserProfile> signIn({
    required String email,
    required String password,
    required UserRole selectedRole,
  }) async {
    final cleanEmail = email.trim().toLowerCase();

    // 1. If Supabase is offline/demo mode, verify against demo users
    if (!SupabaseConfig.isInitialized) {
      if (cleanEmail == 'noprofile@copabuakwa.org') {
        throw Exception('Your account is not set up yet. Please contact the Area Head office.');
      }

      if (password == 'wrongpassword' || password == 'wrong_password' || password.isEmpty) {
        throw Exception(AppStrings.invalidCredentialsMessage);
      }

      final user = _mockUsers.firstWhere(
        (u) => u.email.toLowerCase() == cleanEmail,
        orElse: () => throw Exception(AppStrings.invalidCredentialsMessage),
      );

      // Verify selected role matches real role
      _validateRoleMatch(user.role, selectedRole);

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
        await _sb.auth.signOut();
        throw Exception('Your account is not set up yet. Please contact the Area Head office.');
      }

      // Verify selected role matches real role
      try {
        _validateRoleMatch(profile.role, selectedRole);
      } catch (roleError) {
        // Sign user out of this attempt
        await _sb.auth.signOut();
        rethrow;
      }

      return profile;
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('invalid login credentials') || msg.contains('invalid_grant')) {
        throw Exception(AppStrings.invalidCredentialsMessage);
      }
      if (msg.contains('email not confirmed')) {
        throw Exception('Email not confirmed. Please check your email or contact the Area Head office.');
      }
      throw Exception(e.message);
    } catch (e) {
      final errStr = e.toString().replaceAll('Exception: ', '');
      if (errStr.contains('This account is not') ||
          errStr.contains('Your account is not set up') ||
          errStr.contains(AppStrings.invalidCredentialsMessage)) {
        rethrow;
      }
      throw Exception(errStr.isNotEmpty ? errStr : AppStrings.invalidCredentialsMessage);
    }
  }

  void _validateRoleMatch(UserRole actualRole, UserRole selectedRole) {
    if (actualRole != selectedRole) {
      switch (selectedRole) {
        case UserRole.areaHead:
          throw Exception('This account is not an area head account. Choose the correct option above.');
        case UserRole.pastor:
          throw Exception('This account is not a pastor account. Choose the correct option above.');
        case UserRole.ministryLeader:
          throw Exception('This account is not a ministry leader account. Choose the correct option above.');
        case UserRole.member:
          throw Exception('This account is not a member account. Choose the correct option above.');
      }
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
  Future<InviteModel> verifyInviteCode(String code) async {
    final cleanCode = code.trim().toUpperCase();

    // 1. Check Rate Limiting (15-min lockout after 5 failed tries)
    if (_inviteLockoutUntil != null && _inviteLockoutUntil!.isAfter(DateTime.now())) {
      throw Exception('Too many tries. Please wait 15 minutes and try again.');
    }

    // 2. Mock / Offline Mode Verification
    if (!SupabaseConfig.isInitialized) {
      final match = _mockInvites.cast<InviteModel?>().firstWhere(
        (inv) => inv?.code.toUpperCase() == cleanCode && inv?.isPending == true,
        orElse: () => null,
      );

      if (match == null) {
        _recordFailedInviteAttempt();
        if (_failedInviteAttempts >= 5) {
          throw Exception('Too many tries. Please wait 15 minutes and try again.');
        }
        throw Exception('This code is not valid. Ask your Area Head for a new one.');
      }

      // Reset failed attempts on success
      _failedInviteAttempts = 0;
      _inviteLockoutUntil = null;
      return match;
    }

    // 3. Supabase RPC verify_invite_code
    try {
      final res = await _sb.rpc('verify_invite_code', params: {'p_code': cleanCode});
      if (res != null && res['valid'] == true) {
        _failedInviteAttempts = 0;
        _inviteLockoutUntil = null;
        return InviteModel.fromJson(Map<String, dynamic>.from(res));
      }
      _recordFailedInviteAttempt();
      if (_failedInviteAttempts >= 5) {
        throw Exception('Too many tries. Please wait 15 minutes and try again.');
      }
      throw Exception('This code is not valid. Ask your Area Head for a new one.');
    } catch (e) {
      _recordFailedInviteAttempt();
      final errStr = e.toString();
      if (errStr.contains('Too many') || _failedInviteAttempts >= 5) {
        throw Exception('Too many tries. Please wait 15 minutes and try again.');
      }
      throw Exception('This code is not valid. Ask your Area Head for a new one.');
    }
  }

  void _recordFailedInviteAttempt() {
    _failedInviteAttempts++;
    if (_failedInviteAttempts >= 5) {
      _inviteLockoutUntil = DateTime.now().add(const Duration(minutes: 15));
    }
  }

  @override
  Future<UserProfile> redeemInvite({
    required String code,
    required String email,
    required String password,
    required String fullName,
  }) async {
    final verified = await verifyInviteCode(code);
    final cleanEmail = email.trim().toLowerCase();

    // 1. Mock / Offline Mode Redemption
    if (!SupabaseConfig.isInitialized) {
      // Mark invite redeemed
      final index = _mockInvites.indexWhere((inv) => inv.id == verified.id);
      if (index != -1) {
        final current = _mockInvites[index];
        _mockInvites[index] = InviteModel(
          id: current.id,
          code: current.code,
          role: current.role,
          targetName: current.targetName,
          districtId: current.districtId,
          districtName: current.districtName,
          ministryId: current.ministryId,
          ministryName: current.ministryName,
          status: 'redeemed',
          createdAt: current.createdAt,
          expiresAt: current.expiresAt,
          redeemedBy: 'mock-user-${DateTime.now().millisecondsSinceEpoch}',
          redeemedAt: DateTime.now(),
        );
      }

      final newProfile = UserProfile(
        id: 'mock-user-${DateTime.now().millisecondsSinceEpoch}',
        fullName: fullName.isNotEmpty ? fullName.trim() : verified.targetName,
        email: cleanEmail,
        role: verified.role,
        status: ProfileStatus.active,
        districtId: verified.districtId,
        createdAt: DateTime.now(),
      );

      _mockUsers.add(newProfile);
      _currentMockUser = newProfile;
      return newProfile;
    }

    // 2. Supabase Auth Sign Up & RPC Redemption
    try {
      final res = await _sb.auth.signUp(
        email: cleanEmail,
        password: password,
        data: {
          'full_name': fullName.isNotEmpty ? fullName.trim() : verified.targetName,
          'role': verified.role.name,
          'district_id': verified.districtId,
        },
      );

      final user = res.user;
      if (user == null) {
        throw Exception('Account activation failed. Please try again.');
      }

      // Call redeem_invite RPC
      await _sb.rpc('redeem_invite', params: {
        'p_code': verified.code,
        'p_user_id': user.id,
        'p_email': cleanEmail,
        'p_full_name': fullName.isNotEmpty ? fullName.trim() : verified.targetName,
      });

      final profile = await _fetchProfileById(user.id);
      return profile ??
          UserProfile(
            id: user.id,
            fullName: fullName.isNotEmpty ? fullName.trim() : verified.targetName,
            email: cleanEmail,
            role: verified.role,
            status: ProfileStatus.active,
            districtId: verified.districtId,
            createdAt: DateTime.now(),
          );
    } catch (e) {
      debugPrint('[AuthRepository] Redeem invite error: $e');
      rethrow;
    }
  }

  @override
  Future<InviteModel> createInvite({
    required UserRole role,
    required String targetName,
    String? districtId,
    String? districtName,
    String? ministryId,
    String? ministryName,
  }) async {
    final generatedCode = _generateRandomInviteCode();
    final newInvite = InviteModel(
      id: 'inv-${DateTime.now().millisecondsSinceEpoch}',
      code: generatedCode,
      role: role,
      targetName: targetName.trim(),
      districtId: districtId,
      districtName: districtName,
      ministryId: ministryId,
      ministryName: ministryName,
      status: 'pending',
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(days: 7)),
    );

    if (!SupabaseConfig.isInitialized) {
      _mockInvites.insert(0, newInvite);
      return newInvite;
    }

    try {
      final res = await _sb.from('invites').insert({
        'code_hash': generatedCode,
        'code_display': generatedCode,
        'role': role.name,
        'target_name': targetName.trim(),
        'district_id': districtId,
        'ministry_id': ministryId,
        'status': 'pending',
        'created_by': _sb.auth.currentUser?.id,
        'expires_at': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
      }).select().single();

      return InviteModel.fromJson(res);
    } catch (e) {
      debugPrint('[AuthRepository] Error creating invite: $e');
      rethrow;
    }
  }

  @override
  Future<List<InviteModel>> getInvites() async {
    if (!SupabaseConfig.isInitialized) {
      return List.unmodifiable(_mockInvites);
    }

    try {
      final res = await _sb
          .from('invites')
          .select('*, districts(name), ministries(name)')
          .order('created_at', ascending: false);

      return (res as List).map((row) {
        final dName = row['districts'] != null ? row['districts']['name'] as String? : null;
        final mName = row['ministries'] != null ? row['ministries']['name'] as String? : null;
        final map = Map<String, dynamic>.from(row);
        if (dName != null) map['district_name'] = dName;
        if (mName != null) map['ministry_name'] = mName;
        return InviteModel.fromJson(map);
      }).toList();
    } catch (e) {
      debugPrint('[AuthRepository] Error getting invites: $e');
      return [];
    }
  }

  @override
  Future<void> cancelInvite(String inviteId) async {
    if (!SupabaseConfig.isInitialized) {
      final idx = _mockInvites.indexWhere((inv) => inv.id == inviteId);
      if (idx != -1) {
        final current = _mockInvites[idx];
        _mockInvites[idx] = InviteModel(
          id: current.id,
          code: current.code,
          role: current.role,
          targetName: current.targetName,
          districtId: current.districtId,
          districtName: current.districtName,
          ministryId: current.ministryId,
          ministryName: current.ministryName,
          status: 'cancelled',
          createdAt: current.createdAt,
          expiresAt: current.expiresAt,
        );
      }
      return;
    }

    try {
      await _sb.from('invites').update({'status': 'cancelled'}).eq('id', inviteId);
    } catch (e) {
      debugPrint('[AuthRepository] Error cancelling invite: $e');
      rethrow;
    }
  }

  static String _generateRandomInviteCode() {
    const chars = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ'; // Excludes 0, 1, I, O to avoid confusion
    final rnd = Random.secure();
    final p1 = List.generate(4, (_) => chars[rnd.nextInt(chars.length)]).join();
    final p2 = List.generate(2, (_) => chars[rnd.nextInt(chars.length)]).join();
    return 'ABK-$p1-$p2';
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
