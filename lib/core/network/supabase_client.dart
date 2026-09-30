import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  SupabaseConfig._();

  static bool _isInitialized = false;
  static bool get isInitialized => _isInitialized;

  static SupabaseClient get client {
    if (!_isInitialized) {
      try {
        return Supabase.instance.client;
      } catch (e) {
        throw StateError('Supabase client has not been initialized. Call SupabaseConfig.init() first.');
      }
    }
    return Supabase.instance.client;
  }

  static Future<void> init() async {
    try {
      final url = dotenv.env['SUPABASE_URL'] ?? '';
      final anonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

      if (url.isNotEmpty && anonKey.isNotEmpty && !url.contains('dummy-abuakwa-project')) {
        // ignore: deprecated_member_use
        await Supabase.initialize(
          url: url,
          // ignore: deprecated_member_use
          anonKey: anonKey,
          authOptions: const FlutterAuthClientOptions(
            authFlowType: AuthFlowType.pkce,
          ),
        );
        _isInitialized = true;
        debugPrint('[SupabaseConfig] Initialized successfully with remote endpoint.');
      } else {
        debugPrint('[SupabaseConfig] Using local mock/offline configuration.');
        _isInitialized = false;
      }
    } catch (e) {
      debugPrint('[SupabaseConfig] Initialization error: $e');
      _isInitialized = false;
    }
  }
}
