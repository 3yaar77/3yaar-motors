import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:autoreel/theme.dart';
import 'package:autoreel/nav.dart';
import 'package:autoreel/providers/car_provider.dart';
import 'package:autoreel/providers/plate_provider.dart';
import 'package:autoreel/providers/auth_provider.dart';
import 'package:autoreel/providers/notification_provider.dart';
import 'package:autoreel/providers/reel_provider.dart';
import 'package:autoreel/providers/listings_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:autoreel/firebase_options.dart';
import 'package:autoreel/providers/messages_provider.dart';
import 'package:autoreel/providers/local_chat_provider.dart';
import 'package:autoreel/providers/accessory_provider.dart';

/// Main entry point for the application
///
/// This sets up:
/// - Provider state management
/// - go_router navigation
/// - Material 3 theming with light/dark modes
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    // Diagnostics: confirm project and bucket at runtime
    // Safe to keep in production; prints only to debug console
    // Helps verify same Firebase project on web and mobile
    debugPrint('Firebase project: ' + DefaultFirebaseOptions.currentPlatform.projectId);
    debugPrint('Firebase storage bucket: ' + (DefaultFirebaseOptions.currentPlatform.storageBucket ?? '(none)'));
  } catch (e) {
    // Avoid crashing if Firebase fails to init; log and continue (local-only still works)
    debugPrint('Firebase init failed: $e');
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CarProvider()),
        ChangeNotifierProvider(create: (_) => PlateProvider()),
        ChangeNotifierProvider(create: (_) => LocalChatProvider()),
        ChangeNotifierProxyProvider<AuthProvider, NotificationProvider>(
          create: (_) => NotificationProvider(),
          update: (_, auth, notif) {
            final p = notif ?? NotificationProvider();
            p.attachUser(auth.currentUser?.uid);
            return p;
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, MessagesProvider>(
          create: (_) => MessagesProvider(),
          update: (_, auth, mp) {
            final p = mp ?? MessagesProvider();
            p.attachUser(auth.currentUser?.uid);
            return p;
          },
        ),
        ChangeNotifierProvider(create: (_) => ReelProvider()),
        ChangeNotifierProvider(create: (_) => ListingsProvider()),
        ChangeNotifierProvider(create: (_) => AccessoryProvider()),
      ],
      child: MaterialApp.router(
        title: 'Motix',
        debugShowCheckedModeBanner: false,
        theme: lightTheme,
        darkTheme: darkTheme,
        themeMode: ThemeMode.dark, // Force dark mode for sleek aesthetic
        routerConfig: AppRouter.router,
      ),
    );
  }
}
