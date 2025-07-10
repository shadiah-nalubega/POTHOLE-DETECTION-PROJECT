import 'package:flutter/material.dart';
import 'package:pothole1/auth/login_page.dart';
import 'package:pothole1/auth/sign_page.dart';
import 'package:pothole1/pages/getstarted.dart';
import 'package:pothole1/pages/homepage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pot Hole Detection',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      initialRoute: "/",
      routes: {
        "/":(context)=> const GetStarted(),
        "/home":(context)=> const Homepage(),
        "/login":(context)=> const LoginPage(),
        "/signup":(context)=> const SignPage(),
        
      },
    );
  }
}
  // final String orsApiKey =
  //     'eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6ImY5ZmRlMzA0MGQxOTQ5Nzg5ZmVmNDk2NjQzODI1ZmExIiwiaCI6Im11cm11cjY0In0=';
  // final String thingSpeakUrl =
  //     'https://api.thingspeak.com/channels/3004931/feeds.json?api_key=HCX3A9AOSBAKYPXG&results=100';