import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_theme.dart';
import '../../app/widgets/app_card.dart';
import '../../core/cloud_auth_configuration.dart';

const _appVersion = String.fromEnvironment(
  'FLUTTER_BUILD_NAME',
  defaultValue: '0.1.0',
);
const _appBuildNumber = String.fromEnvironment(
  'FLUTTER_BUILD_NUMBER',
  defaultValue: '1',
);

/// Settings keeps local workspace management available in offline builds.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.primaryBackground,
    appBar: AppBar(title: const Text('Settings')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Workspace settings',
            style: TextStyle(
              color: AppTheme.ivory,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SettingsHeading(
                  icon: Icons.folder_copy_outlined,
                  title: 'Local workspace',
                ),
                const SizedBox(height: 8),
                Text(
                  'Create, open, back up, or export the workspace stored on this device.',
                  style: TextStyle(
                    color: AppTheme.ivory.withValues(alpha: 0.78),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => context.push('/workspace'),
                  icon: const Icon(Icons.settings_outlined),
                  label: const Text('MANAGE LOCAL WORKSPACE'),
                ),
              ],
            ),
          ),
          if (cloudAuthEnabled) ...[
            const SizedBox(height: 14),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SettingsHeading(
                    icon: Icons.cloud_outlined,
                    title: 'Optional cloud account',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Manage collector sign-in, registration, account details, and sign-out. Authentication does not upload or sync local workspace data.',
                    style: TextStyle(
                      color: AppTheme.ivory.withValues(alpha: 0.78),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => context.push('/account'),
                    icon: const Icon(Icons.manage_accounts_outlined),
                    label: const Text('MANAGE CLOUD ACCOUNT'),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Center(
            child: Text(
              'SignBridge v$_appVersion+$_appBuildNumber',
              style: TextStyle(
                color: AppTheme.ivory.withValues(alpha: 0.58),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _SettingsHeading extends StatelessWidget {
  const _SettingsHeading({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: AppTheme.teal),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            color: AppTheme.ivory,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    ],
  );
}
