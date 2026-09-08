import 'current_user.dart';

enum AuthStatus {
  initializing,
  unauthenticated,
  authenticating,
  authenticated,
  error,
}

class AuthState {
  final AuthStatus status;
  final CurrentUser? user;
  final String? message;

  const AuthState._({required this.status, this.user, this.message});

  const AuthState.initializing() : this._(status: AuthStatus.initializing);

  const AuthState.unauthenticated({String? message})
    : this._(status: AuthStatus.unauthenticated, message: message);

  const AuthState.authenticating() : this._(status: AuthStatus.authenticating);

  const AuthState.authenticated(CurrentUser user)
    : this._(status: AuthStatus.authenticated, user: user);

  const AuthState.error(String message)
    : this._(status: AuthStatus.error, message: message);

  bool get isLoading =>
      status == AuthStatus.initializing || status == AuthStatus.authenticating;
  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isUnauthenticated =>
      status == AuthStatus.unauthenticated || status == AuthStatus.error;
}
