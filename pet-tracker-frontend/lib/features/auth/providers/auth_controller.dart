import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../services/firebase_auth_service.dart';
import '../data/auth_repository.dart';
import '../models/auth_state.dart';
import 'auth_providers.dart';

class AuthController extends Notifier<AuthState> {
  StreamSubscription<void>? _authSubscription;

  @override
  AuthState build() {
    final repository = ref.watch(authRepositoryProvider);
    _authSubscription?.cancel();
    _authSubscription = repository.authStateChanges().listen(
      (session) async {
        if (session == null) {
          state = const AuthState.unauthenticated();
          return;
        }
        await _syncBackendUser(repository);
      },
      onError: (Object error) {
        state = AuthState.error(_friendlyMessage(error));
      },
    );
    ref.onDispose(() => _authSubscription?.cancel());
    return const AuthState.initializing();
  }

  Future<void> login({required String email, required String password}) async {
    final repository = ref.read(authRepositoryProvider);
    state = const AuthState.authenticating();
    try {
      final user = await repository.login(email: email, password: password);
      state = AuthState.authenticated(user);
    } catch (error) {
      state = AuthState.error(_friendlyMessage(error));
    }
  }

  Future<void> register({
    required String email,
    required String password,
  }) async {
    final repository = ref.read(authRepositoryProvider);
    state = const AuthState.authenticating();
    try {
      final user = await repository.register(email: email, password: password);
      state = AuthState.authenticated(user);
    } catch (error) {
      state = AuthState.error(_friendlyMessage(error));
    }
  }

  Future<void> logout() async {
    final repository = ref.read(authRepositoryProvider);
    state = const AuthState.authenticating();
    await repository.logout();
    state = const AuthState.unauthenticated();
  }

  Future<void> _syncBackendUser(AuthRepository repository) async {
    state = const AuthState.authenticating();
    try {
      final user = await repository.syncCurrentUser();
      state = AuthState.authenticated(user);
    } catch (error) {
      state = AuthState.error(_friendlyMessage(error));
    }
  }

  String _friendlyMessage(Object error) {
    if (error is FirebaseAuthServiceException) return error.message;
    if (error is FirebaseAuthException) {
      final message = switch (error.code) {
        'invalid-email' => 'Enter a valid email address.',
        'user-disabled' => 'This account has been disabled.',
        'user-not-found' ||
        'wrong-password' ||
        'invalid-credential' => 'Email or password is incorrect.',
        'email-already-in-use' => 'An account already exists for this email.',
        'weak-password' => 'Use a stronger password.',
        'operation-not-allowed' =>
          'Email/password sign-in is not enabled for this Firebase project.',
        'invalid-api-key' => 'Firebase API key is invalid for this project.',
        'network-request-failed' =>
          'Unable to reach Firebase Authentication. Check your connection.',
        _ => 'Authentication failed. Please try again.',
      };
      if (kDebugMode) {
        debugPrint('FirebaseAuthException.code: ${error.code}');
      }
      return '$message (Firebase code: ${error.code})';
    }
    if (error is ApiException) {
      if (error.isUnauthorized) {
        return 'Your session expired. Please sign in again.';
      }
      return error.message;
    }
    return 'Authentication failed. Please try again.';
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
