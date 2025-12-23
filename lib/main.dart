import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lojistik/app.dart';
import 'package:lojistik/core/di/service_locator.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await setupDependencies();

  if (!kIsWeb) {
    await FirebaseAppCheck.instance.activate(androidProvider: AndroidProvider.debug);
    await FlutterDownloader.initialize(debug: true, ignoreSsl: true);
  }

  runApp(const ProviderScope(child: App()));
}
