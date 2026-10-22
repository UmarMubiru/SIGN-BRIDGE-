import 'package:flutter/foundation.dart';

/// Resolves the optional cloud API without making it a local app dependency.
///
/// An empty API URL selects localhost only in debug builds. Profile and release
/// builds remain unconfigured until an explicit public API URL is supplied.
@immutable
class ApiConfiguration {
  const ApiConfiguration({
    required this.configuredBaseUrl,
    required this.isDebugBuild,
    this.isWeb = false,
    this.platform = TargetPlatform.windows,
    this.webOrigin = '',
  });

  final String configuredBaseUrl;
  final bool isDebugBuild;
  final bool isWeb;
  final TargetPlatform platform;
  final String webOrigin;

  bool get isConfigured => configuredBaseUrl.trim().isNotEmpty || isDebugBuild;

  bool get usesDevelopmentFallback =>
      configuredBaseUrl.trim().isEmpty && isDebugBuild;

  String get baseUrl {
    final configured = configuredBaseUrl.trim();
    if (configured.isNotEmpty) {
      return configured.replaceFirst(RegExp(r'/+$'), '');
    }
    if (!isDebugBuild) return '';

    if (isWeb && webOrigin.isNotEmpty) {
      final origin = Uri.tryParse(webOrigin);
      if (origin != null && origin.hasScheme && origin.host.isNotEmpty) {
        final scheme = origin.scheme == 'https' ? 'https' : 'http';
        return Uri(
          scheme: scheme,
          host: origin.host,
          port: origin.port,
        ).resolve('/api/v1').toString();
      }
    }

    final host = platform == TargetPlatform.android ? '10.0.2.2' : 'localhost';
    return Uri(
      scheme: 'http',
      host: host,
      port: 8000,
    ).resolve('/api/v1').toString();
  }

  String get unavailableMessage =>
      'Optional cloud sign-in is not configured for this build. Local workspace collection remains available.';
}
