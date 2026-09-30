import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/constants/app_colors.dart';
import 'core/constants/app_strings.dart';
import 'core/network/supabase_client.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/auth/presentation/screens/home_shell_screen.dart';
import 'features/auth/presentation/screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('[main] .env load warning: $e');
  }

  // Initialize Hive for offline drafts and caching
  try {
    await Hive.initFlutter();
  } catch (e) {
    debugPrint('[main] Hive init warning: $e');
  }

  // Initialize Supabase
  await SupabaseConfig.init();

  runApp(
    const ProviderScope(
      child: AbuakwaApp(),
    ),
  );
}

class AbuakwaApp extends StatelessWidget {
  const AbuakwaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      home: const AuthGate(),
    );
  }
}

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      loading: () => const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const LoginScreen(),
      data: (userProfile) {
        if (userProfile != null) {
          return const HomeShellScreen();
        }
        return const LoginScreen();
      },
    );
  }
}
