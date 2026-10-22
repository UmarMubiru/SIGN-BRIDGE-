import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_theme.dart';
import '../../app/widgets/app_button.dart';
import '../../core/api_client.dart';
import 'auth_page_layout.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.returnTo});

  final String? returnTo;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  final _apiClient = ApiClient();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        await _apiClient.login(
          _emailController.text.trim(),
          _passwordController.text,
        );

        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          context.go(_safeReturnLocation(widget.returnTo));
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Login failed: ${describeApiError(e)}'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthPageLayout(
      title: 'Welcome',
      highlight: 'Back!',
      subtitle: 'Sign in to continue to your account',
      form: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [
                AutofillHints.username,
                AutofillHints.email,
              ],
              style: const TextStyle(color: AppTheme.ivory),
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'Enter your email',
                prefixIcon: Icon(Icons.mail_rounded),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your email';
                }
                if (!value.contains('@')) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              autofillHints: const [AutofillHints.password],
              style: const TextStyle(color: AppTheme.ivory),
              decoration: InputDecoration(
                labelText: 'Password',
                hintText: 'Enter your password',
                prefixIcon: const Icon(Icons.lock_rounded),
                suffixIcon: IconButton(
                  tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () => setState(() {
                    _obscurePassword = !_obscurePassword;
                  }),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your password';
                }
                if (value.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                text: 'Login',
                icon: Icons.login_rounded,
                onPressed: _handleLogin,
                isLoading: _isLoading,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  "Don't have an account? ",
                  style: TextStyle(color: AppTheme.ivory),
                ),
                TextButton(
                  onPressed: () => context.go(
                    Uri(
                      path: '/register',
                      queryParameters: {
                        if (widget.returnTo != null)
                          'returnTo': _safeReturnLocation(widget.returnTo),
                      },
                    ).toString(),
                  ),
                  child: const Text('Create one'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _safeReturnLocation(String? value) =>
    value != null && value.startsWith('/') && !value.startsWith('//')
    ? value
    : '/dashboard';
