part of '../main.dart';

class BackendStatusCard extends StatelessWidget {
  final String status;
  final String message;
  final bool online;
  final bool loading;
  final VoidCallback onCheck;

  const BackendStatusCard({
    super.key,
    required this.status,
    required this.message,
    required this.online,
    required this.loading,
    required this.onCheck,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: online
                  ? const Color(0xFFEAFBF1)
                  : const Color(0xFFFFF4E5),
              child: Icon(
                online ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                color: online
                    ? const Color(0xFF15803D)
                    : const Color(0xFFB45309),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Backend Health',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    status,
                    style: TextStyle(
                      color: online
                          ? const Color(0xFF15803D)
                          : const Color(0xFFB45309),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: const TextStyle(
                      color: Color(0xFF73778A),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            FilledButton.tonalIcon(
              onPressed: loading ? null : onCheck,
              icon: loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync_rounded),
              label: Text(loading ? 'Checking' : 'Check'),
            ),
          ],
        ),
      ),
    );
  }
}

class AuthStatusCard extends StatefulWidget {
  final String status;
  final String message;
  final CurrentUser? backendUser;
  final bool loading;
  final Future<void> Function(String email, String password) onSignIn;
  final Future<void> Function(String email, String password) onSignUp;
  final Future<void> Function() onSignOut;
  final Future<void> Function() onLoadCurrentUser;

  const AuthStatusCard({
    super.key,
    required this.status,
    required this.message,
    required this.backendUser,
    required this.loading,
    required this.onSignIn,
    required this.onSignUp,
    required this.onSignOut,
    required this.onLoadCurrentUser,
  });

  @override
  State<AuthStatusCard> createState() => _AuthStatusCardState();
}

class _AuthStatusCardState extends State<AuthStatusCard> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool showPassword = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 720;
    final form = _AuthForm(
      emailController: emailController,
      passwordController: passwordController,
      showPassword: showPassword,
      loading: widget.loading,
      onTogglePassword: () => setState(() => showPassword = !showPassword),
      onSignIn: () => _submit(widget.onSignIn),
      onSignUp: () => _submit(widget.onSignUp),
    );
    final actions = _BackendAuthActions(
      loading: widget.loading,
      backendUser: widget.backendUser,
      onLoadCurrentUser: widget.onLoadCurrentUser,
      onSignOut: widget.onSignOut,
    );

    return AppCard(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF171A2B), Color(0xFF3C2FB8)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: Colors.white24,
                        child: Icon(
                          Icons.verified_user_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Account Access',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Firebase sign-in and backend identity check',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      AuthStatePill(status: widget.status),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    widget.message,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isWide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: form),
                        const SizedBox(width: 18),
                        Expanded(child: actions),
                      ],
                    )
                  else ...[
                    form,
                    const SizedBox(height: 18),
                    actions,
                  ],
                  if (widget.loading) ...[
                    const SizedBox(height: 16),
                    const LinearProgressIndicator(),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit(Future<void> Function(String email, String password) action) {
    final email = emailController.text.trim();
    final password = passwordController.text;
    if (email.isEmpty || password.isEmpty) return;
    action(email, password);
  }
}

class _AuthForm extends StatelessWidget {
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool showPassword;
  final bool loading;
  final VoidCallback onTogglePassword;
  final VoidCallback onSignIn;
  final VoidCallback onSignUp;

  const _AuthForm({
    required this.emailController,
    required this.passwordController,
    required this.showPassword,
    required this.loading,
    required this.onTogglePassword,
    required this.onSignIn,
    required this.onSignUp,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sign in with Firebase',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        const Text(
          'Use an email/password Firebase account. The frontend will request an ID token and attach it to backend calls.',
          style: TextStyle(
            color: Color(0xFF73778A),
            fontSize: 12,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: emailController,
          decoration: inputDecoration(
            'Email address',
          ).copyWith(prefixIcon: const Icon(Icons.mail_outline_rounded)),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 10),
        TextField(
          controller: passwordController,
          decoration: inputDecoration('Password').copyWith(
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
              onPressed: onTogglePassword,
              icon: Icon(
                showPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
          ),
          obscureText: !showPassword,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: loading ? null : onSignIn,
                icon: const Icon(Icons.login_rounded),
                label: const Text('Sign in'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: loading ? null : onSignUp,
                icon: const Icon(Icons.person_add_alt_rounded),
                label: const Text('Create'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BackendAuthActions extends StatelessWidget {
  final bool loading;
  final CurrentUser? backendUser;
  final Future<void> Function() onLoadCurrentUser;
  final Future<void> Function() onSignOut;

  const _BackendAuthActions({
    required this.loading,
    required this.backendUser,
    required this.onLoadCurrentUser,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Backend Verification',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        const Text(
          'After signing in, call /api/v1/auth/me to confirm the backend accepts the Firebase bearer token.',
          style: TextStyle(
            color: Color(0xFF73778A),
            fontSize: 12,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: loading ? null : onLoadCurrentUser,
            icon: const Icon(Icons.cloud_sync_rounded),
            label: const Text('Call /auth/me'),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: loading ? null : onSignOut,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sign out'),
          ),
        ),
        const SizedBox(height: 12),
        if (backendUser == null)
          const InfoPanel(
            icon: Icons.info_outline_rounded,
            text:
                'No backend user loaded yet. This is expected before calling /auth/me.',
          )
        else
          InfoPanel(
            icon: Icons.account_circle_rounded,
            text:
                'Backend user: ${backendUser!.uid} • ${backendUser!.email ?? 'no email'}',
          ),
      ],
    );
  }
}

class AuthStatePill extends StatelessWidget {
  final String status;

  const AuthStatePill({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    final good =
        normalized.contains('signed') || normalized.contains('verified');
    final warning =
        normalized.contains('not configured') || normalized.contains('failed');
    final color = good
        ? const Color(0xFF86EFAC)
        : warning
        ? const Color(0xFFFCD34D)
        : Colors.white70;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 6),
          Text(
            status,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
