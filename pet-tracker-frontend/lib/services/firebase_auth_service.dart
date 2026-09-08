import 'package:firebase_auth/firebase_auth.dart';

import '../core/firebase/firebase_initializer.dart';
import '../core/firebase/firebase_options.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/models/firebase_auth_session.dart';

class FirebaseAuthService implements FirebaseAuthGateway {
  bool _initialized = false;

  @override
  bool get isConfigured => FrontendFirebaseOptions.isConfigured;

  User? get currentUser {
    if (!_initialized) return null;
    return FirebaseAuth.instance.currentUser;
  }

  @override
  Stream<FirebaseAuthSession?> authStateChanges() async* {
    await initialize();
    if (!isConfigured) {
      yield null;
      return;
    }

    yield* FirebaseAuth.instance.authStateChanges().map(_sessionFromUser);
  }

  Future<void> initialize() async {
    if (_initialized || !isConfigured) return;
    await FirebaseInitializer.initialize();
    _initialized = true;
  }

  @override
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    await initialize();
    _ensureConfigured();
    return FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  @override
  Future<UserCredential> signUp({
    required String email,
    required String password,
  }) async {
    await initialize();
    _ensureConfigured();
    return FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  @override
  Future<void> signOut() async {
    if (!_initialized) return;
    await FirebaseAuth.instance.signOut();
  }

  @override
  Future<String?> idToken() async {
    await initialize();
    if (!isConfigured) return null;
    return FirebaseAuth.instance.currentUser?.getIdToken();
  }

  @override
  Future<String?> freshIdToken() async {
    await initialize();
    if (!isConfigured) return null;
    return FirebaseAuth.instance.currentUser?.getIdToken(true);
  }

  FirebaseAuthSession? _sessionFromUser(User? user) {
    if (user == null) return null;
    return FirebaseAuthSession(uid: user.uid, email: user.email);
  }

  void _ensureConfigured() {
    if (!isConfigured) {
      throw FirebaseAuthServiceException(
        'Firebase is not configured. Provide FIREBASE_API_KEY, FIREBASE_PROJECT_ID, and FIREBASE_APP_ID with --dart-define.',
      );
    }
  }
}

class FirebaseAuthServiceException implements Exception {
  final String message;

  const FirebaseAuthServiceException(this.message);

  @override
  String toString() => message;
}
