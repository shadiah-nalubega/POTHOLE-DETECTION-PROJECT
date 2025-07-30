import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:pothole/screens/edit_profile_page.dart';
import 'package:provider/provider.dart';
import 'package:pothole/theme_provider.dart';
import 'package:pothole/screens/notifications_page.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:location/location.dart' as loc; // For device GPS location
import 'package:geocoding/geocoding.dart'
    as geo; // For reverse geocoding placemarks

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  int _notificationCount = 0;
  String _userName = 'User';
  String? _profilePicUrl;

  String _locationText = 'Loading location...';

  late final User? currentUser;

  @override
  void initState() {
    super.initState();
    currentUser = _auth.currentUser;
    _fetchUserData();
    _listenNotificationCount();
    _fetchCurrentLocation();
  }

  Future<void> _fetchUserData() async {
    if (currentUser != null) {
      final userDoc = await _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
        setState(() {
          _userName = (data['username'] as String?) ?? _userName;
          _profilePicUrl = (data['avatarUrl'] as String?) ?? _profilePicUrl;
        });
      }
    }
  }

  void _listenNotificationCount() {
    if (currentUser != null) {
      _firestore
          .collection('notifications')
          .where('read', isEqualTo: false)
          .snapshots()
          .listen((snapshot) {
            setState(() {
              _notificationCount = snapshot.docs.length;
            });
          });
    }
  }

  Future<void> _fetchCurrentLocation() async {
    loc.Location location = loc.Location();

    bool _serviceEnabled;
    loc.PermissionStatus _permissionGranted;
    loc.LocationData _locationData;

    _serviceEnabled = await location.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await location.requestService();
      if (!_serviceEnabled) {
        setState(() {
          _locationText = 'Location service disabled';
        });
        return;
      }
    }

    _permissionGranted = await location.hasPermission();
    if (_permissionGranted == loc.PermissionStatus.denied) {
      _permissionGranted = await location.requestPermission();
      if (_permissionGranted != loc.PermissionStatus.granted) {
        setState(() {
          _locationText = 'Location permission denied';
        });
        return;
      }
    }

    _locationData = await location.getLocation();

    try {
      List<geo.Placemark> placemarks = await geo.placemarkFromCoordinates(
        _locationData.latitude!,
        _locationData.longitude!,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        setState(() {
          _locationText =
              '${place.locality ?? place.subAdministrativeArea ?? 'Unknown'}, ${place.country ?? ''} – ⚠️ Moderate potholes nearby';
        });
      } else {
        setState(() {
          _locationText = 'Unknown location – ⚠️ Moderate potholes nearby';
        });
      }
    } catch (e) {
      setState(() {
        _locationText = 'Error fetching location – ⚠️ Moderate potholes nearby';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.grey[100],
      appBar: AppBar(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        elevation: 0.5,
        title: Text(
          "Pothole Detection",
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          NotificationIconWithBadge(
            count: _notificationCount,
            isDark: isDark,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              );
            },
          ),
          IconButton(
            icon: _profilePicUrl != null
                ? CircleAvatar(
                    backgroundImage: NetworkImage(_profilePicUrl!),
                    radius: 16,
                  )
                : Icon(
                    LucideIcons.userCircle2,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EditProfilePage()),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          const SizedBox(height: 20),
          WelcomeWidget(
            userName: _userName,
            isDark: isDark,
            profilePicUrl: _profilePicUrl,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(LucideIcons.mapPin, size: 18, color: Colors.redAccent),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _locationText,
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.grey[700],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            height: 180,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [Colors.teal[700]!, Colors.tealAccent]
                    : [Colors.indigo, Colors.deepPurpleAccent],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.tealAccent.withOpacity(0.3)
                      : Colors.indigo.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "🚗 Stay Alert!",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "Live pothole alerts on your route",
                        style: TextStyle(color: Colors.white70),
                      ),
                      const Spacer(),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.indigo,
                        ),
                        onPressed: () {
                          Navigator.pushNamed(context, "/map");
                        },
                        child: const Text("View Map"),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Lottie.asset("images/animations/drive.json"),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.1,
            children: [
              _AnimatedActionCard(
                label: "Report pothole",
                icon: LucideIcons.alertTriangle,
                color: Colors.redAccent,
                route: "/reportpothole",
              ),
              _AnimatedActionCard(
                label: "Statistics",
                icon: LucideIcons.barChart3,
                color: Colors.deepPurple,
                route: "/stat",
              ),
              _AnimatedActionCard(
                label: "Settings",
                icon: LucideIcons.settings,
                color: Colors.blueGrey,
                route: "/settings",
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class WelcomeWidget extends StatelessWidget {
  final String userName;
  final bool isDark;
  final String? profilePicUrl;

  const WelcomeWidget({
    Key? key,
    required this.userName,
    required this.isDark,
    this.profilePicUrl,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Lottie.asset(
              "images/animations/WavingHand.json",
              height: 40,
              width: 40,
              animate: true,
            ),
            const SizedBox(height: 4),
            Text(
              "Welcome back, $userName",
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AnimatedActionCard extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final String route;

  const _AnimatedActionCard({
    Key? key,
    required this.label,
    required this.icon,
    required this.color,
    required this.route,
  }) : super(key: key);

  @override
  State<_AnimatedActionCard> createState() => _AnimatedActionCardState();
}

class _AnimatedActionCardState extends State<_AnimatedActionCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.95,
      upperBound: 1.0,
    );
    _scaleAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) => _controller.reverse();
  void _onTapUp(TapUpDetails _) {
    _controller.forward();
    Navigator.of(context).pushNamed(widget.route);
  }

  void _onTapCancel() => _controller.forward();

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return ScaleTransition(
      scale: _scaleAnim,
      child: Card(
        color: isDark ? Colors.grey[900] : Colors.white,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: _onTapDown,
          onTapUp: _onTapUp,
          onTapCancel: _onTapCancel,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, size: 38, color: widget.color),
                const SizedBox(height: 14),
                Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class NotificationIconWithBadge extends StatelessWidget {
  final int count;
  final bool isDark;
  final VoidCallback onTap;

  const NotificationIconWithBadge({
    Key? key,
    required this.count,
    required this.isDark,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: Icon(
            LucideIcons.bell,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
          onPressed: onTap,
        ),
        if (count > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? Colors.black : Colors.white,
                  width: 1.5,
                ),
              ),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Center(
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
