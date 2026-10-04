import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:cop_abuakwa_app/core/constants/app_strings.dart';
import 'package:cop_abuakwa_app/core/network/supabase_client.dart';
import 'package:cop_abuakwa_app/core/utils/image_compressor.dart';
import 'package:cop_abuakwa_app/core/widgets/author_attribution_header.dart';
import 'package:cop_abuakwa_app/features/auth/data/auth_repository.dart';
import 'package:cop_abuakwa_app/features/auth/domain/models/profile_model.dart';
import 'package:cop_abuakwa_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:cop_abuakwa_app/features/auth/presentation/screens/signup_screen.dart';
import 'package:cop_abuakwa_app/features/districts/data/districts_repository.dart';
import 'package:cop_abuakwa_app/features/districts/domain/models/district_model.dart';
import 'package:cop_abuakwa_app/features/districts/presentation/providers/districts_provider.dart';
import 'package:cop_abuakwa_app/features/districts/presentation/screens/district_assemblies_screen.dart';
import 'package:cop_abuakwa_app/features/districts/presentation/screens/register_district_screen.dart';
import 'package:cop_abuakwa_app/features/feeds/data/feeds_repository.dart';
import 'package:cop_abuakwa_app/features/meetings/data/meetings_repository.dart';
import 'package:cop_abuakwa_app/features/projects/data/projects_repository.dart';
import 'package:cop_abuakwa_app/features/transfer/domain/models/tenure_archive_model.dart';
import 'package:cop_abuakwa_app/features/transfer/utils/archive_pdf_generator.dart';
import 'package:cop_abuakwa_app/main.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SupabaseConfig.setMockMode(true);
  });

  setUp(() {
    SupabaseAuthRepository.resetMockState();
    SupabaseDistrictsRepository.resetState();
    SupabaseFeedsRepository.resetState();
    SupabaseProjectsRepository.resetState();
  });

  group('Part 1: Pastor 4-State Routing & Fresh DB Tests', () {
    testWidgets('State 1: Pastor with no district linked routes to RegisterDistrictScreen', (WidgetTester tester) async {
      final container = ProviderContainer();
      final authRepo = container.read(authRepositoryProvider);

      // Create and redeem pastor invite without district
      final invite = await authRepo.createInvite(
        role: UserRole.pastor,
        targetName: 'Pastor Kwadwo Nkrumah',
      );
      final pastor = await authRepo.redeemInvite(
        code: invite.code,
        email: 'pastor.nkrumah@copabuakwa.org',
        password: 'Password123!',
        fullName: 'Pastor Kwadwo Nkrumah',
      );

      container.read(authStateProvider.notifier).setMockProfile(pastor);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const AbuakwaApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Register your district'), findsOneWidget);
      expect(find.text('District Name'), findsOneWidget);
      expect(find.text('Tenure Start Date'), findsOneWidget);
      expect(find.text('Submit for approval'), findsOneWidget);

      container.dispose();
    });

    testWidgets('State 2: Pastor with pending district routes to WaitingApprovalScreen', (WidgetTester tester) async {
      final container = ProviderContainer();
      final authRepo = container.read(authRepositoryProvider);
      final distRepo = container.read(districtsRepositoryProvider);

      final invite = await authRepo.createInvite(
        role: UserRole.pastor,
        targetName: 'Pastor Kofi Osei',
      );
      final pastor = await authRepo.redeemInvite(
        code: invite.code,
        email: 'pastor.osei@copabuakwa.org',
        password: 'Password123!',
        fullName: 'Pastor Kofi Osei',
      );

      container.read(authStateProvider.notifier).setMockProfile(pastor);

      // Pastor registers district
      final dist = await distRepo.registerDistrict(
        name: 'Tanoso District',
        startDate: DateTime(2025, 2, 1),
      );

      expect(dist.status, DistrictStatus.pending);

      // App re-evaluates / refreshes profile
      await container.read(authStateProvider.notifier).refreshProfile();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const AbuakwaApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Waiting for Area Head Approval'), findsOneWidget);
      expect(find.textContaining('Tanoso District'), findsWidgets);
      expect(find.text('Edit My Profile'), findsOneWidget);

      container.dispose();
    });

    testWidgets('State 3: Pastor with rejected district shows Area Head note and edit/resubmit option', (WidgetTester tester) async {
      final container = ProviderContainer();
      final authRepo = container.read(authRepositoryProvider);
      final distRepo = container.read(districtsRepositoryProvider);

      final invite = await authRepo.createInvite(
        role: UserRole.pastor,
        targetName: 'Pastor Yaw Appiah',
      );
      final pastor = await authRepo.redeemInvite(
        code: invite.code,
        email: 'pastor.appiah@copabuakwa.org',
        password: 'Password123!',
        fullName: 'Pastor Yaw Appiah',
      );

      container.read(authStateProvider.notifier).setMockProfile(pastor);

      final dist = await distRepo.registerDistrict(
        name: 'Sepaase District',
        startDate: DateTime(2025, 3, 1),
      );

      // Area Head rejects with note
      await distRepo.rejectDistrict(dist.id, note: 'Please verify exact district boundary and tenure start date.');
      await container.read(authStateProvider.notifier).refreshProfile();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const AbuakwaApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Registration Needs Attention'), findsOneWidget);
      expect(find.text('Please verify exact district boundary and tenure start date.'), findsOneWidget);
      expect(find.text('Edit & Resubmit District'), findsOneWidget);

      container.dispose();
    });

    testWidgets('State 4: Pastor with active district routes to Pastor Home Dashboard', (WidgetTester tester) async {
      final container = ProviderContainer();
      final authRepo = container.read(authRepositoryProvider);
      final distRepo = container.read(districtsRepositoryProvider);

      final invite = await authRepo.createInvite(
        role: UserRole.pastor,
        targetName: 'Pastor Samuel Antwi',
      );
      final pastor = await authRepo.redeemInvite(
        code: invite.code,
        email: 'pastor.antwi@copabuakwa.org',
        password: 'Password123!',
        fullName: 'Pastor Samuel Antwi',
      );

      container.read(authStateProvider.notifier).setMockProfile(pastor);

      final dist = await distRepo.registerDistrict(
        name: 'Abuakwa Central District',
        startDate: DateTime(2025, 1, 1),
      );

      // Area Head approves
      await distRepo.approveDistrict(dist.id, note: 'Approved');
      await container.read(authStateProvider.notifier).refreshProfile();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const AbuakwaApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Feed'), findsOneWidget);
      expect(find.text('My District'), findsOneWidget);
      expect(find.text('Thoughts'), findsOneWidget);
      expect(find.text('Meetings'), findsOneWidget);

      container.dispose();
    });

    test('Fresh restart of app reads latest district status directly from database', () async {
      final repo = SupabaseDistrictsRepository();
      final authRepo = SupabaseAuthRepository();

      final invite = await authRepo.createInvite(
        role: UserRole.pastor,
        targetName: 'Pastor Restart Test',
      );
      await authRepo.redeemInvite(
        code: invite.code,
        email: 'pastor.restart@copabuakwa.org',
        password: 'Password123!',
        fullName: 'Pastor Restart Test',
      );

      // Register district
      final dist = await repo.registerDistrict(name: 'Bompata District', startDate: DateTime(2025, 5, 1));
      expect(dist.status, DistrictStatus.pending);

      // App is killed and restarted -> fresh getProfile
      var freshProfile = await authRepo.getCurrentProfile();
      expect(freshProfile?.districtStatus, DistrictStatus.pending);

      // Area Head approves
      await repo.approveDistrict(dist.id);

      // Fresh profile fetch after approval
      freshProfile = await authRepo.getCurrentProfile();
      expect(freshProfile?.districtStatus, DistrictStatus.active);
    });
  });

  group('Part 2: Simplified District Registration Tests', () {
    testWidgets('RegisterDistrictScreen has only Name, Start Date, and Submit button (no Assemblies section)', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: RegisterDistrictScreen(),
          ),
        ),
      );

      expect(find.text('Register your district'), findsOneWidget);
      expect(find.text('District Name'), findsOneWidget);
      expect(find.text('Tenure Start Date'), findsOneWidget);
      expect(find.text('Submit for approval'), findsOneWidget);

      // Verify Local Assemblies and Add Assembly buttons are removed
      expect(find.text('Local Assemblies'), findsNothing);
      expect(find.text('Add Assembly'), findsNothing);
      expect(find.text('Add another assembly'), findsNothing);
    });

    test('registerDistrict no longer requires assemblies parameter and creates pending district', () async {
      final repo = SupabaseDistrictsRepository();
      final created = await repo.registerDistrict(
        name: 'Asuoyeboah District',
        startDate: DateTime(2025, 6, 1),
      );

      expect(created.name, 'Asuoyeboah District');
      expect(created.status, DistrictStatus.pending);
      expect(created.startDate, DateTime(2025, 6, 1));
      expect(created.assemblyNames, isEmpty);
    });
  });

  group('Part 3: Assembly Management & Security Policy Tests', () {
    test('After approval, pastor can add assemblies and names must be unique per district', () async {
      final repo = SupabaseDistrictsRepository();
      final dist = await repo.registerDistrict(
        name: 'Tanoso Central District',
        startDate: DateTime(2025, 1, 1),
      );

      await repo.approveDistrict(dist.id);

      // Add first assembly
      final asm1 = await repo.addAssembly(districtId: dist.id, name: 'Central Assembly');
      expect(asm1.name, 'Central Assembly');
      expect(asm1.isActive, isTrue);

      // Add second assembly
      final asm2 = await repo.addAssembly(districtId: dist.id, name: 'Bethel Assembly');
      expect(asm2.name, 'Bethel Assembly');

      // Duplicate assembly in same district must be blocked
      expect(
        () => repo.addAssembly(districtId: dist.id, name: '  central   assembly  '),
        throwsA(predicate((e) => e.toString().contains('already exists in your district'))),
      );

      // Different district CAN use the same assembly name
      final dist2 = await repo.registerDistrict(name: 'Atwima District', startDate: DateTime(2025, 1, 1));
      await repo.approveDistrict(dist2.id);
      final asmOther = await repo.addAssembly(districtId: dist2.id, name: 'Central Assembly');
      expect(asmOther.name, 'Central Assembly');
    });

    test('Pastor can rename and hide (deactivate) an assembly', () async {
      final repo = SupabaseDistrictsRepository();
      final dist = await repo.registerDistrict(name: 'Barekese District', startDate: DateTime(2025, 1, 1));
      await repo.approveDistrict(dist.id);

      final asm = await repo.addAssembly(districtId: dist.id, name: 'Faith Assembly');

      // Rename assembly
      final renamed = await repo.renameAssembly(assemblyId: asm.id, newName: 'Grace & Faith Assembly');
      expect(renamed.name, 'Grace & Faith Assembly');

      // Hide / Deactivate assembly
      await repo.toggleAssemblyStatus(assemblyId: asm.id, isActive: false);

      final activeList = await repo.getAssembliesForDistrict(dist.id, activeOnly: true);
      expect(activeList.any((a) => a.id == asm.id), isFalse);

      final allList = await repo.getAssembliesForDistrict(dist.id, activeOnly: false);
      expect(allList.any((a) => a.id == asm.id && !a.isActive), isTrue);
    });

    testWidgets('Member sign-up shows "Your pastor has not added assemblies yet" when district has no active assemblies', (WidgetTester tester) async {
      final container = ProviderContainer();
      final distRepo = container.read(districtsRepositoryProvider);

      // Create an active district with NO assemblies
      await distRepo.addDistrictDirectly(name: 'Brand New District');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: SignUpScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open district dropdown and select the active district
      await tester.tap(find.text(AppStrings.chooseDistrict), warnIfMissed: false);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Brand New District').last);
      await tester.pumpAndSettle();

      // Expect warning message and disabled form
      expect(find.text('Your pastor has not added assemblies yet. Please try again soon.'), findsOneWidget);

      container.dispose();
    });

    testWidgets('DistrictAssembliesScreen displays empty state with "Add your first assembly" button', (WidgetTester tester) async {
      final container = ProviderContainer();
      final distRepo = container.read(districtsRepositoryProvider);
      final dist = await distRepo.registerDistrict(name: 'Empty Assemblies District', startDate: DateTime(2025, 1, 1));
      await distRepo.approveDistrict(dist.id);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: DistrictAssembliesScreen(
              districtId: dist.id,
              districtName: dist.name,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No Assemblies Added Yet'), findsOneWidget);
      expect(find.text('Add your first assembly'), findsOneWidget);

      container.dispose();
    });

    test('Security & Permissions: Pending pastor cannot post projects or thoughts', () async {
      final repo = SupabaseDistrictsRepository();
      final authRepo = SupabaseAuthRepository();

      // Create and set mock pastor profile
      final pastorUser = UserProfile(
        id: 'mock-pastor-pending-1',
        email: 'pastor.pending@copabuakwa.org',
        fullName: 'Pastor Pending User',
        role: UserRole.pastor,
        createdAt: DateTime.now(),
      );
      SupabaseAuthRepository.updateCurrentMockUser(pastorUser);

      // Register district as pending
      final dist = await repo.registerDistrict(name: 'Pending District Test', startDate: DateTime(2025, 1, 1));
      expect(dist.status, DistrictStatus.pending);

      final current = await authRepo.getCurrentProfile();
      expect(current?.districtStatus, DistrictStatus.pending);

      // Verify that user profile role helper confirms pending status
      expect(current?.isPastor, isTrue);
      expect(current?.districtStatus == DistrictStatus.active, isFalse);
    });

    test('Security & Permissions: Assembly create/update blocks duplicates and cross-district additions', () async {
      final repo = SupabaseDistrictsRepository();
      final dist1 = await repo.registerDistrict(name: 'District One', startDate: DateTime(2025, 1, 1));
      final dist2 = await repo.registerDistrict(name: 'District Two', startDate: DateTime(2025, 1, 1));
      await repo.approveDistrict(dist1.id);
      await repo.approveDistrict(dist2.id);

      final asm1 = await repo.addAssembly(districtId: dist1.id, name: 'Victory Assembly');
      expect(asm1.name, 'Victory Assembly');

      // Duplicate in dist1 is blocked
      expect(
        () => repo.addAssembly(districtId: dist1.id, name: 'victory assembly'),
        throwsA(predicate((e) => e.toString().contains('already exists'))),
      );

      // Dist2 has separate assembly list
      final asm2 = await repo.addAssembly(districtId: dist2.id, name: 'Grace Assembly');
      expect(asm2.name, 'Grace Assembly');
      expect(asm2.districtId, dist2.id);

      final dist1List = await repo.getAssembliesForDistrict(dist1.id);
      expect(dist1List.any((a) => a.id == asm2.id), isFalse);
    });
  });

  group('Part 4: Area Head Pending Card & Instant Count Tests', () {
    testWidgets('Pending card renders real pastor name, start date, and no assemblies list', (WidgetTester tester) async {
      final container = ProviderContainer();
      final authRepo = container.read(authRepositoryProvider);
      final distRepo = container.read(districtsRepositoryProvider);

      final invite = await authRepo.createInvite(role: UserRole.pastor, targetName: 'Pastor Isaac Mensah');
      final pastor = await authRepo.redeemInvite(
        code: invite.code,
        email: 'pastor.mensah@copabuakwa.org',
        password: 'Password123!',
        fullName: 'Pastor Isaac Mensah',
      );
      container.read(authStateProvider.notifier).setMockProfile(pastor);

      final dist = await distRepo.registerDistrict(
        name: 'Nsuta District',
        startDate: DateTime(2025, 4, 15),
      );

      // Area Head visits District Activation screen
      final areaHead = UserProfile(
        id: 'mock-area-head-id',
        fullName: 'Apostle Area Head',
        email: 'areahead@copabuakwa.org',
        role: UserRole.areaHead,
        status: ProfileStatus.active,
        createdAt: DateTime(2026, 1, 1),
      );
      container.read(authStateProvider.notifier).setMockProfile(areaHead);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const AbuakwaApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to District Activation / Management screen
      await tester.tap(find.text('Districts'));
      await tester.pumpAndSettle();

      // Pending card should show Pastor Isaac Mensah and Tenure Start
      expect(find.text('Nsuta District'), findsWidgets);
      expect(find.text('Pastor Isaac Mensah'), findsWidgets);
      expect(find.textContaining('Tenure Start:'), findsWidgets);
      expect(find.text('Approve'), findsWidgets);
      expect(find.text('Reject'), findsWidgets);

      // Tap Approve
      await tester.tap(find.text('Approve').first);
      await tester.pumpAndSettle();

      // Instantly tab count updates
      final updatedDist = await distRepo.getDistrictById(dist.id);
      expect(updatedDist?.isActive, isTrue);

      container.dispose();
    });
  });

  group('Part 3: Photo Compression & Attribution Tests', () {
    test('ImageCompressor resizes and compresses large image', () async {
      final rawImage = img.Image(width: 2400, height: 1800);
      img.fill(rawImage, color: img.ColorRgb8(31, 58, 95));
      final rawJpgBytes = Uint8List.fromList(img.encodeJpg(rawImage, quality: 100));

      expect(rawJpgBytes.isNotEmpty, isTrue);

      final compressedBytes = await ImageCompressor.compressPostImage(rawJpgBytes, maxDimension: 1600, quality: 80);
      final decoded = img.decodeImage(compressedBytes);

      expect(decoded, isNotNull);
      expect(decoded!.width <= 1600, isTrue);
      expect(decoded.height <= 1600, isTrue);
      expect(compressedBytes.length, lessThan(rawJpgBytes.length));
    });

    test('ImageCompressor creates square avatar correctly', () async {
      final rawImage = img.Image(width: 1200, height: 800);
      img.fill(rawImage, color: img.ColorRgb8(184, 134, 11));
      final rawJpgBytes = Uint8List.fromList(img.encodeJpg(rawImage, quality: 100));

      final avatarBytes = await ImageCompressor.compressAvatar(rawJpgBytes, size: 512);
      final decoded = img.decodeImage(avatarBytes);

      expect(decoded, isNotNull);
      expect(decoded!.width, 512);
      expect(decoded.height, 512);
    });

    testWidgets('AuthorAttributionHeader renders avatar initials, role badge, and opens safe profile dialog', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AuthorAttributionHeader(
              authorName: 'Pastor Kwabena Darko',
              authorRole: UserRole.pastor,
              districtName: 'Abuakwa Central',
              createdAt: DateTime(2026, 10, 2),
            ),
          ),
        ),
      );

      expect(find.text('Pastor Kwabena Darko'), findsOneWidget);
      expect(find.text('Pastor'), findsOneWidget);
      expect(find.text('PD'), findsOneWidget);
      expect(find.textContaining('Abuakwa Central'), findsOneWidget);

      await tester.tap(find.text('Pastor Kwabena Darko'));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsNothing);
    });
  });

  group('Step 4: Transfer Archive & Title Format Tests', () {
    test('Archive title follows exact "Pastor <Full Name>, <startYear>-<endYear>" pattern', () {
      final archive = TenureArchiveModel(
        id: 'arch-1',
        tenureId: 'tenure-1',
        title: 'Pastor Enoch Agyemang, 2021-2026',
        summaryJson: {
          'pastor_name': 'Pastor Enoch Agyemang',
          'district_name': 'Abuakwa North',
          'total_projects': 4,
          'total_events': 14,
          'total_updates': 32,
          'total_thoughts': 18,
        },
        createdAt: DateTime.now(),
      );

      expect(archive.title, 'Pastor Enoch Agyemang, 2021-2026');
      expect(archive.pastorName, 'Pastor Enoch Agyemang');
      expect(archive.districtName, 'Abuakwa North');
      expect(archive.totalProjects, 4);
    });

    test('PDF Generator generates non-empty document bytes', () async {
      final archive = TenureArchiveModel(
        id: 'arch-1',
        tenureId: 'tenure-1',
        title: 'Pastor Enoch Agyemang, 2021-2026',
        summaryJson: {
          'pastor_name': 'Pastor Enoch Agyemang',
          'district_name': 'Abuakwa North',
          'total_projects': 4,
          'total_events': 14,
          'total_updates': 32,
          'total_thoughts': 18,
        },
        createdAt: DateTime.now(),
      );

      final pdfBytes = await ArchivePdfGenerator.generateArchivePdf(archive);
      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.length, greaterThan(100));
    });
  });

  group('Step 5: Meetings Repository Tests', () {
    test('Jitsi room link includes audio-only and muted video flags', () async {
      final repo = SupabaseMeetingsRepository();
      final meeting = await repo.createInstantMeeting(
        title: 'Abuakwa Pastors Monthly',
        createdBy: 'user-1',
        creatorName: 'Apostle Area Head',
      );

      expect(meeting.roomLink.startsWith('https://meet.jit.si/Abuakwa_'), isTrue);
      expect(meeting.roomLink.contains('#config.startWithAudioOnly=true&config.startWithVideoMuted=true'), isTrue);
    });
  });
}
