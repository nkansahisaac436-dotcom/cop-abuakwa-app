import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cop_abuakwa_app/core/constants/app_strings.dart';
import 'package:cop_abuakwa_app/features/auth/data/auth_repository.dart';
import 'package:cop_abuakwa_app/main.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SupabaseAuthRepository.resetMockState();
  });

  testWidgets('Initial app renders login screen with app title', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: AbuakwaApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.appName), findsOneWidget);
    expect(find.text(AppStrings.churchAreaName), findsOneWidget);
  });
}
