import 'package:flutter_test/flutter_test.dart';
import 'package:cop_abuakwa_app/features/auth/domain/models/profile_model.dart';
import 'package:cop_abuakwa_app/features/districts/domain/models/district_model.dart';
import 'package:cop_abuakwa_app/features/projects/domain/models/project_model.dart';
import 'package:cop_abuakwa_app/features/transfer/domain/models/tenure_archive_model.dart';

void main() {
  group('UserProfile Model', () {
    test('Correctly maps roles and helper getters', () {
      final profile = UserProfile(
        id: 'user-1',
        fullName: 'Apostle Area Head',
        email: 'areahead@copabuakwa.org',
        role: UserRole.areaHead,
        status: ProfileStatus.active,
        createdAt: DateTime.now(),
      );

      expect(profile.isAreaHead, true);
      expect(profile.isPastor, false);
      expect(profile.isMember, false);
      expect(profile.role.value, 'area_head');
    });
  });

  group('District Model', () {
    test('Status active/inactive getters work correctly', () {
      final district = DistrictModel(
        id: 'dist-1',
        name: 'Abuakwa Central',
        status: DistrictStatus.inactive,
        createdAt: DateTime.now(),
      );

      expect(district.isInactive, true);
      expect(district.isActive, false);

      final activated = district.copyWith(status: DistrictStatus.active);
      expect(activated.isActive, true);
    });
  });

  group('Project Model & Visibility', () {
    test('Visibility levels correspond to specifications', () {
      expect(VisibilityLevel.public.value, 'public');
      expect(VisibilityLevel.members.value, 'members');
      expect(VisibilityLevel.pastors.value, 'pastors');
      expect(VisibilityLevel.areaHead.value, 'area_head');

      final project = ProjectModel(
        id: 'p-1',
        districtId: 'dist-1',
        title: 'New Mission House',
        description: 'Building new pastoral residence',
        type: ProjectType.project,
        status: ProjectStatus.ongoing,
        progressPct: 65,
        visibility: VisibilityLevel.pastors,
        createdAt: DateTime.now(),
      );

      expect(project.isProject, true);
      expect(project.isEvent, false);
      expect(project.progressPct, 65);
      expect(project.visibility, VisibilityLevel.pastors);
    });
  });

  group('Transfer Request & Tenure Archive', () {
    test('Archive title format and summary mapping', () {
      final archive = TenureArchiveModel(
        id: 'arch-1',
        tenureId: 'tenure-1',
        title: 'Pastor Enoch Agyemang, 2021-2026',
        summaryJson: {
          'pastor_name': 'Enoch Agyemang',
          'district_name': 'Abuakwa Central',
          'total_projects': 5,
          'total_events': 12,
          'total_updates': 24,
          'total_thoughts': 8,
        },
        createdAt: DateTime.now(),
      );

      expect(archive.title, 'Pastor Enoch Agyemang, 2021-2026');
      expect(archive.pastorName, 'Enoch Agyemang');
      expect(archive.totalProjects, 5);
      expect(archive.totalEvents, 12);
      expect(archive.totalUpdates, 24);
      expect(archive.totalThoughts, 8);
    });
  });
}
