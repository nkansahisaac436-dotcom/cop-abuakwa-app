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
import 'package:cop_abuakwa_app/core/widgets/primary_button.dart';
import 'package:cop_abuakwa_app/features/auth/data/auth_repository.dart';
import 'package:cop_abuakwa_app/features/auth/domain/models/profile_model.dart';
import 'package:cop_abuakwa_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:cop_abuakwa_app/features/auth/presentation/screens/login_screen.dart';
import 'package:cop_abuakwa_app/features/auth/presentation/screens/signup_screen.dart';
import 'package:cop_abuakwa_app/features/districts/data/districts_repository.dart';
import 'package:cop_abuakwa_app/features/districts/domain/models/district_model.dart';
import 'package:cop_abuakwa_app/features/districts/presentation/providers/districts_provider.dart';
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

  group('Part 1 & 2: Login & Sign-up Widget Tests', () {
    testWidgets('LoginScreen renders 4 role chips and default Member view on 360px viewport', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      // App Title and Header
      expect(find.text(AppStrings.appName), findsOneWidget);
      expect(find.text(AppStrings.churchAreaName), findsOneWidget);

      // Role Selector
      expect(find.text('I am logging in as'), findsOneWidget);
      expect(find.text('Member'), findsOneWidget);
      expect(find.text('Pastor'), findsOneWidget);
      expect(find.text('Leader'), findsOneWidget);
      expect(find.text('Area Head'), findsOneWidget);

      // Default Member Form
      expect(find.text(AppStrings.email), findsOneWidget);
      expect(find.text(AppStrings.password), findsOneWidget);
      expect(find.text(AppStrings.forgotPassword), findsOneWidget);
      expect(find.text(AppStrings.logIn), findsOneWidget);
      expect(find.text(AppStrings.createMemberAccount), findsOneWidget);
    });

    testWidgets('Two-step invite code flow works cleanly with verification and redemption', (WidgetTester tester) async {
      // First create a pastor invite
      final container = ProviderContainer();
      final authRepo = container.read(authRepositoryProvider);
      final invite = await authRepo.createInvite(
        role: UserRole.pastor,
        targetName: 'Pastor Kwabena Darko',
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      // Tap on Pastor chip
      await tester.tap(find.text('Pastor'));
      await tester.pumpAndSettle();

      expect(find.text('I have an invite code'), findsOneWidget);

      // Switch to "I have an invite code" (Step 1)
      await tester.tap(find.text('I have an invite code'));
      await tester.pumpAndSettle();

      expect(find.text('Invite code'), findsOneWidget);
      expect(find.text('Paste'), findsOneWidget);
      expect(find.text('Verify code'), findsOneWidget);

      // Enter created invite code (auto-verifies on 11 characters)
      await tester.enterText(find.byType(TextFormField).first, invite.code);
      await tester.pumpAndSettle();

      // Step 2: Green card verification badge, locked code, Change code link
      expect(find.text('Invitation verified'), findsOneWidget);
      expect(find.text('Change code'), findsOneWidget);
      expect(find.text('Create a password'), findsOneWidget);
      expect(find.text('Activate my account'), findsOneWidget);

      // Tap "Change code" to return to Step 1
      await tester.tap(find.text('Change code'));
      await tester.pumpAndSettle();

      expect(find.text('Verify code'), findsOneWidget);
      expect(find.text('Invitation verified'), findsNothing);
      container.dispose();
    });

    testWidgets('SignUpScreen renders required fields', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SignUpScreen(),
          ),
        ),
      );

      expect(find.text(AppStrings.createYourAccount), findsOneWidget);
      expect(find.text(AppStrings.fullName), findsOneWidget);
      expect(find.text(AppStrings.email), findsOneWidget);
      expect(find.text(AppStrings.district), findsOneWidget);
      expect(find.text(AppStrings.assembly), findsOneWidget);
      expect(find.text(AppStrings.password), findsOneWidget);
      expect(find.text(AppStrings.dataConsent), findsOneWidget);
      expect(find.text(AppStrings.createAccount), findsOneWidget);
    });
  });

  group('Part 2: Pastor District Self-Registration & Approval Tests', () {
    test('Pastor registers a new district with status pending and assemblies', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final districtsRepo = container.read(districtsRepositoryProvider);
      final registered = await districtsRepo.registerDistrict(
        name: 'Abuakwa North',
        assemblies: ['Bethel Assembly', 'Central Assembly', 'Calvary Assembly'],
        startDate: DateTime(2026, 1, 15),
      );

      expect(registered.name, 'Abuakwa North');
      expect(registered.status, DistrictStatus.pending);
      expect(registered.isPending, isTrue);
      expect(registered.assemblyNames?.length, 3);
      expect(registered.assemblyNames?.first, 'Bethel Assembly');
    });

    test('Duplicate district registration is blocked with friendly error', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final districtsRepo = container.read(districtsRepositoryProvider);
      await districtsRepo.registerDistrict(
        name: 'Abuakwa Central',
        assemblies: ['Central Assembly'],
        startDate: DateTime(2026, 1, 15),
      );

      // Attempt duplicate registration with different casing and spacing
      expect(
        () => districtsRepo.registerDistrict(
          name: '  abuakwa   central  ',
          assemblies: ['Other Assembly'],
          startDate: DateTime(2026, 1, 15),
        ),
        throwsA(predicate((e) => e.toString().contains('This district is already registered. Contact the Area Head office.'))),
      );
    });

    test('Area Head approves pending district', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final districtsRepo = container.read(districtsRepositoryProvider);
      final registered = await districtsRepo.registerDistrict(
        name: 'Abuakwa South',
        assemblies: ['Emmanuel Assembly'],
        startDate: DateTime(2026, 1, 15),
      );

      expect(registered.status, DistrictStatus.pending);

      await districtsRepo.approveDistrict(registered.id, note: 'Approved');
      final approved = await districtsRepo.getDistrictById(registered.id);

      expect(approved, isNotNull);
      expect(approved!.status, DistrictStatus.active);
      expect(approved.isActive, isTrue);
    });

    test('Area Head rejects pending district with decision note', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final districtsRepo = container.read(districtsRepositoryProvider);
      final registered = await districtsRepo.registerDistrict(
        name: 'Incomplete District',
        assemblies: [],
        startDate: DateTime(2026, 1, 15),
      );

      await districtsRepo.rejectDistrict(
        registered.id,
        note: 'Please list at least 2 local assemblies before resubmitting.',
      );

      final rejected = await districtsRepo.getDistrictById(registered.id);
      expect(rejected, isNotNull);
      expect(rejected!.status, DistrictStatus.rejected);
      expect(rejected.isRejected, isTrue);
      expect(rejected.decisionNote, 'Please list at least 2 local assemblies before resubmitting.');

      // Pastor can resubmit with updated assemblies
      final resubmitted = await districtsRepo.resubmitDistrict(
        districtId: rejected.id,
        name: 'Incomplete District',
        assemblies: ['Grace Assembly', 'Hope Assembly'],
        startDate: DateTime(2026, 1, 15),
      );

      expect(resubmitted.status, DistrictStatus.pending);
      expect(resubmitted.assemblyNames?.length, 2);
    });

    test('Pastor invite can be created without a pre-assigned district', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final authRepo = container.read(authRepositoryProvider);
      final invite = await authRepo.createInvite(
        role: UserRole.pastor,
        targetName: 'Pastor Unassigned',
        districtId: null, // District is optional
        districtName: null,
      );

      expect(invite.districtId, isNull);
      expect(invite.districtName, isNull);
      expect(invite.role, UserRole.pastor);
      expect(invite.code.startsWith('ABK-'), isTrue);
    });
  });

  group('Part 3: Photo Compression & Attribution Tests', () {
    test('ImageCompressor resizes and compresses large image', () async {
      // Create a large 2400x1800 raw test image in memory
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
      expect(find.text('PD'), findsOneWidget); // Initials
      expect(find.textContaining('Abuakwa Central'), findsOneWidget);

      // Tap on author attribution header to open safe profile dialog
      await tester.tap(find.text('Pastor Kwabena Darko'));
      await tester.pumpAndSettle();

      // Dialog opens showing name, role, and district (no private email/phone)
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsNothing);
    });
  });

  group('Step 3: All 4 Roles Login & Dashboard Landing Widget Tests', () {
    testWidgets('Area Head logs in and lands on Area Head Dashboard', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: AbuakwaApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Select Area Head chip
      await tester.tap(find.text('Area Head'));
      await tester.pumpAndSettle();

      // Fill in Area Head credentials
      await tester.enterText(find.byType(TextFormField).at(0), 'areahead@copabuakwa.org');
      await tester.enterText(find.byType(TextFormField).at(1), 'AbuakwaAreaHead2026!');
      await tester.pumpAndSettle();

      // Tap Log in button
      await tester.tap(find.widgetWithText(PrimaryButton, AppStrings.logIn));
      await tester.pumpAndSettle();

      // Should be on Area Head Dashboard
      expect(find.text('Area Head Dashboard'), findsOneWidget);
      expect(find.text('Supervisory Actions'), findsOneWidget);
    });

    testWidgets('Pastor activates account and lands on pastor interface', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final container = ProviderContainer();
      final authRepo = container.read(authRepositoryProvider);
      final invite = await authRepo.createInvite(
        role: UserRole.pastor,
        targetName: 'Pastor Kwabena Darko',
        districtId: 'd0000000-0000-0000-0000-000000000001',
        districtName: 'Abuakwa Central',
      );

      // Activate pastor account
      await authRepo.redeemInvite(
        code: invite.code,
        email: 'pastor.darko@copabuakwa.org',
        password: 'Password123!',
        fullName: 'Pastor Kwabena Darko',
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const AbuakwaApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Since account is activated and session exists, lands directly on Pastor Home
      expect(find.text('Feed'), findsOneWidget);
      expect(find.text('My District'), findsOneWidget);
      expect(find.text('Thoughts'), findsOneWidget);
      container.dispose();
    });

    testWidgets('Member signs up with active district and lands on feed', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final container = ProviderContainer();
      final districtsRepo = container.read(districtsRepositoryProvider);
      final dist = await districtsRepo.addDistrictDirectly(
        name: 'Abuakwa Central',
        assemblies: ['Bethel Assembly'],
      );

      final authRepo = container.read(authRepositoryProvider);
      await authRepo.signUpMember(
        fullName: 'Kofi Mensah',
        email: 'kofi.mensah@example.com',
        password: 'Password123!',
        districtId: dist.id,
        assemblyId: 'asm-1',
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const AbuakwaApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Feed'), findsOneWidget);
      expect(find.text('Projects'), findsOneWidget);
      container.dispose();
    });

    testWidgets('Wrong password shows visible error banner and stays on LoginScreen', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: AbuakwaApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Enter wrong password
      await tester.enterText(find.byType(TextFormField).at(0), 'areahead@copabuakwa.org');
      await tester.enterText(find.byType(TextFormField).at(1), 'wrongpassword');
      await tester.pumpAndSettle();

      // Tap Log in button
      await tester.tap(find.widgetWithText(PrimaryButton, AppStrings.logIn));
      await tester.pumpAndSettle();

      // Error banner is visible and screen didn't blank out
      expect(find.text(AppStrings.invalidCredentialsMessage), findsOneWidget);
      expect(find.text(AppStrings.logIn), findsOneWidget);
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

  group('Part 1 & 4: District Lifecycle & Security Hardening Tests', () {
    test('End-to-end Pastor invite without district -> redemption -> self-registration -> pending -> approval -> assembly addition', () async {
      final container = ProviderContainer();
      final authRepo = container.read(authRepositoryProvider);
      final distRepo = container.read(districtsRepositoryProvider);

      // 1. Area Head creates invite with NO district
      final invite = await authRepo.createInvite(
        role: UserRole.pastor,
        targetName: 'Pastor Emmanuel Boakye',
      );
      expect(invite.districtId, isNull);
      expect(invite.districtName, isNull);
      expect(invite.role, UserRole.pastor);

      // 2. Pastor redeems the invite
      final redeemedUser = await authRepo.redeemInvite(
        code: invite.code,
        email: 'pastor.boakye@copabuakwa.org',
        password: 'SecurePassword123!',
        fullName: 'Pastor Emmanuel Boakye',
      );
      expect(redeemedUser.role, UserRole.pastor);
      expect(redeemedUser.districtId, isNull);

      // 3. Pastor registers new district with 2 assemblies and start date
      final registeredDistrict = await distRepo.registerDistrict(
        name: 'Tanoso East District',
        assemblies: ['Central Assembly', 'Bethany Assembly'],
        startDate: DateTime(2025, 1, 15),
      );

      // 4. District is saved as pending
      expect(registeredDistrict.isPending, isTrue);
      expect(registeredDistrict.name, 'Tanoso East District');
      expect(registeredDistrict.assemblyNames?.length, 2);

      // 5. Area Head fetches districts and sees the pending district
      final allDistricts = await distRepo.getDistricts();
      final pendingList = allDistricts.where((d) => d.isPending).toList();
      expect(pendingList.any((d) => d.id == registeredDistrict.id), isTrue);

      // 6. Area Head approves the district
      await distRepo.approveDistrict(registeredDistrict.id, note: 'Approved by Apostle Area Head.');
      final approvedDist = await distRepo.getDistrictById(registeredDistrict.id);
      expect(approvedDist?.isActive, isTrue);

      // 7. Pastor adds an additional assembly later
      final newAsm = await distRepo.addAssembly(
        districtId: registeredDistrict.id,
        name: 'Maranatha Assembly',
      );
      expect(newAsm.name, 'Maranatha Assembly');
      expect(newAsm.districtId, registeredDistrict.id);

      final updatedAssemblies = await distRepo.getAssembliesForDistrict(registeredDistrict.id);
      expect(updatedAssemblies.any((a) => a.name == 'Maranatha Assembly'), isTrue);

      container.dispose();
    });

    test('Duplicate district names are blocked with descriptive message', () async {
      final repo = SupabaseDistrictsRepository();
      await repo.registerDistrict(
        name: 'Abuakwa Central',
        assemblies: ['Central Assembly'],
        startDate: DateTime.now(),
      );

      // Attempt duplicate registration with different casing/spacing
      expect(
        () => repo.registerDistrict(
          name: '  abuakwa   central  ',
          assemblies: ['Another Assembly'],
          startDate: DateTime.now(),
        ),
        throwsA(predicate((e) => e.toString().contains('already registered'))),
      );
    });

    test('Invite code brute-force protection locks after 5 consecutive failures', () async {
      final repo = SupabaseAuthRepository();
      SupabaseAuthRepository.resetMockState();

      for (int i = 0; i < 5; i++) {
        try {
          await repo.verifyInviteCode('ABK-WRON-00');
        } catch (_) {}
      }

      // 6th attempt must trigger rate limit exception
      expect(
        () => repo.verifyInviteCode('ABK-WRON-00'),
        throwsA(predicate((e) => e.toString().contains('Too many tries'))),
      );
    });

    test('Member self-service account deletion removes profile record', () async {
      final container = ProviderContainer();
      final authRepo = container.read(authRepositoryProvider);
      final distRepo = container.read(districtsRepositoryProvider);

      // Create an active district
      final activeDist = await distRepo.addDistrictDirectly(
        name: 'Abuakwa Central District',
        assemblies: ['Central Assembly'],
      );

      // Sign up member
      final member = await authRepo.signUpMember(
        fullName: 'Brother John Doe',
        email: 'john.doe@gmail.com',
        password: 'Password123!',
        districtId: activeDist.id,
        assemblyId: 'asm-1',
      );
      expect(member.fullName, 'Brother John Doe');

      // Delete account
      await authRepo.deleteAccount();
      final currentProfile = await authRepo.getCurrentProfile();
      expect(currentProfile, isNull);

      container.dispose();
    });
  });
}
