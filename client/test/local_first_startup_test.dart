import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signbridge/features/splash/splash_screen.dart';

void main() {
  test('desktop launches into the local workspace without login', () {
    expect(startupRouteForPlatform(TargetPlatform.windows), '/workspace');
    expect(startupRouteForPlatform(TargetPlatform.linux), '/workspace');
    expect(startupRouteForPlatform(TargetPlatform.macOS), '/workspace');
  });

  test('Android starts from the app-private local workspace flow', () {
    expect(startupRouteForPlatform(TargetPlatform.android), '/workspace');
  });
}
