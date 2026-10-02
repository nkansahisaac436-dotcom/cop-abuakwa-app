import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../auth/domain/models/profile_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../districts/presentation/screens/districts_activation_screen.dart';
import '../../../feeds/presentation/screens/public_feed_screen.dart';
import '../../../feeds/presentation/screens/pastor_thoughts_screen.dart';
import '../../../ministries/presentation/screens/ministries_list_screen.dart';
import '../../../projects/presentation/screens/projects_list_screen.dart';
import '../../../projects/presentation/screens/area_head_projects_map_screen.dart';
import '../../../supervision/presentation/screens/supervision_visits_screen.dart';
import '../../../transfer/presentation/screens/transfer_archive_screen.dart';
import '../../../meetings/presentation/screens/meetings_screen.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import 'invite_pastor_screen.dart';

class HomeShellScreen extends ConsumerStatefulWidget {
  final UserRole? initialRole;

  const HomeShellScreen({super.key, this.initialRole});

  @override
  ConsumerState<HomeShellScreen> createState() => _HomeShellScreenState();
}

class _HomeShellScreenState extends ConsumerState<HomeShellScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final userProfile = ref.watch(authStateProvider).value;

    if (userProfile == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isAreaHead = userProfile.isAreaHead;
    final isPastor = userProfile.isPastor;
    final isMinistryLeader = userProfile.isMinistryLeader;

    // Configure tabs dynamically based on user role
    final List<Widget> screens;
    final List<BottomNavigationBarItem> navItems;

    if (isAreaHead) {
      screens = [
        const AreaHeadDashboardTab(),
        const AreaHeadProjectsMapScreen(),
        const DistrictsActivationScreen(),
        const TransferArchiveScreen(),
        const ProfileScreen(),
      ];
      navItems = const [
        BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'Dashboard'),
        BottomNavigationBarItem(icon: Icon(Icons.map_outlined), activeIcon: Icon(Icons.map), label: 'All Projects'),
        BottomNavigationBarItem(icon: Icon(Icons.apartment_outlined), activeIcon: Icon(Icons.apartment), label: 'Districts'),
        BottomNavigationBarItem(icon: Icon(Icons.archive_outlined), activeIcon: Icon(Icons.archive), label: 'Archives'),
        BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
      ];
    } else if (isPastor) {
      screens = [
        const PublicFeedScreen(),
        const ProjectsListScreen(),
        const PastorThoughtsScreen(),
        const MeetingsScreen(),
        const ProfileScreen(),
      ];
      navItems = const [
        BottomNavigationBarItem(icon: Icon(Icons.feed_outlined), activeIcon: Icon(Icons.feed), label: 'Feed'),
        BottomNavigationBarItem(icon: Icon(Icons.assignment_outlined), activeIcon: Icon(Icons.assignment), label: 'My District'),
        BottomNavigationBarItem(icon: Icon(Icons.psychology_outlined), activeIcon: Icon(Icons.psychology), label: 'Thoughts'),
        BottomNavigationBarItem(icon: Icon(Icons.video_call_outlined), activeIcon: Icon(Icons.video_call), label: 'Meetings'),
        BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
      ];
    } else if (isMinistryLeader) {
      screens = [
        const PublicFeedScreen(),
        const MinistriesListScreen(),
        const ProfileScreen(),
      ];
      navItems = const [
        BottomNavigationBarItem(icon: Icon(Icons.feed_outlined), activeIcon: Icon(Icons.feed), label: 'Area Feed'),
        BottomNavigationBarItem(icon: Icon(Icons.groups_outlined), activeIcon: Icon(Icons.groups), label: 'Ministries'),
        BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
      ];
    } else {
      // General Member
      screens = [
        const PublicFeedScreen(),
        const MinistriesListScreen(),
        const ProjectsListScreen(onlyPublic: true),
        const ProfileScreen(),
      ];
      navItems = const [
        BottomNavigationBarItem(icon: Icon(Icons.feed_outlined), activeIcon: Icon(Icons.feed), label: 'Feed'),
        BottomNavigationBarItem(icon: Icon(Icons.groups_outlined), activeIcon: Icon(Icons.groups), label: 'Ministries'),
        BottomNavigationBarItem(icon: Icon(Icons.explore_outlined), activeIcon: Icon(Icons.explore), label: 'Projects'),
        BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
      ];
    }

    final safeIndex = _currentIndex >= screens.length ? 0 : _currentIndex;

    return Scaffold(
      body: IndexedStack(
        index: safeIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: safeIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.white,
          selectedItemColor: AppColors.navy,
          unselectedItemColor: AppColors.softGrey,
          selectedLabelStyle: GoogleFonts.nunitoSans(fontWeight: FontWeight.bold, fontSize: 11),
          unselectedLabelStyle: GoogleFonts.nunitoSans(fontSize: 11),
          items: navItems,
        ),
      ),
    );
  }
}

/// Area Head Dashboard Tab
class AreaHeadDashboardTab extends ConsumerWidget {
  const AreaHeadDashboardTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Area Head Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_outlined),
            tooltip: 'Invite Pastor',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const InvitePastorScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: AppColors.navyGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.gold,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'AREA HEAD OFFICE',
                          style: GoogleFonts.nunitoSans(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.navyDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Abuakwa Area Oversight',
                    style: GoogleFonts.sourceSerif4(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Welcome, ${user?.fullName ?? "Apostle"}. Supervising ~33 Districts.',
                    style: GoogleFonts.nunitoSans(
                      fontSize: 13,
                      color: AppColors.lightGold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Quick Actions
            Text(
              'Supervisory Actions',
              style: GoogleFonts.sourceSerif4(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildActionTile(
                    context: context,
                    icon: Icons.add_location_alt_outlined,
                    title: 'Log Supervision\nVisit',
                    color: AppColors.navy,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SupervisionVisitsScreen()),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionTile(
                    context: context,
                    icon: Icons.person_add_outlined,
                    title: 'Invite District\nPastor',
                    color: AppColors.gold,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const InvitePastorScreen()),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildActionTile(
                    context: context,
                    icon: Icons.campaign_outlined,
                    title: 'Post Area\nAnnouncement',
                    color: const Color(0xFF0D9488),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const PublicFeedScreen()),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionTile(
                    context: context,
                    icon: Icons.archive_outlined,
                    title: 'Tenure Archives\n& Transfer Decisions',
                    color: const Color(0xFF6366F1),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const TransferArchiveScreen()),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Recent Supervision Log Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Supervision Visits',
                    style: GoogleFonts.sourceSerif4(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.navy,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SupervisionVisitsScreen()),
                    );
                  },
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle_outline, color: AppColors.success, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Recent Visit: Tanoso Central Assembly',
                          style: GoogleFonts.nunitoSans(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Inspected ongoing youth chapel renovation. Construction progressing at 70%. Good pastoral leadership.',
                    style: GoogleFonts.nunitoSans(fontSize: 13, color: AppColors.softGrey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.nunitoSans(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
