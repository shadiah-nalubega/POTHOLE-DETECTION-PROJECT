import 'dart:async';
import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:pothole/screens/notifications_page.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_tts/flutter_tts.dart';

// Main entry point: initializes Firebase and runs the app
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

// Root widget for the app
class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SearchScreen(),
    );
  }
}

// Main screen for pothole detection and route finding
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  GoogleMapController? mapController; // Controls Google Map
  Map<String, Marker> markers = {}; // Stores map markers
  final TextEditingController searchController =
      TextEditingController(); // For search input

  // List of pothole marker locations
  List<LatLng> potholeMarkers = [];
  bool showPotholes = true; // Toggle pothole visibility
  BitmapDescriptor? warningIcon; // Custom icon for pothole markers

  // ThingSpeak API details for fetching pothole data
  final String thingSpeakChannelId = "3003013";
  final String thingSpeakReadApiKey = "I7I05AI7PDG2GY6T";

  // Predefined gate for route selection
  final Map<String, LatLng> gateLocations = {
    'Main Gate': LatLng(0.3293245722418652, 32.57097846586401),
    'Western Gate': LatLng(0.33489802889405, 32.56393185237201),
    "Eestern gate": LatLng(0.33568994099457616, 32.5724612370186),
    'CoCIS': LatLng(0.3314728429581685, 32.570646523535906),
  };

  final Set<Polyline> _polylines = {}; // Stores route polylines
  String routeDistance = ''; // Route distance info
  String routeDuration = ''; // Route duration info

  late final Stream<int> unreadCountStream; // Stream for unread notifications

  String? selectedMarkerId; // Currently selected marker

  LatLng? currentLocation; // User's current location

  // For live location updates and pothole alerts
  StreamSubscription<Position>? _positionStream;
  final Set<String> _alertedPotholes = {}; // Tracks potholes already alerted

  final FlutterTts flutterTts = FlutterTts(); // Text-to-speech for alerts

  @override
  void initState() {
    super.initState();
    // Initialize TTS settings
    flutterTts.setLanguage("en-US");
    flutterTts.setPitch(1.0);
    flutterTts.setSpeechRate(0.5);
    _loadWarningIcon(); // Load custom warning icon
    _fetchThingSpeakPotholes(); // Fetch pothole data

    // Listen for unread notifications
    unreadCountStream = FirebaseFirestore.instance
        .collection('notifications')
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);

    // Get current location and start updates
    _determinePosition().then((pos) {
      if (pos != null) {
        setState(() {
          currentLocation = pos;
        });
        // Move map camera to current location
        if (mapController != null) {
          mapController!.animateCamera(CameraUpdate.newLatLngZoom(pos, 14));
          addMarker('Current Location', pos);
        }
        _startLocationUpdates();
      } else {
        // Fallback to Kampala if location unavailable
        currentLocation = const LatLng(0.3152, 32.5816);
        _startLocationUpdates();
      }
    });
  }

  @override
  void dispose() {
    _positionStream?.cancel(); // Stop location updates
    super.dispose();
  }

  // Start live location updates
  void _startLocationUpdates() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // meters
    );

    _positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) {
            final newLoc = LatLng(position.latitude, position.longitude);
            setState(() {
              currentLocation = newLoc;
              // Update current location marker
              addMarker('Current Location', newLoc);
            });
            _checkProximityToPotholes(newLoc); // Alert if near pothole
          },
        );
  }

  // Check if user is near any pothole and alert
  void _checkProximityToPotholes(LatLng userLoc) {
    const double alertThreshold = 20; // meters

    for (final pothole in potholeMarkers) {
      final id = 'pothole_${pothole.latitude}_${pothole.longitude}';
      final distance = _calculateDistance(userLoc, pothole);

      if (distance < alertThreshold && !_alertedPotholes.contains(id)) {
        _alertedPotholes.add(id);
        _showToast("⚠️ Approaching pothole!");
        Vibration.hasVibrator().then((hasVib) {
          if (hasVib ?? false) Vibration.vibrate(duration: 500);
        });
        flutterTts.speak("Warning! Pothole ahead.");
      } else if (distance >= alertThreshold && _alertedPotholes.contains(id)) {
        _alertedPotholes.remove(id);
      }
    }
  }

  // Get user's current location
  Future<LatLng?> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showToast("Location services are disabled.");
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showToast("Location permissions are denied");
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showToast("Location permissions are permanently denied.");
      return null;
    }

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    return LatLng(position.latitude, position.longitude);
  }

  // Load custom warning icon for pothole markers
  Future<void> _loadWarningIcon() async {
    warningIcon = await _bitmapDescriptorFromIconData(
      Icons.warning,
      color: Colors.red,
      size: 32,
    );
    setState(() {});
  }

  // Create BitmapDescriptor from IconData
  Future<BitmapDescriptor> _bitmapDescriptorFromIconData(
    IconData iconData, {
    Color color = Colors.red,
    double size = 32,
  }) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(iconData.codePoint),
      style: TextStyle(
        fontSize: size,
        fontFamily: iconData.fontFamily,
        color: color,
        package: iconData.fontPackage,
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset.zero);
    final image = await pictureRecorder.endRecording().toImage(
      size.toInt(),
      size.toInt(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  // Show a toast notification
  void _showToast(String msg) {
    Flushbar(
      message: msg, // ← use the parameter passed in
      icon: const Icon(Icons.warning, size: 28.0, color: Colors.yellow),
      duration: const Duration(seconds: 3),
      flushbarPosition: FlushbarPosition.BOTTOM,
      margin: const EdgeInsets.all(12),
      borderRadius: BorderRadius.circular(8),
      backgroundColor: Colors.black87,
    ).show(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pothole Route Finder"),
        actions: [
          // Notification icon with unread count badge
          StreamBuilder<int>(
            stream: unreadCountStream,
            builder: (context, snapshot) {
              final unreadNotifications = snapshot.data ?? 0;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificationsScreen(),
                        ),
                      );
                    },
                  ),
                  if (unreadNotifications > 0)
                    Positioned(
                      right: 11,
                      top: 11,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 14,
                          minHeight: 14,
                        ),
                        child: Text(
                          unreadNotifications.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Google Map widget
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: currentLocation ?? const LatLng(0.3152, 32.5816),
              zoom: 12.0,
            ),
            onMapCreated: (controller) {
              mapController = controller;
              if (currentLocation != null) {
                mapController!.animateCamera(
                  CameraUpdate.newLatLngZoom(currentLocation!, 14),
                );
                addMarker('Current Location', currentLocation!);
              }
            },
            markers: {
              ...markers.values.map((m) {
                if (m.markerId.value == selectedMarkerId) {
                  return m.copyWith(
                    iconParam: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueBlue,
                    ),
                  );
                }
                return m;
              }).toSet(),
              if (showPotholes)
                ...potholeMarkers.map(
                  (p) => Marker(
                    markerId: MarkerId('pothole_${p.latitude}_${p.longitude}'),
                    position: p,
                    icon:
                        warningIcon ??
                        BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueRed,
                        ),
                    infoWindow: const InfoWindow(title: "Pothole"),
                    onTap: () {
                      _onMarkerTap('pothole_${p.latitude}_${p.longitude}', p);
                    },
                  ),
                ),
            },
            polylines: _polylines,
            onTap: (pos) {
              setState(() {
                selectedMarkerId = null;
                _polylines.clear();
                routeDistance = '';
                routeDuration = '';
              });
            },
          ),
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: searchController,
                        decoration: const InputDecoration(
                          hintText: 'Search place...',
                          border: InputBorder.none,
                          prefixIcon: Icon(Icons.search),
                        ),
                        onSubmitted: (_) => _searchPlace(),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        showPotholes ? Icons.visibility_off : Icons.warning,
                        color: Colors.red,
                      ),
                      tooltip: showPotholes ? "Hide potholes" : "Show potholes",
                      onPressed: () =>
                          setState(() => showPotholes = !showPotholes),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (routeDistance.isNotEmpty && routeDuration.isNotEmpty)
            Positioned(
              bottom: 120,
              left: 16,
              right: 16,
              child: Card(
                color: Colors.white.withOpacity(0.9),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 6,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.timeline, color: Colors.green),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Distance: $routeDistance',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.timer, color: Colors.green),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Duration: $routeDuration',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 32),
        child: FloatingActionButton.extended(
          backgroundColor: Colors.red,
          icon: const Icon(Icons.alt_route),
          label: const Text("Select Route"),
          onPressed: () {
            _showRouteSelectionBottomSheet();
          },
        ),
      ),
    );
  }

  Future<void> _showRouteSelectionBottomSheet() async {
    String selectedGate = gateLocations.keys.first;

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.alt_route, color: Colors.red, size: 40),
                  const SizedBox(height: 12),
                  Text(
                    "Select Destination Gate",
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedGate,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: gateLocations.keys
                        .map(
                          (gate) =>
                              DropdownMenuItem(value: gate, child: Text(gate)),
                        )
                        .toList(),
                    onChanged: (val) =>
                        setModalState(() => selectedGate = val!),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.directions),
                    label: const Text("Show Route"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      final LatLng target = gateLocations[selectedGate]!;
                      _goToLocationAndDrawRoute(selectedGate, target);
                    },
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _goToLocationAndDrawRoute(String markerId, LatLng target) async {
    if (mapController == null) return;

    // Clear previous markers except current location and polylines before new route
    markers.removeWhere((key, _) => key != 'Current Location');
    _polylines.clear();

    mapController!.animateCamera(CameraUpdate.newLatLngZoom(target, 16));
    addMarker(markerId, target);
    setState(() => selectedMarkerId = markerId);

    if (currentLocation != null) {
      await _drawLeastPotholeRoute(currentLocation!, target);
    } else {
      _showToast("Current location unknown.");
    }
  }

  Future<void> _fetchThingSpeakPotholes() async {
    try {
      final url = Uri.parse(
        "https://api.thingspeak.com/channels/$thingSpeakChannelId/feeds.json?api_key=$thingSpeakReadApiKey&results=50",
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final feeds = data['feeds'];
        List<LatLng> points = [];
        for (var feed in feeds) {
          double? lat = double.tryParse(feed['field1'] ?? '');
          double? lng = double.tryParse(feed['field2'] ?? '');
          if (lat != null && lng != null) points.add(LatLng(lat, lng));
        }
        setState(() => potholeMarkers = points);
      }
    } catch (e) {
      _showToast("Error fetching pothole data.");
    }
  }

  Future<void> _searchPlace() async {
    final query = searchController.text.trim();
    if (query.isEmpty) {
      _showToast("Please enter a place name");
      return;
    }

    try {
      List<Location> locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        final location = locations.first;
        final target = LatLng(location.latitude, location.longitude);

        // Clear previous markers except current location and polylines before new route
        markers.removeWhere((key, _) => key != 'Current Location');
        _polylines.clear();

        mapController?.animateCamera(CameraUpdate.newLatLngZoom(target, 14));
        addMarker(query, target);
        setState(() {
          selectedMarkerId = query;
          routeDistance = '';
          routeDuration = '';
        });
        if (currentLocation != null) {
          await _drawLeastPotholeRoute(currentLocation!, target);
        } else {
          _showToast("Current location unknown.");
        }
      } else {
        throw Exception("No locations found");
      }
    } catch (e) {
      debugPrint('Geocoding error: $e');
      _showToast('Error finding location: $e');
    }
  }

  void addMarker(String markerId, LatLng location) {
    final marker = Marker(
      markerId: MarkerId(markerId),
      position: location,
      infoWindow: InfoWindow(
        title: markerId,
        snippet:
            '${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}',
      ),
      onTap: () {
        _onMarkerTap(markerId, location);
      },
    );
    markers[markerId] = marker;
    setState(() {});
  }

  void _onMarkerTap(String markerId, LatLng location) async {
    // Clear previous markers except current location and polylines
    markers.removeWhere((key, _) => key != 'Current Location');
    _polylines.clear();

    setState(() {
      selectedMarkerId = markerId;
      routeDistance = '';
      routeDuration = '';
    });
    mapController?.animateCamera(CameraUpdate.newLatLngZoom(location, 16));
    addMarker(markerId, location);
    if (currentLocation != null) {
      await _drawLeastPotholeRoute(currentLocation!, location);
    } else {
      _showToast("Current location unknown.");
    }
  }

  Future<void> _drawLeastPotholeRoute(LatLng start, LatLng end) async {
    await _drawRoute(start, end);

    if (_polylines.isNotEmpty) {
      final routePoints = _polylines.first.points;
      int potholeCount = _countPotholesAlongRoute(routePoints);

      // Show the count in the route info card
      setState(() {
        // Fix: Only append pothole count if routeDistance is not empty and doesn't already contain pothole info
        if (routeDistance.isNotEmpty && !routeDistance.contains('pothole')) {
          routeDistance = '$routeDistance • $potholeCount potholes';
        }
      });

      // Also show a toast notification
      _showToast("⚠️ Route has $potholeCount potholes");
    }
  }

  int _countPotholesAlongRoute(List<LatLng> routePoints) {
    int count = 0;

    for (final pothole in potholeMarkers) {
      if (_isPotholeNearRoute(pothole, routePoints, 20)) {
        // 20 meters threshold
        count++;
      }
    }
    return count;
  }

  bool _isPotholeNearRoute(
    LatLng pothole,
    List<LatLng> routePoints,
    double thresholdMeters,
  ) {
    // Check distance to each segment of the route
    for (int i = 0; i < routePoints.length - 1; i++) {
      final distance = _distanceToSegmentMeters(
        pothole,
        routePoints[i],
        routePoints[i + 1],
      );
      if (distance < thresholdMeters) {
        return true;
      }
    }
    return false;
  }

  double _distanceToSegmentMeters(
    LatLng point,
    LatLng segmentStart,
    LatLng segmentEnd,
  ) {
    // Convert LatLng to cartesian coordinates (meters)
    const double earthRadius = 6371000; // meters

    double lat1 = segmentStart.latitude * math.pi / 180;
    double lng1 = segmentStart.longitude * math.pi / 180;
    double lat2 = segmentEnd.latitude * math.pi / 180;
    double lng2 = segmentEnd.longitude * math.pi / 180;
    double lat0 = point.latitude * math.pi / 180;
    double lng0 = point.longitude * math.pi / 180;

    // Convert to 3D cartesian coordinates
    List<double> toXYZ(double lat, double lng) {
      return [
        earthRadius * math.cos(lat) * math.cos(lng),
        earthRadius * math.cos(lat) * math.sin(lng),
        earthRadius * math.sin(lat),
      ];
    }

    final p1 = toXYZ(lat1, lng1);
    final p2 = toXYZ(lat2, lng2);
    final p0 = toXYZ(lat0, lng0);

    // Vector from p1 to p2
    final dx = p2[0] - p1[0];
    final dy = p2[1] - p1[1];
    final dz = p2[2] - p1[2];

    // Vector from p1 to p0
    final px = p0[0] - p1[0];
    final py = p0[1] - p1[1];
    final pz = p0[2] - p1[2];

    // Dot product and segment length squared
    final dot = dx * px + dy * py + dz * pz;
    final len2 = dx * dx + dy * dy + dz * dz;

    double param = -1;
    if (len2 != 0) {
      param = dot / len2;
    }

    List<double> closest;
    if (param < 0) {
      closest = p1;
    } else if (param > 1) {
      closest = p2;
    } else {
      closest = [p1[0] + param * dx, p1[1] + param * dy, p1[2] + param * dz];
    }

    // Euclidean distance between point and closest point on segment
    final dist = math.sqrt(
      math.pow(p0[0] - closest[0], 2) +
          math.pow(p0[1] - closest[1], 2) +
          math.pow(p0[2] - closest[2], 2),
    );
    return dist;
  }

  Future<void> _drawRoute(LatLng start, LatLng end) async {
    final url = Uri.parse(
      "https://maps.googleapis.com/maps/api/directions/json?origin=${start.latitude},${start.longitude}&destination=${end.latitude},${end.longitude}&key=AIzaSyBgIN4DNxvEBKmA0ZtErW_mJxYC8_fYCfk",
    );
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if ((data["routes"] as List).isEmpty) {
        _showToast("No route found.");
        return;
      }
      final route = data["routes"][0];
      final points = route["overview_polyline"]["points"];
      final legs = route["legs"][0];

      final polylinePoints = _decodePolyline(points);

      setState(() {
        _polylines.clear();
        // Border polyline (thicker black)
        _polylines.add(
          Polyline(
            polylineId: const PolylineId("route_border"),
            points: polylinePoints,
            width: 4,
            color: Colors.black,
          ),
        );
        // Foreground polyline (slightly thinner bright green)
        _polylines.add(
          Polyline(
            polylineId: const PolylineId("route"),
            points: polylinePoints,
            width: 6,
            color: Colors.greenAccent.shade400,
          ),
        );
        routeDistance = legs['distance']['text'];
        routeDuration = legs['duration']['text'];
      });
    } else {
      _showToast("Failed to get route.");
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> poly = [];
    int index = 0, len = encoded.length, lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      poly.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return poly;
  }

  double _calculateDistance(LatLng a, LatLng b) {
    const double earthRadius = 6371000; // meters
    final lat1 = a.latitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLng = (b.longitude - a.longitude) * math.pi / 180;

    final hav =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);

    final c = 2 * math.atan2(math.sqrt(hav), math.sqrt(1 - hav));
    return earthRadius * c; // returns distance in meters
  }
}
