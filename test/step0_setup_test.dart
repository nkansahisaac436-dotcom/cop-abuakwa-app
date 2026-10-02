import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cop_abuakwa_app/core/constants/app_colors.dart';
import 'package:cop_abuakwa_app/core/constants/app_strings.dart';
import 'package:cop_abuakwa_app/core/network/supabase_client.dart';
import 'package:cop_abuakwa_app/core/theme/app_theme.dart';
import 'package:cop_abuakwa_app/core/widgets/warning_banner.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SupabaseConfig.setMockMode(true);
  });

  test('Theme and color tokens are correctly defined', () {
    expect(AppColors.navy, const Color(0xFF1F3A5F));
    expect(AppColors.gold, const Color(0xFFB8860B));
    expect(AppColors.warningFill, const Color(0xFFFFF4E0));
    expect(AppColors.warningBorder, const Color(0xFFE0A11B));
    expect(AppColors.warningText, const Color(0xFF7A4A00));
    expect(AppTheme.lightTheme.primaryColor, AppColors.navy);
  });

  test('Required exact strings match specification', () {
    expect(
      AppStrings.districtInactiveBlockedToast,
      'Your district has not been approved yet. Please try to sign up again later, once your district is approved.',
    );
    expect(
      AppStrings.invalidCredentialsMessage,
      'Email or password is not correct. Check and try again.',
    );
    expect(
      AppStrings.transferConfirmMessage,
      'Are you sure? This will send a transfer request to the Area Head.',
    );
    expect(AppStrings.ministries.length, 5);
  });

  testWidgets('Church logo image asset exists and can be rendered', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Image.asset(
            'assets/images/abuakwa_logo.png',
            width: 96,
            height: 96,
            semanticLabel: 'Church of Pentecost logo',
          ),
        ),
      ),
    );

    expect(find.byType(Image), findsOneWidget);
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.semanticLabel, 'Church of Pentecost logo');
  });

  testWidgets('WarningBanner displays title and message accurately', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WarningBanner(
            title: AppStrings.districtNotApprovedTitle,
            message: AppStrings.districtNotApprovedMessage,
          ),
        ),
      ),
    );

    expect(find.text(AppStrings.districtNotApprovedTitle), findsOneWidget);
    expect(find.text(AppStrings.districtNotApprovedMessage), findsOneWidget);
  });
}
