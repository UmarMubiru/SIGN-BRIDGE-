import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signbridge/app/theme/app_theme.dart';
import 'package:signbridge/features/auth/login_screen.dart';
import 'package:signbridge/features/auth/register_screen.dart';

void main() {
  final viewports = <Size>[
    const Size(360, 800), // Android phone portrait
    const Size(800, 390), // Compact tablet / browser window
    const Size(1440, 900), // Desktop web
  ];

  for (final viewport in viewports) {
    testWidgets('login fits or scrolls at $viewport', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = viewport;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.darkTheme,
            home: const LoginScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.text('Login'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('signup fits or scrolls at $viewport', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = viewport;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.darkTheme,
            home: const RegisterScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TextFormField), findsNWidgets(4));
      expect(
        find.widgetWithText(ElevatedButton, 'Create Account'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
