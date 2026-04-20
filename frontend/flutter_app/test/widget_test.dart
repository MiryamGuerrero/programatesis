import 'package:flutter_test/flutter_test.dart';
import 'package:reuma_nutri_app/core/config/app_config.dart';

void main() {
  test('default FASTAPI base URL is local backend', () {
    expect(AppConfig.fastApiBaseUrl, 'http://localhost:8000/api/v1/');
  });

  test('Supabase values are provided through dart-define at runtime', () {
    expect(AppConfig.supabaseUrl, anyOf(isEmpty, startsWith('https://')));
    expect(AppConfig.supabaseAnonKey, anyOf(isEmpty, startsWith('sb_')));
  });
}
