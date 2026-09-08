part of '../main.dart';

class LoginScreen extends StatelessWidget {
  final String backendStatus;
  final String backendMessage;
  final bool backendOnline;
  final bool isCheckingBackend;
  final VoidCallback onCheckBackend;
  final String authStatus;
  final String authMessage;
  final CurrentUser? backendUser;
  final bool isAuthenticating;
  final Future<void> Function(String email, String password) onSignIn;
  final Future<void> Function(String email, String password) onSignUp;
  final Future<void> Function() onSignOut;
  final Future<void> Function() onLoadCurrentUser;

  const LoginScreen({
    super.key,
    required this.backendStatus,
    required this.backendMessage,
    required this.backendOnline,
    required this.isCheckingBackend,
    required this.onCheckBackend,
    required this.authStatus,
    required this.authMessage,
    required this.backendUser,
    required this.isAuthenticating,
    required this.onSignIn,
    required this.onSignUp,
    required this.onSignOut,
    required this.onLoadCurrentUser,
  });

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFEEF2FF), Color(0xFFF8FAFC)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Expanded(child: _LoginHero()),
                          const SizedBox(width: 28),
                          Expanded(child: _LoginPanel(content: _content())),
                        ],
                      )
                    : Column(
                        children: [
                          const _LoginHero(),
                          const SizedBox(height: 22),
                          _LoginPanel(content: _content()),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        BackendStatusCard(
          status: backendStatus,
          message: backendMessage,
          online: backendOnline,
          loading: isCheckingBackend,
          onCheck: onCheckBackend,
        ),
        const SizedBox(height: 14),
        AuthStatusCard(
          status: authStatus,
          message: authMessage,
          backendUser: backendUser,
          loading: isAuthenticating,
          onSignIn: onSignIn,
          onSignUp: onSignUp,
          onSignOut: onSignOut,
          onLoadCurrentUser: onLoadCurrentUser,
        ),
      ],
    );
  }
}

class _LoginHero extends StatelessWidget {
  const _LoginHero();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: const Color(0xFF5B5FEF),
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x335B5FEF),
                blurRadius: 24,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: const Icon(Icons.pets_rounded, color: Colors.white, size: 38),
        ),
        const SizedBox(height: 24),
        const Text(
          'Pet Tracker',
          style: TextStyle(
            color: Color(0xFF171A2B),
            fontSize: 42,
            fontWeight: FontWeight.w900,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Sign in to manage pets, trackers, safe zones, and backend telemetry data from one dashboard.',
          style: TextStyle(color: Color(0xFF5E6475), fontSize: 16, height: 1.5),
        ),
        const SizedBox(height: 22),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: const [
            _LoginFeature(
              icon: Icons.verified_user_rounded,
              label: 'Firebase Auth',
            ),
            _LoginFeature(
              icon: Icons.cloud_done_rounded,
              label: 'FastAPI Backend',
            ),
            _LoginFeature(
              icon: Icons.gps_fixed_rounded,
              label: 'Tracker Ready',
            ),
          ],
        ),
      ],
    );
  }
}

class _LoginPanel extends StatelessWidget {
  final Widget content;

  const _LoginPanel({required this.content});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .72),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 34,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Padding(padding: const EdgeInsets.all(14), child: content),
    );
  }
}

class _LoginFeature extends StatelessWidget {
  final IconData icon;
  final String label;

  const _LoginFeature({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE3E6EF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: const Color(0xFF5B5FEF)),
          const SizedBox(width: 7),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
