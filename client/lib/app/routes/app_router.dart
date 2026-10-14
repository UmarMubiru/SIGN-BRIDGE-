import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/signers/signers_screen.dart';
import '../../features/signers/create_signer_screen.dart';
import '../../features/signs/signs_screen.dart';
import '../../core/recording/recording_context.dart';
import '../../core/recording/recorded_video.dart';
import '../../features/recording/new_recording_screen.dart';
import '../../features/sessions/sessions_screen.dart';
import '../../features/sessions/session_details_screen.dart';
import '../../features/sessions/create_session_screen.dart';
import '../../features/sessions/sign_recording_screen.dart';
import '../../features/recording/recording_setup_screen.dart';
import '../../features/review/review_screen.dart';
import '../../features/records/records_screen.dart';
import '../../features/coverage/coverage_screen.dart';
import '../../features/datasets/datasets_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        name: 'dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      // Placeholder routes for all screens
      GoRoute(
        path: '/signers',
        name: 'signers',
        builder: (context, state) => const SignersScreen(),
      ),
      GoRoute(
        path: '/signers/create',
        name: 'create_signer',
        builder: (context, state) => const CreateSignerScreen(),
      ),
      GoRoute(
        path: '/signs',
        name: 'signs',
        builder: (context, state) => const SignsScreen(),
      ),
      GoRoute(
        path: '/sessions',
        name: 'sessions',
        builder: (context, state) => const SessionsScreen(),
      ),
      GoRoute(
        path: '/sessions/create',
        name: 'create_session',
        builder: (context, state) {
          final signerId = state.uri.queryParameters['signerId'];
          return CreateSessionScreen(signerId: signerId);
        },
      ),
      GoRoute(
        path: '/sessions/:sessionId/signs',
        name: 'sign_recording',
        builder: (context, state) {
          final sessionId = state.pathParameters['sessionId'] ?? '';
          final signId = state.uri.queryParameters['signId'];
          return SignRecordingScreen(sessionId: sessionId, signId: signId);
        },
      ),
      GoRoute(
        path: '/sessions/:sessionId',
        name: 'session_details',
        builder: (context, state) {
          final sessionId = state.pathParameters['sessionId'] ?? '';
          return SessionDetailsScreen(sessionId: sessionId);
        },
      ),
      GoRoute(
        path: '/recording/setup',
        name: 'recording_setup',
        builder: (context, state) {
          final extra = state.extra;
          final data = extra is Map ? Map<String, dynamic>.from(extra) : null;
          return RecordingSetupScreen(data: data);
        },
      ),
      GoRoute(
        path: '/recording/camera',
        name: 'recording_camera',
        builder: (context, state) {
          final extra = state.extra;
          final rawContext = extra is Map ? extra['recordingContext'] : null;
          final recordingContext = rawContext is RecordingContext
              ? rawContext
              : rawContext is Map
              ? RecordingContext.fromJson(Map<String, dynamic>.from(rawContext))
              : null;

          if (recordingContext == null) {
            return const _UnavailableRecordingRouteScreen();
          }

          return NewRecordingScreen(context: recordingContext);
        },
      ),
      GoRoute(
        path: '/review',
        name: 'review',
        builder: (context, state) {
          final extra = state.extra;
          final rawVideo = extra is Map ? extra['recordedVideo'] : null;
          if (rawVideo is! RecordedVideo) {
            return _UnavailableReviewRouteScreen(
              sessionId: state.uri.queryParameters['sessionId'],
              signId: state.uri.queryParameters['signId'],
            );
          }

          return ReviewScreen(data: {'recordedVideo': rawVideo});
        },
      ),
      GoRoute(
        path: '/validation',
        name: 'validation',
        builder: (context, state) =>
            const _PlaceholderScreen(title: 'Validation'),
      ),
      GoRoute(
        path: '/records',
        name: 'records',
        builder: (context, state) => const RecordsScreen(),
      ),
      GoRoute(
        path: '/coverage',
        name: 'coverage',
        builder: (context, state) => const CoverageScreen(),
      ),
      GoRoute(
        path: '/datasets',
        name: 'datasets',
        builder: (context, state) => const DatasetsScreen(),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) =>
            const _PlaceholderScreen(title: 'Settings'),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

class _PlaceholderScreen extends StatelessWidget {
  final String title;

  const _PlaceholderScreen({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text(
          '$title - Coming Soon',
          style: const TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}

class _UnavailableReviewRouteScreen extends StatelessWidget {
  final String? sessionId;
  final String? signId;

  const _UnavailableReviewRouteScreen({this.sessionId, this.signId});

  @override
  Widget build(BuildContext context) {
    final destination = sessionId == null || sessionId!.isEmpty
        ? '/sessions'
        : Uri(
            path: '/sessions/$sessionId/signs',
            queryParameters: signId == null ? null : {'signId': signId},
          ).toString();

    return Scaffold(
      backgroundColor: AppTheme.primaryBackground,
      appBar: AppBar(title: const Text('Recording Review')),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.video_file_outlined,
                  color: AppTheme.gold,
                  size: 56,
                ),
                const SizedBox(height: 16),
                const Text(
                  'This recording preview can’t be restored after leaving the review screen.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.ivory, fontSize: 16),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Any recording that finished uploading remains saved in your session.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.ivory),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => context.go(destination),
                  child: const Text('Return to session'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UnavailableRecordingRouteScreen extends StatelessWidget {
  const _UnavailableRecordingRouteScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryBackground,
      appBar: AppBar(title: const Text('Recording')),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'This camera setup can’t be restored after leaving the page.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.ivory, fontSize: 16),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => context.go('/sessions'),
                  child: const Text('Return to sessions'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
