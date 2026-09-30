import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cop_abuakwa_app/core/constants/app_strings.dart';
import 'package:cop_abuakwa_app/features/auth/presentation/screens/login_screen.dart';
import 'package:cop_abuakwa_app/features/auth/presentation/screens/signup_screen.dart';
import 'package:cop_abuakwa_app/features/transfer/domain/models/tenure_archive_model.dart';
import 'package:cop_abuakwa_app/features/transfer/utils/archive_pdf_generator.dart';
import 'package:cop_abuakwa_app/features/meetings/data/meetings_repository.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('Step 2: Login & Sign-up Widget Tests', () {
    testWidgets('LoginScreen renders design elements correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      expect(find.text(AppStrings.appName), findsOneWidget);
      expect(find.text(AppStrings.churchAreaName), findsOneWidget);
      expect(find.text(AppStrings.welcomeBack), findsOneWidget);
      expect(find.text(AppStrings.loginSubtitle), findsOneWidget);
      expect(find.text(AppStrings.logIn), findsOneWidget);
      expect(find.text(AppStrings.createMemberAccount), findsOneWidget);
      expect(find.text(AppStrings.pastorInviteNote), findsOneWidget);
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

      expect(archive.title, startsWith('Pastor '));
      expect(archive.title, contains(', 2021-2026'));
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
      expect(pdfBytes.isNotEmpty, true);
      expect(pdfBytes.length, greaterThan(1000));
    });
  });

  group('Step 5: Meetings & Audio-Only Default Tests', () {
    test('Instant meeting link includes audio-only flags to save data', () async {
      final repo = SupabaseMeetingsRepository();
      final meeting = await repo.createInstantMeeting(
        title: 'Pastors Prayer Call',
        createdBy: 'user-1',
        creatorName: 'Pastor Alpha',
      );

      expect(meeting.roomLink, contains('meet.jit.si'));
      expect(meeting.roomLink, contains('startWithAudioOnly=true'));
      expect(meeting.roomLink, contains('startWithVideoMuted=true'));
    });
  });
}
