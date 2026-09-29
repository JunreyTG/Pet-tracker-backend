import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../data/repositories/repositories.dart';
import '../utils/navigation_args.dart';

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel _alertsChannel = AndroidNotificationChannel(
  'pet_tracker_alerts',
  'Pet Tracker Alerts',
  description: 'High-priority notifications for pet tracker events.',
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
);

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('FCM background message received: ${message.messageId}');
}

class NotificationService extends GetxService {
  NotificationService(this._repository);
  final NotificationRepository _repository;
  String? _registeredTokenId;

  String get _platformName {
    if (kIsWeb) return 'android';
    return defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
  }

  String get _deviceName {
    if (kIsWeb) return 'Web Browser';
    return defaultTargetPlatform == TargetPlatform.iOS
        ? 'iOS Device'
        : 'Android Device';
  }

  Future<void> _initLocalNotifications() async {
    if (kIsWeb) return;
    try {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinInit = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const initSettings = InitializationSettings(
        android: androidInit,
        iOS: darwinInit,
      );
      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (response) {
          Get.toNamed(Routes.alerts);
        },
      );

      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(_alertsChannel);
      debugPrint('Local notifications channel "pet_tracker_alerts" initialized.');
    } catch (e) {
      debugPrint('Error initializing local notifications: $e');
    }
  }

  Future<void> registerCurrentDevice() async {
    try {
      if (kIsWeb) {
        debugPrint('FCM push notifications: Web browser environment detected.');
        return;
      }
      await _initLocalNotifications();

      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('FCM: Notification permission denied by user.');
        return;
      }

      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      final token = await messaging.getToken();
      if (token == null) {
        debugPrint('FCM: Could not obtain FCM token.');
        return;
      }
      debugPrint('FCM: Token obtained: ${token.substring(0, 15)}...');
      _registeredTokenId = await _repository.register(
        token,
        _platformName,
        _deviceName,
      );
      debugPrint('FCM: Registered with backend as token_id: $_registeredTokenId');

      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        debugPrint('FCM: Token refreshed.');
        _registeredTokenId = await _repository.register(
          newToken,
          _platformName,
          _deviceName,
        );
      });
      FirebaseMessaging.onMessage.listen((message) => _showForeground(message));
      FirebaseMessaging.onMessageOpenedApp.listen(_navigateFromMessage);
    } catch (e) {
      debugPrint('FCM registration warning: $e');
    }
  }

  Future<void> unregisterCurrentDevice() async {
    final id = _registeredTokenId;
    if (id == null || id.isEmpty) return;
    try {
      await _repository.delete(id);
      _registeredTokenId = null;
      debugPrint('FCM: Unregistered current device token.');
    } catch (e) {
      debugPrint('FCM unregister warning: $e');
    }
  }

  Future<void> _showForeground(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title'] ?? 'Pet Alert';
    final body =
        notification?.body ?? message.data['message'] ?? 'Open alerts for details.';

    if (!kIsWeb) {
      try {
        await _localNotifications.show(
          id: notification?.hashCode ??
              DateTime.now().millisecondsSinceEpoch.remainder(100000),
          title: title,
          body: body,
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              _alertsChannel.id,
              _alertsChannel.name,
              channelDescription: _alertsChannel.description,
              importance: Importance.max,
              priority: Priority.high,
              playSound: true,
              enableVibration: true,
              icon: '@mipmap/ic_launcher',
            ),
            iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          payload: message.data['alert_id'] ?? '',
        );
      } catch (e) {
        debugPrint('Error showing local notification: $e');
      }
    }

    Get.snackbar(
      title,
      body,
      snackPosition: SnackPosition.TOP,
      duration: const Duration(seconds: 4),
    );
  }

  void _navigateFromMessage(RemoteMessage message) {
    final data = message.data;
    if (data['alert_id'] != null) {
      Get.toNamed(Routes.alerts);
    }
    final petId = asIdString(data['pet_id']);
    if (petId != null) {
      Get.toNamed(Routes.petDetails, arguments: petId);
    }
    final deviceId = asIdString(data['device_id']);
    if (deviceId != null) {
      Get.toNamed(Routes.tracking, arguments: deviceId);
    }
  }
}
