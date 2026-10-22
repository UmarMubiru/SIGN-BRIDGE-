import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_theme.dart';
import '../../core/workspace/workspace_service.dart';

String startupRouteForPlatform(TargetPlatform platform) => switch (platform) {
  TargetPlatform.windows ||
  TargetPlatform.linux ||
  TargetPlatform.macOS ||
  TargetPlatform.android => '/workspace',
  _ => '/login',
};

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();
    // Desktop and Android collection start from their platform-appropriate
    // local workspace. Cloud login remains an explicit workspace action.
    _navigationTimer = Timer(const Duration(seconds: 2), _openLocalWorkspace);
  }

  Future<void> _openLocalWorkspace() async {
    if (!mounted) return;
    final initialRoute = startupRouteForPlatform(defaultTargetPlatform);
    if (initialRoute != '/workspace') {
      context.go(initialRoute);
      return;
    }
    try {
      final workspace = await ref
          .read(workspaceServiceProvider)
          .loadActiveWorkspace();
      if (mounted) context.go(workspace == null ? '/workspace' : '/dashboard');
    } catch (_) {
      // A missing or unavailable workspace should return to local setup.
      if (mounted) context.go('/workspace');
    }
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryBackground,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Image.asset(
              'assets/images/signbridge_logo.png',
              width: 300,
              height: 300,
              errorBuilder: (context, error, stackTrace) {
                // Fallback to placeholder if image not found
                return Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.gold, AppTheme.teal],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.accessibility_new,
                    size: 150,
                    color: AppTheme.primaryBackground,
                  ),
                );
              },
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(color: AppTheme.gold),
          ],
        ),
      ),
    );
  }
}
