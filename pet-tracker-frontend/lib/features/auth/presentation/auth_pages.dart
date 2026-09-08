import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../shared/widgets/app_card.dart';
import '../models/auth_state.dart';
import '../providers/auth_controller.dart';

class LoginRoutePage extends ConsumerStatefulWidget {
  const LoginRoutePage({super.key});

  @override
  ConsumerState<LoginRoutePage> createState() => _LoginRoutePageState();
}

class _LoginRoutePageState extends ConsumerState<LoginRoutePage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showPassword = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final loading = authState.status == AuthStatus.authenticating;

    return _AuthScaffold(
      title: 'Sign in',
      subtitle: 'Access your Pet Tracker dashboard.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (authState.status == AuthStatus.error) ...[
              _AuthError(message: authState.message ?? 'Unable to sign in.'),
              const SizedBox(height: 14),
            ],
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email address'),
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              validator: _validateEmail,
              enabled: !loading,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'Password',
                suffixIcon: IconButton(
                  onPressed: loading
                      ? null
                      : () => setState(() => _showPassword = !_showPassword),
                  icon: Icon(
                    _showPassword ? Icons.visibility_off : Icons.visibility,
                  ),
                ),
              ),
              obscureText: !_showPassword,
              autofillHints: const [AutofillHints.password],
              validator: _requiredPassword,
              enabled: !loading,
              onFieldSubmitted: (_) => _submit(loading),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: loading ? null : () => _submit(loading),
              child: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Sign in'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: loading ? null : () => context.go('/register'),
              child: const Text('Create an account'),
            ),
          ],
        ),
      ),
    );
  }

  void _submit(bool loading) {
    if (loading || !_formKey.currentState!.validate()) return;
    ref
        .read(authControllerProvider.notifier)
        .login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
  }
}

class RegisterRoutePage extends ConsumerStatefulWidget {
  const RegisterRoutePage({super.key});

  @override
  ConsumerState<RegisterRoutePage> createState() => _RegisterRoutePageState();
}

class _RegisterRoutePageState extends ConsumerState<RegisterRoutePage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _showPassword = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final loading = authState.status == AuthStatus.authenticating;

    return _AuthScaffold(
      title: 'Create account',
      subtitle: 'Register with Firebase email and password.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (authState.status == AuthStatus.error) ...[
              _AuthError(
                message: authState.message ?? 'Unable to create account.',
              ),
              const SizedBox(height: 14),
            ],
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email address'),
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              validator: _validateEmail,
              enabled: !loading,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'Password',
                suffixIcon: IconButton(
                  onPressed: loading
                      ? null
                      : () => setState(() => _showPassword = !_showPassword),
                  icon: Icon(
                    _showPassword ? Icons.visibility_off : Icons.visibility,
                  ),
                ),
              ),
              obscureText: !_showPassword,
              validator: _requiredPassword,
              enabled: !loading,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmPasswordController,
              decoration: const InputDecoration(labelText: 'Confirm password'),
              obscureText: !_showPassword,
              validator: (value) {
                if ((value ?? '').isEmpty) return 'Confirm your password.';
                if (value != _passwordController.text) {
                  return 'Passwords do not match.';
                }
                return null;
              },
              enabled: !loading,
              onFieldSubmitted: (_) => _submit(loading),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: loading ? null : () => _submit(loading),
              child: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create account'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: loading ? null : () => context.go('/login'),
              child: const Text('Back to sign in'),
            ),
          ],
        ),
      ),
    );
  }

  void _submit(bool loading) {
    if (loading || !_formKey.currentState!.validate()) return;
    ref
        .read(authControllerProvider.notifier)
        .register(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
  }
}

class _AuthScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _AuthScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.pets_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(color: AppColors.mutedText),
                    ),
                    const SizedBox(height: 22),
                    child,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthError extends StatelessWidget {
  final String message;

  const _AuthError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(message, style: const TextStyle(color: AppColors.danger)),
    );
  }
}

String? _validateEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return 'Email is required.';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
    return 'Enter a valid email address.';
  }
  return null;
}

String? _requiredPassword(String? value) {
  if ((value ?? '').isEmpty) return 'Password is required.';
  return null;
}
