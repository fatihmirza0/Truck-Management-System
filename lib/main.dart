import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'firebase_options.dart';
import 'package:flutter/foundation.dart';
import 'widgets/app_theme.dart';

// Ekranlar
import 'screens/login_screen.dart';
import 'screens/manager/manager_screen.dart';
import 'screens/dispatch/dispatch_main_screen.dart';
import 'screens/driver/driver_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    await FlutterDownloader.initialize(
      debug: kDebugMode,
      ignoreSsl: false,
    );
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Truck Management System',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme(),
      initialRoute: '/',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(builder: (_) => const LoginScreen());

          case '/manager':
            return MaterialPageRoute(builder: (_) => ManagerScreen());

          case '/dispatch':
            return MaterialPageRoute(builder: (_) => DispatchMainScreen());

          case '/driver':
            // 🔹 Login ekranından gelen driverId parametresini al
            final args = settings.arguments as Map<String, dynamic>?;
            final driverId = args?['driverId'] ?? '';

            return MaterialPageRoute(
              builder: (_) => DriverScreen(driverId: driverId),
            );

          default:
            return MaterialPageRoute(
              builder: (_) => const Scaffold(
                body: Center(
                  child: Text("404 - Sayfa bulunamadı"),
                ),
              ),
            );
        }
      },
    );
  }
}
