import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

// Core
import 'core/firebase_options.dart';
import 'core/app_colors.dart';

// Views - Auth
import 'views/auth/firebase_load_check_screen.dart';
import 'views/auth/simple_preload_screen.dart';
import 'views/auth/start_page.dart';
import 'views/auth/login_screen.dart';
import 'views/auth/signup_screen.dart';
import 'views/auth/forgot_password_screen.dart';

// Views - Dashboard
import 'views/dashboard/dashboard_wrapper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables (.env)
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Note: .env file not loaded ($e), falling back to defaults.");
  }

  // Timezone setup
  tz_data.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Colombo'));

  // Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Eduwide App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.lightBackground,
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
      routes: {
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignUpPage(),
        '/forgot-password': (context) => const ForgotPasswordPage(),
        '/dashboard': (context) => const DashboardWrapper(),
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const FirebaseLoadCheckScreen();
        }

        // User is logged in → go to preload (then dashboard)
        if (snapshot.hasData && snapshot.data != null) {
          return const SimplePreloadScreen();
        }

        // No user → show start page (login/signup)
        return const StartPage();
      },
    );
  }
}
