import 'package:flutter/material.dart';
import 'package:pothole1/pages/getstarted.dart';
import 'package:pothole1/pages/homepage.dart';

void main() {
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
        "/":(context)=> const Getstarted(),
        "/home":(context)=> const Homepage(),
        
      },
    );
  }
}