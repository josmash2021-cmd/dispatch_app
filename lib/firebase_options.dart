// File generated manually for Firebase configuration.
// TODO: Replace these placeholder values with your actual Firebase project credentials.
//
// To get your credentials:
// 1. Go to https://console.firebase.google.com/
// 2. Create a new project (or select existing)
// 3. Add an Android app with package name: com.uberclone.dispatch.dispatch_app
// 4. Add a Web app
// 5. Copy the configuration values below
//
// Alternatively, install Git and run:
//   dart pub global activate flutterfire_cli
//   flutterfire configure

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
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
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAdwPUqsI8UuaEQEXw6aaNz7umWeGdWjjg',
    appId: '1:56054738352:web:175c4c0bf0377c59c1ba75',
    messagingSenderId: '56054738352',
    projectId: 'cruise-af9f1',
    authDomain: 'cruise-af9f1.firebaseapp.com',
    storageBucket: 'cruise-af9f1.firebasestorage.app',
    measurementId: 'G-E9KRTB7VPR',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA17wn7sSLxa7WInC8Z8FCA-Pjkb-a2eIw',
    appId: '1:56054738352:android:e37930a44e5476e1c1ba75',
    messagingSenderId: '56054738352',
    projectId: 'cruise-af9f1',
    storageBucket: 'cruise-af9f1.firebasestorage.app',
  );

  // NOTE: iOS uses GoogleService-Info.plist at runtime (main.dart).
  // These options are kept as fallback only — replace appId with the real
  // GOOGLE_APP_ID from Firebase Console once you register the iOS app.
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAdwPUqsI8UuaEQEXw6aaNz7umWeGdWjjg',
    appId: '1:56054738352:ios:0000000000000000',
    messagingSenderId: '56054738352',
    projectId: 'cruise-af9f1',
    storageBucket: 'cruise-af9f1.firebasestorage.app',
    iosBundleId: 'com.uberclone.dispatch.dispatchApp',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyAdwPUqsI8UuaEQEXw6aaNz7umWeGdWjjg',
    appId: '1:56054738352:macos:0000000000000000',
    messagingSenderId: '56054738352',
    projectId: 'cruise-af9f1',
    storageBucket: 'cruise-af9f1.firebasestorage.app',
    iosBundleId: 'com.uberclone.dispatch.dispatchApp',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyAdwPUqsI8UuaEQEXw6aaNz7umWeGdWjjg',
    appId: '1:56054738352:web:175c4c0bf0377c59c1ba75',
    messagingSenderId: '56054738352',
    projectId: 'cruise-af9f1',
    authDomain: 'cruise-af9f1.firebaseapp.com',
    storageBucket: 'cruise-af9f1.firebasestorage.app',
    measurementId: 'G-E9KRTB7VPR',
  );
}
