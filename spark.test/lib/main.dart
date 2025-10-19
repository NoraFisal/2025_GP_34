import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';

// Pages
import 'login.dart';
import 'signup.dart';
import 'organizer_profile.dart';
import 'view_organizer_profile.dart';
import 'organizer_management.dart';
import 'player_profile_page.dart';
import 'player_profile_edit_page.dart';
import 'view_player_profile_page.dart';
import 'start.dart';
import 'homepage.dart';
import 'a.dart';
import 'forgotPassword.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Minimal Firebase init for Web / Mobile
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyDiHp6IZ1bCkm251TZgxWzK2kUOjQZ9_IQ",
        authDomain: "spark-6c004.firebaseapp.com",
        projectId: "spark-6c004",
        storageBucket: "spark-6c004.firebasestorage.app",
        messagingSenderId: "15267728081",
        appId: "1:15267728081:web:7c632ec48527966d8bd3f0",
        measurementId: "G-LEK7C8XD8V",
      ),
    );
  } else {
    await Firebase.initializeApp();
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SPARK',
      theme: ThemeData(useMaterial3: true),
      initialRoute: '/homepage', // يمكن تغييره لتغيير الصفحة الرئيسية
      routes: {
        // Start / Landing
        '/': (context) => const StartPage(), // أو StartPage() حسب اختيارك

        // Authentication
        '/login': (context) => const LoginPage(),
        '/forgotPassword': (context) => ForgotPasswordPage(),
        '/signup': (context) => const SignupPage(),
        '/a': (context) => const APage(),

        // Organizer
        '/organizerProfile': (context) => const OrganizerProfilePage(),
        '/organizerManagement': (context) => const OrganizerManagementPage(),
        '/viewOrganizerProfile': (context) =>
            ViewOrganizerProfilePage(organizerId: 'xtTXMnGpxp8jxIK9I5AE'),

        // Player
        '/playerProfile': (context) => const PlayerProfilePage(),
        '/playerEdit': (context) => const PlayerProfileEditPage(),
        '/viewPlayerProfile': (context) =>
            const ViewPlayerProfilePage(userId: 'replace_with_id'),

        // Homepage
        '/homepage': (context) => const HomePage(),
      },
    );
  }
}
