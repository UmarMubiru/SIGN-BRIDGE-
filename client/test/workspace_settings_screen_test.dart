import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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
          path: '/login',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('Optional cloud login'))),
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
    expect(find.text('OPTIONAL CLOUD SIGN-IN'), findsOneWidget);
    expect(
      find.textContaining('without an account or internet'),
      findsOneWidget,
    );
    expect(
      find.textContaining('cloud features continue to work'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('cloud login remains optional from the local workspace', (
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
          path: '/login',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('Optional cloud login'))),
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

    await tester.tap(find.text('OPTIONAL CLOUD SIGN-IN'));
    await tester.pumpAndSettle();
    expect(find.text('Optional cloud login'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
