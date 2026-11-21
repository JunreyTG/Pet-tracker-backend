import 'dart:io';

import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/services/notification_service.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/repositories.dart';
import '../../profile/services/profile_photo_store.dart';

class AuthController extends GetxController {
  AuthController(this._backendAuth, this._notifications);
  final BackendAuthRepository _backendAuth;
  final NotificationService _notifications;

  final initializing = true.obs;
  final loading = false.obs;
  final error = ''.obs;
  final Rxn<UserModel> backendUser = Rxn<UserModel>();
  Worker? _photoWorker;

  bool get isAuthenticated => backendUser.value != null;

  @override
  void onInit() {
    super.onInit();
    Get.find<ApiClient>().onSessionExpired = _endSession;
    _photoWorker = ever(
      backendUser,
      (user) => ProfilePhotoStore.loadFor(user?.uid),
    );
    _tryRestoreSession();
  }

  @override
  void onClose() {
    _photoWorker?.dispose();
    super.onClose();
  }

  Future<void> _tryRestoreSession() async {
    initializing.value = true;
    try {
      final api = Get.find<ApiClient>();
      await api.initTokenFromStorage();
      if (api.hasAuthToken) {
        final cached = await _backendAuth.getCachedUser();
        if (cached != null) {
          backendUser.value = cached;
        }
        try {
          final liveUser = await _backendAuth.me();
          backendUser.value = liveUser;
          if (!liveUser.emailVerificationRequired) {
            _notifications.registerCurrentDevice();
          }
        } catch (e) {
          if (e is ApiException && e.statusCode == 401) {
            await logout();
            return;
          }
        }
      }
    } catch (_) {
    } finally {
      initializing.value = false;
    }
  }

  Future<void> login(String email, String password) => _authAction(() async {
    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty || password.isEmpty) {
      throw ApiException('Enter your email and password.');
    }
    final user = await _backendAuth.login(trimmedEmail, password);
    backendUser.value = user;
    if (user.emailVerificationRequired) {
      Get.offAllNamed(Routes.emailSettings);
    } else {
      await _notifications.registerCurrentDevice();
      Get.offAllNamed(Routes.home);
    }
  });

  Future<void> register(String email, String password, String name) =>
      _authAction(() async {
        final trimmedEmail = email.trim();
        final trimmedName = name.trim();
        if (trimmedName.isEmpty || trimmedEmail.isEmpty || password.isEmpty) {
          throw ApiException('Enter your name, email, and password.');
        }
        final user = await _backendAuth.register(
          trimmedEmail,
          password,
          trimmedName,
        );
        backendUser.value = user;
        if (user.emailVerificationRequired) {
          Get.offAllNamed(Routes.emailSettings, arguments: true);
        } else {
          await _notifications.registerCurrentDevice();
          Get.offAllNamed(Routes.home);
        }
      });

  Future<void> forgotPassword(String email) => _authAction(() async {
    throw ApiException(
      'Password reset is not available for local accounts yet.',
    );
  });

  Future<void> logout() async {
    await _notifications.unregisterCurrentDevice();
    _endSession();
  }

  void _endSession() {
    _backendAuth.logout();
    _notifications.clearSession();
    backendUser.value = null;
    if (!initializing.value) Get.offAllNamed(Routes.login);
  }

  Future<void> updateDisplayName(String name) =>
      updateProfile(displayName: name);

  Future<void> updateProfile({
    String? displayName,
    String? phone,
    String? location,
    String? bio,
  }) async {
    final changes = <String, dynamic>{
      'display_name': ?displayName,
      'phone': ?phone,
      'location': ?location,
      'bio': ?bio,
    };
    if (changes.isEmpty) return;
    final session = Get.find<ApiClient>().authToken;
    final user = await _backendAuth.updateProfile(changes);
    if (session == Get.find<ApiClient>().authToken &&
        backendUser.value?.uid == user.uid) {
      backendUser.value = user;
    }
  }

  Future<void> changePassword(String current, String replacement) async {
    final session = Get.find<ApiClient>().authToken;
    await _backendAuth.changePassword(current, replacement);
    if (session == Get.find<ApiClient>().authToken) {
      _endSession();
      Get.snackbar('Password changed', 'Sign in again with your new password.');
    }
  }

  Future<void> sendEmailVerification() => _backendAuth.sendEmailVerification();

  Future<void> verifyEmail(String code) async {
    final session = Get.find<ApiClient>().authToken;
    final wasRequired = backendUser.value?.emailVerificationRequired == true;
    final user = await _backendAuth.verifyEmail(code);
    if (session != Get.find<ApiClient>().authToken ||
        backendUser.value?.uid != user.uid) {
      return;
    }
    backendUser.value = user;
    if (wasRequired) await _notifications.registerCurrentDevice();
  }

  Future<void> setEmailAlerts(bool enabled) async {
    final session = Get.find<ApiClient>().authToken;
    final user = await _backendAuth.setEmailAlerts(enabled);
    if (session == Get.find<ApiClient>().authToken &&
        backendUser.value?.uid == user.uid) {
      backendUser.value = user;
    }
  }

  Future<void> syncBackendUser({bool rethrowErrors = false}) async {
    try {
      backendUser.value = await _backendAuth.me();
    } on ApiException catch (e) {
      error.value = e.message;
      if (rethrowErrors) rethrow;
    }
  }

  Future<void> _authAction(Future<void> Function() action) async {
    if (loading.value) return;
    loading.value = true;
    error.value = '';
    try {
      await action();
    } on ApiException catch (e) {
      error.value = e.message;
      Get.snackbar('Authentication', error.value);
    } on SocketException {
      error.value = 'Network error. Check your connection.';
      Get.snackbar('Network', error.value);
    } catch (e) {
      error.value = e.toString();
      Get.snackbar('Error', error.value);
    } finally {
      loading.value = false;
    }
  }
}
