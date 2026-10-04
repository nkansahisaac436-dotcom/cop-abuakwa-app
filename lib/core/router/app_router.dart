import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/domain/models/profile_model.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/home_shell_screen.dart';
import '../../features/auth/presentation/screens/invite_pastor_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/signup_screen.dart';
import '../../features/districts/domain/models/district_model.dart';
import '../../features/districts/presentation/providers/districts_provider.dart';
import '../../features/districts/presentation/screens/district_assemblies_screen.dart';
import '../../features/districts/presentation/screens/districts_activation_screen.dart';
import '../../features/districts/presentation/screens/register_district_screen.dart';
import '../../features/districts/presentation/screens/waiting_approval_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/projects/presentation/screens/area_head_projects_map_screen.dart';
import '../../features/supervision/presentation/screens/supervision_visits_screen.dart';
import '../../features/transfer/presentation/screens/transfer_archive_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = AuthRouterRefreshListenable(ref);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final user = ref.read(authStateProvider).value;
      final location = state.matchedLocation;
      final isAuthRoute = location == '/login' || location == '/signup';

      if (user == null) {
        return isAuthRoute ? null : '/login';
      }

      // 1. Pastor ONE unified routing rule:
      if (user.isPastor) {
        DistrictStatus? status = user.districtStatus;
        if (status == null && user.districtId != null) {
          final districts = ref.read(districtsListProvider).value;
          if (districts != null) {
            final match = districts.cast<DistrictModel?>().firstWhere(
              (d) => d?.id == user.districtId || d?.registeredBy == user.id,
              orElse: () => null,
            );
            status = match?.status;
          }
        }

        // State A: No district linked yet -> "Register your district" screen
        if (user.districtId == null && status == null) {
          if (location != '/pastor/register-district' &&
              location != '/profile' &&
              location != '/notifications') {
            return '/pastor/register-district';
          }
          return null;
        }

        // State B & C: District is pending or rejected -> "Waiting for Area Head approval" screen
        if (status == DistrictStatus.pending || status == DistrictStatus.rejected) {
          if (location != '/pastor/waiting-approval' &&
              location != '/pastor/register-district' && // allows edit/resubmit
              location != '/profile' &&
              location != '/notifications') {
            return '/pastor/waiting-approval';
          }
          return null;
        }

        // State D: District is active -> normal pastor dashboard
        if (status == DistrictStatus.active) {
          if (isAuthRoute ||
              location == '/pastor/register-district' ||
              location == '/pastor/waiting-approval') {
            return '/pastor-home';
          }
        }
      }

      // If user is authenticated and is on /login or /signup, redirect to their role home
      if (isAuthRoute) {
        switch (user.role) {
          case UserRole.areaHead:
            return '/dashboard';
          case UserRole.pastor:
            if (user.districtId == null) {
              return '/pastor/register-district';
            }
            if (user.districtStatus == DistrictStatus.active) {
              return '/pastor-home';
            }
            return '/pastor/waiting-approval';
          case UserRole.ministryLeader:
            return '/leader-home';
          case UserRole.member:
            return '/feed';
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        name: 'signup',
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        name: 'area_head_dashboard',
        builder: (context, state) => const HomeShellScreen(initialRole: UserRole.areaHead),
      ),
      GoRoute(
        path: '/pastor-home',
        name: 'pastor_home',
        builder: (context, state) => const HomeShellScreen(initialRole: UserRole.pastor),
      ),
      GoRoute(
        path: '/pastor',
        redirect: (context, state) => '/pastor-home',
      ),
      GoRoute(
        path: '/pastor/register-district',
        name: 'register_district',
        builder: (context, state) => const RegisterDistrictScreen(),
      ),
      GoRoute(
        path: '/pastor/waiting-approval',
        name: 'waiting_approval',
        builder: (context, state) => const WaitingApprovalScreen(),
      ),
      GoRoute(
        path: '/pastor/assemblies',
        name: 'pastor_assemblies',
        builder: (context, state) => const DistrictAssembliesScreen(),
      ),
      GoRoute(
        path: '/leader-home',
        name: 'leader_home',
        builder: (context, state) => const HomeShellScreen(initialRole: UserRole.ministryLeader),
      ),
      GoRoute(
        path: '/feed',
        name: 'member_feed',
        builder: (context, state) => const HomeShellScreen(initialRole: UserRole.member),
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/invites',
        name: 'invites',
        builder: (context, state) => const InvitePastorScreen(),
      ),
      GoRoute(
        path: '/projects-map',
        name: 'projects_map',
        builder: (context, state) => const AreaHeadProjectsMapScreen(),
      ),
      GoRoute(
        path: '/districts-activation',
        name: 'districts_activation',
        builder: (context, state) => const DistrictsActivationScreen(),
      ),
      GoRoute(
        path: '/supervision',
        name: 'supervision',
        builder: (context, state) => const SupervisionVisitsScreen(),
      ),
      GoRoute(
        path: '/transfer-archive',
        name: 'transfer_archive',
        builder: (context, state) => const TransferArchiveScreen(),
      ),
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
    ],
  );
});

class AuthRouterRefreshListenable extends ChangeNotifier {
  AuthRouterRefreshListenable(Ref ref) {
    ref.listen<AsyncValue<UserProfile?>>(
      authStateProvider,
      (previous, next) => notifyListeners(),
    );
    ref.listen<AsyncValue<List<DistrictModel>>>(
      districtsListProvider,
      (previous, next) => notifyListeners(),
    );
  }
}
