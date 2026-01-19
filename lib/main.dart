import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'config/router.dart';
import 'config/app_theme.dart';
import 'services/notification_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // 🛡️ Initialize App Check (reCAPTCHA Enterprise for Web)
  try {
    if (!kDebugMode) {
      await FirebaseAppCheck.instance.activate(
        webProvider: ReCaptchaEnterpriseProvider('6LfJJk4sAAAAAK5I7PH5pfUarux-_TZZ7PPhMnmy'),
        androidProvider: AndroidProvider.playIntegrity,
        appleProvider: AppleProvider.deviceCheck,
      );
    } else {
      // In Debug mode, we can optionally activate with a debug provider if needed,
      // but for now, we'll just skip activation as per the existing logic.
      // Crucially, we avoid calling setTokenAutoRefreshEnabled if not activated.
      debugPrint("🚀 App Check activation skipped in Debug Mode for stability.");
    }
  } catch (e) {
    debugPrint("⚠️ App Check could not be initialized: $e");
  }

  await initializeDateFormatting('tr');
  await _initServices();

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

Future<void> _initServices() async {
  try {
    await NotificationService.initialize();
  } catch (e, s) {
    debugPrint("Init services error: $e");
    debugPrintStack(stackTrace: s);
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: AppRouter.router,
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
      theme: AppTheme.lightTheme,
    );
  }
}
