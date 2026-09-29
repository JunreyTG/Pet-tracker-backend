import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app/bindings/initial_binding.dart';
import 'app/routes/app_pages.dart';
import 'app/theme/app_theme.dart';
import 'core/services/notification_service.dart';
import 'features/auth/controllers/auth_controller.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  runApp(const PetTrackerApp());
}

class PetTrackerApp extends StatelessWidget {
  const PetTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Pet Tracker',
      debugShowCheckedModeBanner: false,
      initialBinding: InitialBinding(),
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      getPages: AppPages.pages,
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    return Obx(() {
      if (auth.initializing.value) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return auth.isAuthenticated ? AppPages.homeScreen : AppPages.loginScreen;
    });
  }
}
