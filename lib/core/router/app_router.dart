import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/domain/models/profile_model.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/home_shell_screen.dart';
import '../../features/auth/presentation/screens/invite_pastor_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/signup_screen.dart';
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

      // If user is authenticated and is on /login or /signup, redirect to their role home
      if (isAuthRoute) {
        switch (user.role) {
          case UserRole.areaHead:
            return '/dashboard';
          case UserRole.pastor:
            if (user.districtId == null) {
              return '/pastor/register-district';
            }
            return '/pastor-home';
          case UserRole.ministryLeader:
            return '/leader-home';
          case UserRole.member:
            return '/feed';
        }
      }

      // If pastor has no district registered yet, keep them on register-district screen
      if (user.isPastor && user.districtId == null) {
        if (location != '/pastor/register-district' &&
            location != '/profile' &&
            location != '/notifications') {
          return '/pastor/register-district';
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
  }
}
