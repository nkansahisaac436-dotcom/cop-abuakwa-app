import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cop_abuakwa_app/core/constants/app_strings.dart';
import 'package:cop_abuakwa_app/core/widgets/primary_button.dart';
import 'package:cop_abuakwa_app/features/auth/domain/models/profile_model.dart';
import 'package:cop_abuakwa_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:cop_abuakwa_app/features/auth/presentation/screens/login_screen.dart';
import 'package:cop_abuakwa_app/features/auth/presentation/screens/signup_screen.dart';
import 'package:cop_abuakwa_app/features/transfer/domain/models/tenure_archive_model.dart';
import 'package:cop_abuakwa_app/features/transfer/utils/archive_pdf_generator.dart';
import 'package:cop_abuakwa_app/features/auth/data/auth_repository.dart';
import 'package:cop_abuakwa_app/features/meetings/data/meetings_repository.dart';
import 'package:cop_abuakwa_app/main.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SupabaseAuthRepository.resetMockState();
  });

  group('Step 2: Login & Sign-up Widget Tests', () {
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

    testWidgets('LoginScreen renders and scrolls without overflow on large iPhone (430px)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      expect(find.text('I am logging in as'), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('Two-step invite code flow works cleanly with auto-format, verification, and change code', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      // Tap on Pastor chip
      await tester.tap(find.text('Pastor'));
      await tester.pumpAndSettle();

      // Should see Log in & I have an invite code toggle
      expect(find.text('Log in'), findsNWidgets(2));
      expect(find.text('I have an invite code'), findsOneWidget);
      expect(find.text('No account yet? Ask your Area Head to send you an invite code.'), findsOneWidget);
      expect(find.text(AppStrings.createMemberAccount), findsNothing);

      // Switch to "I have an invite code" (Step 1)
      await tester.tap(find.text('I have an invite code'));
      await tester.pumpAndSettle();

      expect(find.text('Invite code'), findsOneWidget);
      expect(find.text('Paste'), findsOneWidget);
      expect(find.text('Verify code'), findsOneWidget);

      // Enter valid preloaded Pastor invite code (auto-verifies on 11 characters)
      await tester.enterText(find.byType(TextFormField).first, 'ABK-7K4P-2M');
      await tester.pumpAndSettle();

      // Step 2: Green card verification badge, locked code, Change code link
      expect(find.text('Invitation verified'), findsOneWidget);
      expect(find.text('Pastor, Abuakwa Central District'), findsOneWidget);
      expect(find.text('Change code'), findsOneWidget);
      expect(find.text('Create a password'), findsOneWidget);
      expect(find.text('Activate my account'), findsOneWidget);

      // Tap "Change code" to return to Step 1
      await tester.tap(find.text('Change code'));
      await tester.pumpAndSettle();

      expect(find.text('Verify code'), findsOneWidget);
      expect(find.text('Invitation verified'), findsNothing);
    });

    testWidgets('SignUpScreen renders all required fields', (WidgetTester tester) async {
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

  group('Invite Code System & Role Check Unit Tests', () {
    test('Verifying invalid invite code throws expected error message', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final repo = container.read(authRepositoryProvider);

      expect(
        () => repo.verifyInviteCode('ABK-INVALID-00'),
        throwsA(predicate((e) => e.toString().contains('This code is not valid. Ask your Area Head for a new one.'))),
      );
    });

    test('Redeeming invite initiates account with role and district from invite', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final repo = container.read(authRepositoryProvider);
      final profile = await repo.redeemInvite(
        code: 'ABK-7K4P-2M',
        email: 'pastor.darko@copabuakwa.org',
        password: 'password123',
        fullName: 'Pastor Kwabena Darko',
      );

      expect(profile.role, UserRole.pastor);
      expect(profile.fullName, 'Pastor Kwabena Darko');
      expect(profile.email, 'pastor.darko@copabuakwa.org');
    });

    test('Logging in with mismatched role throws specific error message', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final repo = container.read(authRepositoryProvider);

      // Try logging in with member email while selecting Pastor role
      expect(
        () => repo.signIn(
          email: 'kofi@example.com',
          password: 'password123',
          selectedRole: UserRole.pastor,
        ),
        throwsA(predicate((e) => e.toString().contains('This account is not a pastor account. Choose the correct option above.'))),
      );

      // Try logging in with pastor email while selecting Area Head role
      expect(
        () => repo.signIn(
          email: 'pastor@copabuakwa.org',
          password: 'password123',
          selectedRole: UserRole.areaHead,
        ),
        throwsA(predicate((e) => e.toString().contains('This account is not an area head account. Choose the correct option above.'))),
      );

      // Try logging in with Area Head email while selecting Member role
      expect(
        () => repo.signIn(
          email: 'areahead@copabuakwa.org',
          password: 'password123',
          selectedRole: UserRole.member,
        ),
        throwsA(predicate((e) => e.toString().contains('This account is not a member account. Choose the correct option above.'))),
      );
    });

    test('Logging in with wrong password throws invalid credentials message', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final repo = container.read(authRepositoryProvider);

      expect(
        () => repo.signIn(
          email: 'areahead@copabuakwa.org',
          password: 'wrongpassword',
          selectedRole: UserRole.areaHead,
        ),
        throwsA(predicate((e) => e.toString().contains(AppStrings.invalidCredentialsMessage))),
      );
    });

    test('Logging in with user that has no profile row throws specific setup error', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final repo = container.read(authRepositoryProvider);

      expect(
        () => repo.signIn(
          email: 'noprofile@copabuakwa.org',
          password: 'password123',
          selectedRole: UserRole.areaHead,
        ),
        throwsA(predicate((e) => e.toString().contains('Your account is not set up yet. Please contact the Area Head office.'))),
      );
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

    testWidgets('Pastor logs in and lands on Pastor Home Screen', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: AbuakwaApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Select Pastor chip
      await tester.tap(find.text('Pastor'));
      await tester.pumpAndSettle();

      // Fill in Pastor credentials
      await tester.enterText(find.byType(TextFormField).at(0), 'pastor@copabuakwa.org');
      await tester.enterText(find.byType(TextFormField).at(1), 'AbuakwaPastor2026!');
      await tester.pumpAndSettle();

      // Tap Log in button
      await tester.tap(find.widgetWithText(PrimaryButton, AppStrings.logIn));
      await tester.pumpAndSettle();

      // Should be on Pastor Home (Feed, My District, Thoughts tabs)
      expect(find.text('Feed'), findsOneWidget);
      expect(find.text('My District'), findsOneWidget);
      expect(find.text('Thoughts'), findsOneWidget);
    });

    testWidgets('Ministry Leader logs in and lands on Leader Home Screen', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: AbuakwaApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Select Leader chip
      await tester.tap(find.text('Leader'));
      await tester.pumpAndSettle();

      // Fill in Leader credentials
      await tester.enterText(find.byType(TextFormField).at(0), 'womenleader@copabuakwa.org');
      await tester.enterText(find.byType(TextFormField).at(1), 'AbuakwaLeader2026!');
      await tester.pumpAndSettle();

      // Tap Log in button
      await tester.tap(find.widgetWithText(PrimaryButton, AppStrings.logIn));
      await tester.pumpAndSettle();

      // Should be on Leader Home
      expect(find.text('Area Feed'), findsOneWidget);
      expect(find.text('Ministries'), findsOneWidget);
    });

    testWidgets('Member logs in and lands on Member Feed Screen', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: AbuakwaApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Select Member chip (default)
      await tester.enterText(find.byType(TextFormField).at(0), 'kofi@example.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'AbuakwaMember2026!');
      await tester.pumpAndSettle();

      // Tap Log in button
      await tester.tap(find.widgetWithText(PrimaryButton, AppStrings.logIn));
      await tester.pumpAndSettle();

      // Should be on Member Feed
      expect(find.text('Feed'), findsOneWidget);
      expect(find.text('Projects'), findsOneWidget);
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

    testWidgets('Wrong role chip shows specific role mismatch error banner', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: AbuakwaApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Select Area Head chip but enter Pastor email
      await tester.tap(find.text('Area Head'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'pastor@copabuakwa.org');
      await tester.enterText(find.byType(TextFormField).at(1), 'AbuakwaPastor2026!');
      await tester.pumpAndSettle();

      // Tap Log in button
      await tester.tap(find.widgetWithText(PrimaryButton, AppStrings.logIn));
      await tester.pumpAndSettle();

      // Specific error is visible
      expect(find.text('This account is not an area head account. Choose the correct option above.'), findsOneWidget);
    });

    testWidgets('User with no profile row shows specific not set up error banner', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: AbuakwaApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Area Head'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'noprofile@copabuakwa.org');
      await tester.enterText(find.byType(TextFormField).at(1), 'SomePassword123!');
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(PrimaryButton, AppStrings.logIn));
      await tester.pumpAndSettle();

      expect(find.text('Your account is not set up yet. Please contact the Area Head office.'), findsOneWidget);
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
}
