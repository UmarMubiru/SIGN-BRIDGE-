import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:signbridge/core/workspace/local_workspace.dart';
import 'package:signbridge/core/workspace/workspace_service.dart';
import 'package:signbridge/features/workspace/workspace_settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDirectory;
  late LocalWorkspace workspace;
  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tempDirectory = await Directory.systemTemp.createTemp(
      'signbridge_library_navigation_test_',
    );
    final parent = Directory(p.join(tempDirectory.path, 'workspaces'))
      ..createSync();
    final settings = Directory(p.join(tempDirectory.path, 'settings'))
      ..createSync();
    workspace = await WorkspaceService(settingsDirectory: settings)
        .createWorkspace(parentPath: parent.path, name: 'Library Study');
  });
  tearDown(() async {
    await tempDirectory.delete(recursive: true);
    debugDefaultTargetPlatformOverride = null;
  });
  testWidgets('workspace recording entry opens the pinned workspace library', (
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
          path: '/recording/camera',
          builder: (context, state) {
            final extra = state.extra as Map;
            final pinned = extra['workspace'] as LocalWorkspace;
            final recordingContext = extra['recordingContext'];
            return Scaffold(
              body: Text(
                'Pinned ${pinned.name}; sign ${recordingContext.signId}',
              ),
            );
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeWorkspaceProvider.overrideWith((ref) async => workspace),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('START CONTINUOUS RECORDING'), findsOneWidget);
    await tester.tap(find.text('START CONTINUOUS RECORDING'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.text('Pinned Library Study; sign '), findsOneWidget);
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });
}
