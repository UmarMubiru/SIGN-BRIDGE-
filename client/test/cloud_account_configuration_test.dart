import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:signbridge/core/api_configuration.dart';
import 'package:signbridge/features/auth/cloud_account_screen.dart';

void main() {
  testWidgets('unconfigured cloud sign-in explains local use and can return', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/account',
      routes: [
        GoRoute(
          path: '/account',
          builder: (context, state) => const CloudAccountScreen(
            apiConfiguration: ApiConfiguration(
              configuredBaseUrl: '',
              isDebugBuild: false,
            ),
          ),
        ),
        GoRoute(
          path: '/workspace',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('Local workspace'))),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('not configured for this build'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Local workspace collection remains available'),
      findsOneWidget,
    );
    expect(find.text('RETURN TO WORKSPACE'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('RETURN TO WORKSPACE'));
    await tester.pumpAndSettle();
    expect(find.text('Local workspace'), findsOneWidget);
  });
}
