import 'dart:io';

import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/services/notification_service.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/repositories.dart';

class AuthController extends GetxController {
  AuthController(this._backendAuth, this._notifications);
  final BackendAuthRepository _backendAuth;
  final NotificationService _notifications;

  final initializing = true.obs;
  final loading = false.obs;
  final error = ''.obs;
  final Rxn<UserModel> backendUser = Rxn<UserModel>();

  bool get isAuthenticated => backendUser.value != null;

  @override
  void onInit() {
    super.onInit();
    _tryRestoreSession();
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
          _notifications.registerCurrentDevice();
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
    backendUser.value = await _backendAuth.login(trimmedEmail, password);
    await _notifications.registerCurrentDevice();
    Get.offAllNamed(Routes.home);
  });

  Future<void> register(String email, String password, String name) =>
      _authAction(() async {
        final trimmedEmail = email.trim();
        final trimmedName = name.trim();
        if (trimmedName.isEmpty || trimmedEmail.isEmpty || password.isEmpty) {
          throw ApiException('Enter your name, email, and password.');
        }
        backendUser.value = await _backendAuth.register(
          trimmedEmail,
          password,
          trimmedName,
        );
        await _notifications.registerCurrentDevice();
        Get.offAllNamed(Routes.home);
      });

  Future<void> forgotPassword(String email) => _authAction(() async {
    throw ApiException(
      'Password reset is not available for local accounts yet.',
    );
  });

  Future<void> logout() async {
    await _notifications.unregisterCurrentDevice();
    _backendAuth.logout();
    backendUser.value = null;
    Get.offAllNamed(Routes.login);
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
