import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pettrack/core/network/api_exception.dart';
import 'package:pettrack/features/auth/data/auth_repository.dart';
import 'package:pettrack/features/auth/models/auth_state.dart';
import 'package:pettrack/features/auth/models/current_user.dart';
import 'package:pettrack/features/auth/models/firebase_auth_session.dart';
import 'package:pettrack/features/auth/providers/auth_controller.dart';
import 'package:pettrack/features/auth/providers/auth_providers.dart';

void main() {
  late _FakeFirebaseAuthGateway firebase;
  late _FakeAuthBackend backend;
  late ProviderContainer container;

  setUp(() {
    firebase = _FakeFirebaseAuthGateway();
    backend = _FakeAuthBackend();
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          AuthRepository(firebaseAuth: firebase, backend: backend),
        ),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(firebase.dispose);
  });

  test('starts in initializing state', () {
    expect(
      container.read(authControllerProvider).status,
      AuthStatus.initializing,
    );
  });

  test('moves to unauthenticated when Firebase has no user', () async {
    container.read(authControllerProvider);
    firebase.emit(null);
    await Future<void>.delayed(Duration.zero);

    expect(
      container.read(authControllerProvider).status,
      AuthStatus.unauthenticated,
    );
  });

  test(
    'restores authenticated state from Firebase session and auth me',
    () async {
      container.read(authControllerProvider);
      firebase.emit(
        const FirebaseAuthSession(uid: 'uid-1', email: 'owner@example.com'),
      );
      await Future<void>.delayed(Duration.zero);

      final state = container.read(authControllerProvider);
      expect(state.status, AuthStatus.authenticated);
      expect(state.user?.uid, 'uid-1');
      expect(backend.meCalls, 1);
    },
  );

  test('login success authenticates with backend profile', () async {
    await container
        .read(authControllerProvider.notifier)
        .login(email: 'owner@example.com', password: 'super-secret-password');

    final state = container.read(authControllerProvider);
    expect(firebase.signInCalls, 1);
    expect(backend.meCalls, 1);
    expect(state.status, AuthStatus.authenticated);
  });

  test('login failure shows safe error state', () async {
    firebase.failSignIn = true;

    await container
        .read(authControllerProvider.notifier)
        .login(email: 'owner@example.com', password: 'bad-password');

    final state = container.read(authControllerProvider);
    expect(state.status, AuthStatus.error);
    expect(state.message, isNotEmpty);
  });

  test('Firebase login failure exposes safe diagnostic error code', () async {
    firebase.signInException = FirebaseAuthException(
      code: 'operation-not-allowed',
    );

    await container
        .read(authControllerProvider.notifier)
        .login(email: 'owner@example.com', password: 'password');

    final state = container.read(authControllerProvider);
    expect(state.status, AuthStatus.error);
    expect(state.message, contains('operation-not-allowed'));
    expect(state.message, isNot(contains('super-secret-password')));
  });

  test('registration success authenticates with backend profile', () async {
    await container
        .read(authControllerProvider.notifier)
        .register(email: 'new@example.com', password: 'password');

    final state = container.read(authControllerProvider);
    expect(firebase.signUpCalls, 1);
    expect(backend.meCalls, 1);
    expect(state.status, AuthStatus.authenticated);
  });

  test('registration failure shows safe error state', () async {
    firebase.failSignUp = true;

    await container
        .read(authControllerProvider.notifier)
        .register(email: 'new@example.com', password: 'password');

    final state = container.read(authControllerProvider);
    expect(state.status, AuthStatus.error);
    expect(state.message, isNotEmpty);
  });

  test('logout signs out Firebase and transitions unauthenticated', () async {
    await container.read(authControllerProvider.notifier).logout();

    expect(firebase.signOutCalls, 1);
    expect(
      container.read(authControllerProvider).status,
      AuthStatus.unauthenticated,
    );
  });

  test('/auth/me failure transitions to error', () async {
    backend.error = const ApiException('Backend unavailable.', statusCode: 503);
    container.read(authControllerProvider);
    firebase.emit(
      const FirebaseAuthSession(uid: 'uid-1', email: 'owner@example.com'),
    );
    await Future<void>.delayed(Duration.zero);

    final state = container.read(authControllerProvider);
    expect(state.status, AuthStatus.error);
    expect(state.message, 'Backend unavailable.');
  });

  test('/auth/me 401 signs out Firebase', () async {
    backend.error = const ApiException('Unauthorized.', statusCode: 401);
    container.read(authControllerProvider);
    firebase.emit(
      const FirebaseAuthSession(uid: 'uid-1', email: 'owner@example.com'),
    );
    await Future<void>.delayed(Duration.zero);

    expect(firebase.signOutCalls, 1);
    expect(container.read(authControllerProvider).status, AuthStatus.error);
  });
}

class _FakeFirebaseAuthGateway implements FirebaseAuthGateway {
  final _controller = StreamController<FirebaseAuthSession?>.broadcast();
  bool failSignIn = false;
  bool failSignUp = false;
  Object? signInException;
  int signInCalls = 0;
  int signUpCalls = 0;
  int signOutCalls = 0;

  @override
  bool get isConfigured => true;

  @override
  Stream<FirebaseAuthSession?> authStateChanges() => _controller.stream;

  void emit(FirebaseAuthSession? session) => _controller.add(session);

  @override
  Future<String?> freshIdToken() async => 'fresh-token';

  @override
  Future<String?> idToken() async => 'token';

  @override
  Future<void> signIn({required String email, required String password}) async {
    signInCalls++;
    final exception = signInException;
    if (exception != null) throw exception;
    if (failSignIn) throw Exception('internal firebase error');
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
  }

  @override
  Future<void> signUp({required String email, required String password}) async {
    signUpCalls++;
    if (failSignUp) throw Exception('internal firebase error');
  }

  void dispose() => _controller.close();
}

class _FakeAuthBackend implements AuthBackend {
  int meCalls = 0;
  Object? error;

  @override
  Future<CurrentUser> me() async {
    meCalls++;
    final currentError = error;
    if (currentError != null) throw currentError;
    return const CurrentUser(
      uid: 'uid-1',
      email: 'owner@example.com',
      displayName: null,
    );
  }
}
