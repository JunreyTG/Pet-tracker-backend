import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/auth_api.dart';
import '../../../core/config/api_config.dart';
import '../../../core/network/api_client.dart';
import '../../../services/firebase_auth_service.dart';
import '../data/auth_repository.dart';

final firebaseAuthServiceProvider = Provider<FirebaseAuthService>((ref) {
  return FirebaseAuthService();
});

final authApiClientProvider = Provider<ApiClient>((ref) {
  final firebaseAuthService = ref.watch(firebaseAuthServiceProvider);
  return ApiClient(
    config: const ApiConfig(),
    authTokenProvider: firebaseAuthService.idToken,
    refreshAuthTokenProvider: firebaseAuthService.freshIdToken,
    onUnauthorized: firebaseAuthService.signOut,
  );
});

final authBackendProvider = Provider<AuthBackend>((ref) {
  return AuthApiBackend(AuthApi(ref.watch(authApiClientProvider)));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    firebaseAuth: ref.watch(firebaseAuthServiceProvider),
    backend: ref.watch(authBackendProvider),
  );
});
