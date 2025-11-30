import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';

// Pages
import '../pages/auth/login_page.dart';
import '../pages/auth/signup_page.dart';
import '../pages/organizer/organizer_profile_page.dart';
import '../pages/organizer/organizer_profile_view_page.dart';
import '../pages/organizer/organizer_management_page.dart';
import '../pages/player/player_profile_page.dart';
import '../pages/player/player_profile_edit_page.dart';
import '../pages/player/player_profile_view_page.dart';
import '../pages/start_page.dart';
import '../pages/home_page.dart';
import '../pages/organizer/organizer_home_page.dart';
import '../pages/auth/email_verification_page.dart';
import '../pages/auth/forgot_password_page.dart';
import '../pages/contact_us_page.dart';
import '../pages/chat/chat_list_page.dart';
import '../pages/player/connect_game_page.dart';
import '../pages/chat/chat_page.dart';
import '../pages/chat/team_chat_page.dart';
import '../pages/team/edit_team_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
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

      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: "AIzaSyDiHp6IZ1bCkm251TZgxWzK2kUOjQZ9_IQ",
          authDomain: "spark-6c004.firebaseapp.com",
          projectId: "spark-6c004",
          storageBucket: "spark-6c004.firebasestorage.app",
          messagingSenderId: "15267728081",
          appId: "1:15267728081:android:278ea75ca80fce1e8bd3f0", 
        ),
      );
    }
    print('✅ Firebase initialized successfully');
  } catch (e) {
    print('⚠️ Firebase initialization error: $e');
    print('Continuing without Firebase...');
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
      initialRoute: '/',
      routes: {
        // Start / Landing
        '/': (context) => const StartPage(), 

        // Authentication
        '/login': (context) => const LoginPage(),
        '/forgotPassword': (context) => ForgotPasswordPage(),
        '/signup': (context) => const SignupPage(),
        '/a': (context) => const APage(),

        // Organizer
        '/organizerHome': (_) => const organizerHomePage(),
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
        '/contactuspage': (context) => const ContactUsPage(),
        '/connect-game': (context) => const ConnectGamePage(),

        //chat
        '/chatList': (context) => const ChatListPage(),
         '/chat': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map;
          return Chat(
            chatId: args['chatId'],
            currentUserId: args['currentUserId'],
            otherUserId: args['receiverId'],
            otherUserName: args['otherUserName'] ?? 'Player',
            otherUserImage: args['otherUserImage'],
          );
        },
        '/teamChat': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map;
          return TeamChatPage(
            teamId: args['teamId'],
            teamName: args['teamName'],
          );
        },

        '/editTeam': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map;
          return EditTeamPage(teamId: args['teamId']);
        },
      },
    );
  }
}