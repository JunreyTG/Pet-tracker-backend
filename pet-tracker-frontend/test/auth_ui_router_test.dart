import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pettrack/app/router/app_router.dart';
import 'package:pettrack/app/app.dart';
import 'package:pettrack/features/auth/data/auth_repository.dart';
import 'package:pettrack/features/auth/models/current_user.dart';
import 'package:pettrack/features/auth/models/firebase_auth_session.dart';
import 'package:pettrack/features/auth/providers/auth_controller.dart';
import 'package:pettrack/features/auth/providers/auth_providers.dart';

void main() {
  testWidgets('protected route redirects unauthenticated users to login', (
    tester,
  ) async {
    final firebase = _FakeFirebaseAuthGateway(initialSession: null);
    await tester.pumpWidget(_app(firebase: firebase));
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsWidgets);
    expect(find.text('Owner overview will be migrated here.'), findsNothing);

    firebase.dispose();
  });

  testWidgets('authenticated user accessing login redirects to dashboard', (
    tester,
  ) async {
    final firebase = _FakeFirebaseAuthGateway(
      initialSession: const FirebaseAuthSession(
        uid: 'uid-1',
        email: 'owner@example.com',
      ),
    );
    await tester.pumpWidget(_app(firebase: firebase, initialRoute: '/login'));
    await tester.pumpAndSettle();

    expect(find.text('Owner overview will be migrated here.'), findsOneWidget);
    expect(find.text('Access your Pet Tracker dashboard.'), findsNothing);

    firebase.dispose();
  });

  testWidgets('registration validates required fields and password match', (
    tester,
  ) async {
    final firebase = _FakeFirebaseAuthGateway(initialSession: null);
    await tester.pumpWidget(
      _app(firebase: firebase, initialRoute: '/register'),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create account').last);
    await tester.pump();

    expect(find.text('Email is required.'), findsOneWidget);
    expect(find.text('Password is required.'), findsOneWidget);
    expect(find.text('Confirm your password.'), findsOneWidget);

    await tester.enterText(find.byType(EditableText).at(0), 'new@example.com');
    await tester.enterText(find.byType(EditableText).at(1), 'password');
    await tester.enterText(find.byType(EditableText).at(2), 'different');
    await tester.tap(find.text('Create account').last);
    await tester.pump();

    expect(find.text('Passwords do not match.'), findsOneWidget);

    firebase.dispose();
  });

  testWidgets('registration success flows to dashboard', (tester) async {
    final firebase = _FakeFirebaseAuthGateway(initialSession: null);
    await tester.pumpWidget(
      _app(firebase: firebase, initialRoute: '/register'),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(EditableText).at(0), 'new@example.com');
    await tester.enterText(find.byType(EditableText).at(1), 'password');
    await tester.enterText(find.byType(EditableText).at(2), 'password');
    await tester.tap(find.text('Create account').last);
    await tester.pumpAndSettle();

    expect(firebase.signUpCalls, 1);
    expect(find.text('Owner overview will be migrated here.'), findsOneWidget);

    firebase.dispose();
  });
}

ProviderScope _app({
  required _FakeFirebaseAuthGateway firebase,
  String? initialRoute,
}) {
  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(
        AuthRepository(firebaseAuth: firebase, backend: _FakeAuthBackend()),
      ),
    ],
    child: initialRoute == null
        ? const PetTrackerApp()
        : _InitialRouteApp(initialRoute: initialRoute),
  );
}

class _InitialRouteApp extends ConsumerWidget {
  final String initialRoute;

  const _InitialRouteApp({required this.initialRoute});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      routerConfig: createAppRouter(
        ref.watch(authControllerProvider),
        initialLocation: initialRoute,
      ),
    );
  }
}

class _FakeFirebaseAuthGateway implements FirebaseAuthGateway {
  final FirebaseAuthSession? initialSession;
  final _controller = StreamController<FirebaseAuthSession?>.broadcast();
  int signUpCalls = 0;

  _FakeFirebaseAuthGateway({required this.initialSession});

  @override
  bool get isConfigured => true;

  @override
  Stream<FirebaseAuthSession?> authStateChanges() async* {
    yield initialSession;
    yield* _controller.stream;
  }

  @override
  Future<String?> freshIdToken() async => 'fresh-token';

  @override
  Future<String?> idToken() async => 'token';

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<void> signUp({required String email, required String password}) async {
    signUpCalls++;
    _controller.add(FirebaseAuthSession(uid: 'uid-1', email: email));
  }

  void dispose() => _controller.close();
}

class _FakeAuthBackend implements AuthBackend {
  @override
  Future<CurrentUser> me() async {
    return const CurrentUser(
      uid: 'uid-1',
      email: 'owner@example.com',
      displayName: null,
    );
  }
}
