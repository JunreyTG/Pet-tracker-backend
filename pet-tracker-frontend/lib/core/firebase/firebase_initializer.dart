import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';

class FirebaseInitializer {
  static bool get isConfigured => FrontendFirebaseOptions.isConfigured;

  static Future<void> initialize() async {
    if (!isConfigured || Firebase.apps.isNotEmpty) return;
    await Firebase.initializeApp(
      options: FrontendFirebaseOptions.currentPlatform,
    );
  }

  const FirebaseInitializer._();
}
