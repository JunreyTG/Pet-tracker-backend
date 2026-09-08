import '../../../api/auth_api.dart';
import '../../../core/network/api_exception.dart';
import '../models/firebase_auth_session.dart';

abstract class AuthBackend {
  Future<CurrentUser> me();
}

abstract class FirebaseAuthGateway {
  bool get isConfigured;
  Stream<FirebaseAuthSession?> authStateChanges();
  Future<void> signIn({required String email, required String password});
  Future<void> signUp({required String email, required String password});
  Future<void> signOut();
  Future<String?> idToken();
  Future<String?> freshIdToken();
}

class AuthApiBackend implements AuthBackend {
  final AuthApi _authApi;

  const AuthApiBackend(this._authApi);

  @override
  Future<CurrentUser> me() => _authApi.me();
}

class AuthRepository {
  final FirebaseAuthGateway firebaseAuth;
  final AuthBackend backend;

  const AuthRepository({required this.firebaseAuth, required this.backend});

  bool get isFirebaseConfigured => firebaseAuth.isConfigured;

  Stream<FirebaseAuthSession?> authStateChanges() {
    return firebaseAuth.authStateChanges();
  }

  Future<CurrentUser> login({
    required String email,
    required String password,
  }) async {
    await firebaseAuth.signIn(email: email, password: password);
    return syncCurrentUser();
  }

  Future<CurrentUser> register({
    required String email,
    required String password,
  }) async {
    await firebaseAuth.signUp(email: email, password: password);
    return syncCurrentUser();
  }

  Future<void> logout() async {
    await firebaseAuth.signOut();
  }

  Future<CurrentUser> syncCurrentUser() async {
    try {
      return await backend.me();
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await firebaseAuth.signOut();
      }
      rethrow;
    }
  }

  Future<String?> idToken() => firebaseAuth.idToken();

  Future<String?> freshIdToken() => firebaseAuth.freshIdToken();
}
