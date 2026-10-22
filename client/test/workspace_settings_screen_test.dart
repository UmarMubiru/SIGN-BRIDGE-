import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:signbridge/core/cloud_auth_configuration.dart';
import 'package:signbridge/core/workspace/workspace_service.dart';
import 'package:signbridge/features/workspace/workspace_settings_screen.dart';

void main() {
  testWidgets('workspace settings offers open and create actions', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/workspace',
      routes: [
        GoRoute(
          path: '/workspace',
          builder: (context, state) => const WorkspaceSettingsScreen(),
        ),
        GoRoute(
          path: '/account',
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('Optional cloud account')),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [activeWorkspaceProvider.overrideWith((ref) async => null)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('OPEN EXISTING WORKSPACE'), findsOneWidget);
    expect(find.text('CREATE NEW WORKSPACE'), findsOneWidget);
    expect(
      find.text('OPTIONAL CLOUD ACCOUNT'),
      cloudAuthEnabled ? findsOneWidget : findsNothing,
    );
    expect(
      find.textContaining('without an account or internet'),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Create or open a local workspace to start recording and export datasets',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('cloud account is hidden when cloud authentication is disabled', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/workspace',
      routes: [
        GoRoute(
          path: '/workspace',
          builder: (context, state) => const WorkspaceSettingsScreen(),
        ),
        GoRoute(
          path: '/account',
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('Optional cloud account')),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [activeWorkspaceProvider.overrideWith((ref) async => null)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('OPTIONAL CLOUD ACCOUNT'),
      cloudAuthEnabled ? findsOneWidget : findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Android workspace screen explains app storage and offers restore',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        final router = GoRouter(
          initialLocation: '/workspace',
          routes: [
            GoRoute(
              path: '/workspace',
              builder: (context, state) => const WorkspaceSettingsScreen(),
            ),
            GoRoute(
              path: '/account',
              builder: (context, state) => const Scaffold(
                body: Center(child: Text('Optional cloud account')),
              ),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              activeWorkspaceProvider.overrideWith((ref) async => null),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('RESTORE WORKSPACE FROM FOLDER'), findsOneWidget);
        expect(find.textContaining('may be removed'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
}
