import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_theme.dart';
import '../../app/widgets/app_card.dart';
import '../../app/widgets/navigation_back_button.dart';
import '../../core/api_client.dart';
import '../../core/api_configuration.dart';

class CloudAccountScreen extends ConsumerStatefulWidget {
  const CloudAccountScreen({super.key, this.apiConfiguration});

  final ApiConfiguration? apiConfiguration;

  @override
  ConsumerState<CloudAccountScreen> createState() => _CloudAccountScreenState();
}

class _CloudAccountScreenState extends ConsumerState<CloudAccountScreen> {
  final _api = ApiClient();
  bool _loading = true;
  bool _signingOut = false;
  Map<String, dynamic>? _user;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAccount();
  }

  Future<void> _loadAccount() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final configuration = widget.apiConfiguration ?? ApiClient.configuration;
      if (!configuration.isConfigured) {
        if (mounted) {
          setState(() {
            _user = null;
            _error = configuration.unavailableMessage;
          });
        }
        return;
      }
      if (!await _api.isAuthenticated()) {
        if (mounted) setState(() => _user = null);
        return;
      }
      final user = await _api.getCurrentUser();
      if (mounted) setState(() => _user = user);
    } catch (error) {
      if (mounted) setState(() => _error = describeApiError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signOut() async {
    setState(() => _signingOut = true);
    final serverRevoked = await _api.logout();
    if (!mounted) return;
    setState(() {
      _user = null;
      _error = null;
      _signingOut = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          serverRevoked ? 'Signed out. Your local workspace is unchanged.' : 'Signed out on this device. The server could not be reached to revoke the session.',
        ),
      ),
    );
  }

  String _authLocation(String path) => Uri(
    path: path,
    queryParameters: const {'returnTo': '/account'},
  ).toString();

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.primaryBackground,
    appBar: AppBar(
      leading: const NavigationBackButton(),
      title: const Text('Optional cloud account'),
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(20),
            children: [
              const AppCard(
                child: Text(
                  'Cloud sign-in is optional. Your workspace, videos, and collection metadata remain on this device. Signing in does not upload or sync them.',
                  style: TextStyle(color: AppTheme.ivory),
                ),
              ),
              const SizedBox(height: 16),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else if (_error != null)
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Could not load cloud account: $_error',
                        style: const TextStyle(color: AppTheme.error),
                      ),
                      const SizedBox(height: 8),
                      if ((widget.apiConfiguration ?? ApiClient.configuration)
                          .isConfigured)
                        OutlinedButton.icon(
                          onPressed: _loadAccount,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      if (!(widget.apiConfiguration ?? ApiClient.configuration)
                          .isConfigured)
                        TextButton(
                          onPressed: () => context.go('/workspace'),
                          child: const Text('RETURN TO WORKSPACE'),
                        ),
                      TextButton(
                        onPressed: _signOut,
                        child: const Text('Sign out on this device'),
                      ),
                    ],
                  ),
                )
              else if (_user == null)
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Not signed in',
                        style: TextStyle(
                          color: AppTheme.ivory,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: () => context.push(_authLocation('/login')),
                        icon: const Icon(Icons.login),
                        label: const Text('SIGN IN'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () =>
                            context.push(_authLocation('/register')),
                        icon: const Icon(Icons.person_add_alt_1),
                        label: const Text('CREATE COLLECTOR ACCOUNT'),
                      ),
                    ],
                  ),
                )
              else
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Signed in',
                        style: TextStyle(
                          color: AppTheme.teal,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _accountField('Name', _user!['name']),
                      _accountField('Email', _user!['email']),
                      _accountField('Role', _user!['role']),
                      _accountField(
                        'Status',
                        _user!['is_active'] == true ? 'Active' : 'Inactive',
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _signingOut ? null : _signOut,
                        icon: _signingOut
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.logout),
                        label: const Text('SIGN OUT'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _accountField(String label, Object? value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Text(
      '$label: ${value?.toString() ?? '—'}',
      style: const TextStyle(color: AppTheme.ivory),
    ),
  );
}
