import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signbridge/core/api_client.dart';
import 'package:signbridge/core/api_configuration.dart';

void main() {
  group('ApiConfiguration', () {
    test('uses localhost for a Windows development build', () {
      const configuration = ApiConfiguration(
        configuredBaseUrl: '',
        isDebugBuild: true,
        platform: TargetPlatform.windows,
      );

      expect(configuration.isConfigured, isTrue);
      expect(configuration.usesDevelopmentFallback, isTrue);
      expect(configuration.baseUrl, 'http://localhost:8000/api/v1');
    });

    test('uses the Android emulator host for development', () {
      const configuration = ApiConfiguration(
        configuredBaseUrl: '',
        isDebugBuild: true,
        platform: TargetPlatform.android,
      );

      expect(configuration.baseUrl, 'http://10.0.2.2:8000/api/v1');
    });

    test('uses an explicitly configured API URL', () {
      const configuration = ApiConfiguration(
        configuredBaseUrl: 'https://api.example.test/api/v1/',
        isDebugBuild: false,
      );

      expect(configuration.isConfigured, isTrue);
      expect(configuration.usesDevelopmentFallback, isFalse);
      expect(configuration.baseUrl, 'https://api.example.test/api/v1');
    });

    test('leaves release builds unconfigured instead of using localhost', () {
      const configuration = ApiConfiguration(
        configuredBaseUrl: '',
        isDebugBuild: false,
      );

      expect(configuration.isConfigured, isFalse);
      expect(configuration.baseUrl, isEmpty);
      expect(configuration.unavailableMessage, contains('Local workspace'));
    });

    test('uses the browser origin for a web development build', () {
      const configuration = ApiConfiguration(
        configuredBaseUrl: '',
        isDebugBuild: true,
        isWeb: true,
        webOrigin: 'https://collector.example.test',
      );

      expect(configuration.baseUrl, 'https://collector.example.test/api/v1');
    });

    test('formats an unconfigured cloud API error clearly', () {
      const message = 'Optional cloud sign-in is not configured.';
      expect(
        describeApiError(const CloudApiUnavailableException(message)),
        message,
      );
    });
  });
}
