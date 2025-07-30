import 'package:flutter/material.dart';
import 'package:pothole/screens/edit_profile_page.dart';
import 'package:pothole/screens/gradestat.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'package:pothole/firebase_options.dart';
import 'package:pothole/getstarted.dart';
import 'package:pothole/screens/auth/login_page.dart';
import 'package:pothole/screens/auth/sign_page.dart';
import 'package:pothole/screens/navigation.dart';
import 'package:pothole/screens/reportpothole.dart';
import 'package:pothole/screens/settingspage.dart';
import 'package:pothole/screens/homepage.dart';
import 'package:pothole/screens/search_screen.dart';
import 'package:pothole/ui/avatar_provider.dart';
import 'package:pothole/theme_provider.dart';
import 'package:flutter/services.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Optionally initialize TTS here
  final FlutterTts flutterTts = FlutterTts();
  await flutterTts.setLanguage("en-US");
  await flutterTts.setPitch(1.0);
  await flutterTts.setSpeechRate(0.5);

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  // Activate Firebase App Check
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.playIntegrity,
    appleProvider: AppleProvider.deviceCheck,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AvatarProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return MaterialApp(
          title: 'Pothole App',
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: themeProvider.isDarkMode
              ? ThemeMode.dark
              : ThemeMode.light,
          debugShowCheckedModeBanner: false,
          initialRoute: '/',
          routes: {
            '/': (context) => const GetStarted(),
            '/reportpothole': (context) => const ReportPotholePage(),
            '/settings': (context) => const SettingsPage(),
            '/login': (context) => const LoginPage(),
            '/home': (context) => const Navigation(),
            '/homepage': (context) => const HomeScreen(),
            '/signup': (context) => const SignPage(),
            '/map': (context) => SearchScreen(),
            "/stat": (context) => StatsPage(),
            "/edit": (context) => EditProfilePage(),
          },
        );
      },
    );
  }
}
