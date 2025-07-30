import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';

//we going to build a naivgation bar usign the cursed navigation bar package
class Mainpage extends StatelessWidget {
  const Mainpage({super.key});

  @override
  Widget build(BuildContext context) {
    //we going to put the items in a list of icons
    final items = <Widget>[
      const Icon(Icons.home, size: 30),
      const Icon(Icons.search, size: 30),
      const Icon(Icons.settings, size: 30),
    ];
    return Scaffold(
      bottomNavigationBar: CurvedNavigationBar(
        height: 60,
        items: items),
    );
  }
}
