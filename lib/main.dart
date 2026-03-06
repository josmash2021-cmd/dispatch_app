import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'config/app_theme.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/client_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/driver_provider.dart';
import 'providers/trip_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    // On iOS/macOS: Firebase reads GoogleService-Info.plist automatically.
    // On other platforms: use explicit options from firebase_options.dart.
    final useNativeConfig = !kIsWeb && (Platform.isIOS || Platform.isMacOS);
    if (useNativeConfig) {
      await Firebase.initializeApp();
    } else {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    // Firebase already initialized (hot restart) — ignore duplicate-app error.
    if (!e.toString().contains('duplicate-app')) rethrow;
  }
  await initializeDateFormatting('es', null);
  timeago.setLocaleMessages('es', timeago.EsMessages());
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => TripProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(create: (_) => ClientProvider()),
        ChangeNotifierProvider(create: (_) => DriverProvider()),
      ],
      child: MaterialApp(
        title: 'Dispatch Admin',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const SplashScreen(),
      ),
    );
  }
}

// Watches auth state — redirects to Login or Dashboard automatically
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    switch (auth.status) {
      case AuthStatus.uninitialized:
        return const Scaffold(
          backgroundColor: Color(0xFF08090C),
          body: Center(
            child: CircularProgressIndicator(color: Color(0xFFD4A843)),
          ),
        );
      case AuthStatus.authenticated:
        return const DashboardScreen();
      case AuthStatus.unauthenticated:
      case AuthStatus.loading:
        return const LoginScreen();
    }
  }
}
