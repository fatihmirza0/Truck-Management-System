import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/dispatchScreens/dispatch_main_screen.dart';
import 'screens/managerScreens/manager_screen.dart';
import 'screens/driver_screen.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Truck',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blueGrey),
      initialRoute: '/',
      routes: {
        '/': (context) => LoginScreen(),
        '/manager': (context) => ManagerScreen(),
        '/dispatch': (context) => DispatchMainScreen(),
        '/driver': (context) => const DriverScreen(driverId: "driver1"),
      },
    );
  }
}
