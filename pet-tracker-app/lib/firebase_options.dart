import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA06wR8-rN8GwUJq1s1NyioBgTm-bieZr8',
    appId: '1:504056122041:android:e35bdef9cd8f7e9c712968',
    messagingSenderId: '504056122041',
    projectId: 'pet-tracker-d3663',
    storageBucket: 'pet-tracker-d3663.firebasestorage.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyA06wR8-rN8GwUJq1s1NyioBgTm-bieZr8',
    appId: '1:504056122041:web:placeholder',
    messagingSenderId: '504056122041',
    projectId: 'pet-tracker-d3663',
    authDomain: 'pet-tracker-d3663.firebaseapp.com',
    storageBucket: 'pet-tracker-d3663.firebasestorage.app',
  );
}
