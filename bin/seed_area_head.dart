import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

/// CLI Script to seed the initial Area Head account using .env variables
/// Run via: dart run bin/seed_area_head.dart
Future<void> main() async {
  stdout.writeln('=== Seeding Abuakwa Area Head Account ===');

  final env = <String, String>{};
  final envFile = File('.env');
  if (envFile.existsSync()) {
    for (final line in envFile.readAsLinesSync()) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final eqIdx = trimmed.indexOf('=');
      if (eqIdx != -1) {
        final key = trimmed.substring(0, eqIdx).trim();
        var value = trimmed.substring(eqIdx + 1).trim();
        if ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'"))) {
          value = value.substring(1, value.length - 1);
        }
        env[key] = value;
      }
    }
  }

  final supabaseUrl = env['SUPABASE_URL'] ?? '';
  final serviceRoleKey = env['SUPABASE_SERVICE_ROLE_KEY'] ?? '';
  final email = env['AREA_HEAD_EMAIL'] ?? 'areahead@copabuakwa.org';
  final password = env['AREA_HEAD_PASSWORD'] ?? 'AbuakwaAreaHead2026!';
  final fullName = env['AREA_HEAD_NAME'] ?? 'Apostle Area Head';

  if (supabaseUrl.isEmpty ||
      serviceRoleKey.isEmpty ||
      supabaseUrl.contains('dummy-abuakwa-project')) {
    stdout.writeln('Notice: Local development environment detected.');
    stdout.writeln('Area Head Credentials configured in .env:');
    stdout.writeln('  Email:    $email');
    stdout.writeln('  Name:     $fullName');
    stdout.writeln('  Role:     area_head');
    stdout.writeln('  Password: $password');
    stdout.writeln('[SUCCESS] Area Head account definition validated.');
    return;
  }

  final client = SupabaseClient(supabaseUrl, serviceRoleKey);

  try {
    // 1. Create or update user in Supabase Auth using Admin API
    final adminResponse = await client.auth.admin.createUser(
      AdminUserAttributes(
        email: email,
        password: password,
        emailConfirm: true,
        userMetadata: {
          'full_name': fullName,
          'role': 'area_head',
        },
      ),
    );

    final userId = adminResponse.user?.id;
    if (userId == null) {
      stderr.writeln('Failed to retrieve created user ID');
      return;
    }
    stdout.writeln('Created Auth User: $userId');

    // 2. Upsert Area Head Profile
    await client.from('profiles').upsert({
      'id': userId,
      'full_name': fullName,
      'email': email,
      'role': 'area_head',
      'status': 'active',
      'data_consent_accepted': true,
    });

    stdout.writeln('Successfully seeded Area Head account: $email');
  } catch (e) {
    stderr.writeln('Error provisioning Area Head: $e');
  }
}
