import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:pothole/screens/gradestat.dart';
import 'homepage.dart';
import 'settingspage.dart';

class Navigation extends StatefulWidget {
  const Navigation({super.key});

  @override
  State<Navigation> createState() => _NavigationState();
}

class _NavigationState extends State<Navigation> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [HomeScreen(), StatsPage(), SettingsPage()];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final items = <Widget>[
      Icon(Icons.home, size: 30, color: isDark ? Colors.white : Colors.black),
      Icon(Icons.search, size: 30, color: isDark ? Colors.white : Colors.black),
      Icon(
        Icons.settings,
        size: 30,
        color: isDark ? Colors.white : Colors.black,
      ),
    ];

    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: CurvedNavigationBar(
        height: 60,
        color: isDark ? Colors.grey[850]! : Colors.white,
        backgroundColor: Colors.transparent,
        items: items,
        index: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }
}
