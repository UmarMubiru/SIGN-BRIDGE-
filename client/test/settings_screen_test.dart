import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signbridge/app/theme/app_theme.dart';
import 'package:signbridge/features/workspace/settings_screen.dart';

void main() {
  testWidgets('offline settings exposes local workspace without cloud auth', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.darkTheme, home: const SettingsScreen()),
    );

    expect(find.text('Local workspace'), findsOneWidget);
    expect(find.text('MANAGE LOCAL WORKSPACE'), findsOneWidget);
    expect(find.text('Optional cloud account'), findsNothing);
    expect(find.text('MANAGE CLOUD ACCOUNT'), findsNothing);
    expect(find.text('SignBridge v0.1.0+1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
