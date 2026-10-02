import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/constants/app_strings.dart';
import 'core/network/supabase_client.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

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

class AbuakwaApp extends ConsumerWidget {
  const AbuakwaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      routerConfig: router,
    );
  }
}
