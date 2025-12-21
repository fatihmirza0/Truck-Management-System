import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:lojistik/services/auth_service.dart';
import 'firebase_options.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

// Screens
import 'services/notification_Service.dart';
import 'screens/login_screen.dart';
import 'screens/manager/manager_screen.dart';
import 'screens/dispatch/dispatch_main_screen.dart';
import 'screens/driver/driver_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MyApp());
  _initServices();
}

Future<void> _initServices() async {
  try {
    await NotificationService.initialize();

    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      await FlutterDownloader.initialize(
        debug: true,
        ignoreSsl: true,
      );

      await FirebaseAppCheck.instance.activate(
        androidProvider: AndroidProvider.debug,
      );
    }
  } catch (e, s) {
    debugPrint("Init services error: $e");
    debugPrintStack(stackTrace: s);
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [
        Locale('tr', 'TR'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      title: 'Truck Management System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blueGrey),
      initialRoute: '/',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(builder: (_) => const SplashScreen());

          case '/login':
            return MaterialPageRoute(builder: (_) => const LoginScreen());

          case '/manager':
            return MaterialPageRoute(builder: (_) => const ManagerScreen());

          case '/dispatch':
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (_) => DispatchMainScreen(uid: args?['uid'] ?? ""),
            );

          case '/driver':
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (_) => DriverScreen(uid: args?['uid'] ?? ""),
            );

          default:
            return MaterialPageRoute(
              builder: (_) => const Scaffold(
                body: Center(child: Text("404 - Sayfa bulunamadı")),
              ),
            );
        }
      },
    );
  }
}

/// 🔥 Splash Screen - Auto login kontrolü yapar
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAutoLogin();
  }

  Future<void> _checkAutoLogin() async {
    // 1.5 saniye splash screen göster
    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;

    // Kullanıcı daha önce giriş yapmış mı?
    final isLoggedIn = await AuthService.isLoggedIn();

    if (!mounted) return;

    if (isLoggedIn) {
      // Otomatik giriş yap
      final userData = await AuthService.getSavedUserData();
      final role = userData['role'];
      final uid = userData['uid'] ?? '';

      if (role == 'manager') {
        Navigator.pushReplacementNamed(context, '/manager');
      } else if (role == 'dispatch') {
        Navigator.pushReplacementNamed(
          context,
          '/dispatch',
          arguments: {'uid': uid},
        );
      } else if (role == 'driver') {
        Navigator.pushReplacementNamed(
          context,
          '/driver',
          arguments: {'uid': uid},
        );
      } else {
        // Rol bilinmiyorsa login'e yönlendir
        Navigator.pushReplacementNamed(context, '/login');
      }
    } else {
      // Giriş yapmamışsa login ekranına git
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.blueGrey.shade900,
              Colors.blueGrey.shade700,
              Colors.blueGrey.shade600,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.local_shipping_rounded,
                  size: 80,
                  color: Colors.blueGrey.shade900,
                ),
              ),
              const SizedBox(height: 32),

              // Başlık
              const Text(
                'Truck Management System',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Kurumsal Araç Takip ve İş Yönetimi',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 48),

              // Loading indicator
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.white.withOpacity(0.8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
