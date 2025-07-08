import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  LatLng? currentLocation;
  LatLng? destination;
  List<LatLng> routePoints = [];
  double? distanceKm;
  String? locationError;
  bool isLoadingRoute = false;
  bool showPotholes = false;

  final String orsApiKey =
      'eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6ImY5ZmRlMzA0MGQxOTQ5Nzg5ZmVmNDk2NjQzODI1ZmExIiwiaCI6Im11cm11cjY0In0= '; // <-- Replace with your real key

  //get the api key from openrouteservice.org
  // You can get your own API key from https://openrouteservice.org/sign-up/
  // Make sure to replace the key below
  // You can get your own API key from https://thingspeak.com/
  // Make sure to replace the key below
  final String thingSpeakUrl =
      'https://api.thingspeak.com/channels/3004931/feeds.json?api_key=HCX3A9AOSBAKYPXG&results=100'; // <-- Replace with your channel ID and read key
  //replace with your real channel ID AND read key
  // You can get your own API key from https://thingspeak.com/
  //and replace the key below

  final Map<String, LatLng> destinations = {
    'Kireka': LatLng(0.3333, 32.6650),
    'Banda': LatLng(0.3300, 32.6000),
    'Nakawa': LatLng(0.3200, 32.6200),
    'Wandegeya': LatLng(0.3379, 32.5714),
    'Makerere Main Gate': LatLng(0.3370, 32.5725),
  };

  List<LatLng> potholeLocations = [];

  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    fetchPotholesFromThingSpeak(); // <-- Fetch potholes from ThingSpeak
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((Position position) {
      setState(() {
        currentLocation = LatLng(position.latitude, position.longitude);
      });
    });
  }

  //fetch potholes from thingspeak api

  Future<void> fetchPotholesFromThingSpeak() async {
    final response = await http.get(Uri.parse(thingSpeakUrl));
    print('ThingSpeak response: ${response.body}'); // Debug print

    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body);
      final feeds = jsonData['feeds'];

      final List<LatLng> loaded = [];
      for (var feed in feeds) {
        final lat = double.tryParse(feed['field1'] ?? '');
        final lon = double.tryParse(feed['field2'] ?? '');
        if (lat != null && lon != null) {
          loaded.add(LatLng(lat, lon));
        }
      }

      setState(() {
        potholeLocations = loaded;
      });
    } else {
      print('Failed to fetch potholes: ${response.statusCode}');
    }
  }

  Future<void> _getCurrentLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      setState(() {
        locationError = 'Location permissions are permanently denied.';
      });
      return;
    }
    if (permission == LocationPermission.denied) {
      setState(() {
        locationError = 'Location permissions are denied.';
      });
      return;
    }
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        currentLocation = LatLng(position.latitude, position.longitude);
        locationError = null;
      });
    } catch (e) {
      setState(() {
        locationError = 'Failed to get current location.';
      });
    }
  }

  Future<List<LatLng>> fetchRoute(LatLng start, LatLng end) async {
    final url =
        'https://api.openrouteservice.org/v2/directions/driving-car?api_key=$orsApiKey&start=${start.longitude},${start.latitude}&end=${end.longitude},${end.latitude}';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final coords = data['features'][0]['geometry']['coordinates'] as List;
      // Coordinates come as [longitude, latitude], convert to LatLng
      return coords
          .map((point) => LatLng(point[1] as double, point[0] as double))
          .toList();
    } else {
      throw Exception('Failed to fetch route: ${response.statusCode}');
    }
  }

  void _onDestinationSelected(String? selected) async {
    if (selected == null) return;
    if (currentLocation == null) return;

    LatLng destLatLng = destinations[selected]!;

    setState(() {
      isLoadingRoute = true;
      destination = destLatLng;
      routePoints = [];
      distanceKm = null;
    });

    try {
      final points = await fetchRoute(currentLocation!, destLatLng);
      final distance = Distance().as(
        LengthUnit.Kilometer,
        currentLocation!,
        destLatLng,
      );

      setState(() {
        routePoints = points;
        distanceKm = distance;
      });
    } catch (e) {
      String errorMsg = 'Error fetching route: $e';
      if (e.toString().contains('503')) {
        errorMsg =
            'Route service temporarily unavailable (503). Please try again later.';
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMsg)));
    } finally {
      setState(() {
        isLoadingRoute = false;
      });
    }
  }

  // Returns potholes within 50 meters of any route point
  List<LatLng> _potholesAlongRoute() {
    if (routePoints.isEmpty) return [];
    const double thresholdMeters = 50;
    final distance = Distance();
    return potholeLocations.where((pothole) {
      return routePoints.any(
        (routePoint) => distance(pothole, routePoint) < thresholdMeters,
      );
    }).toList();
  }

  String? _nearbyPotholeWarning() {
    if (currentLocation == null || routePoints.isEmpty) return null;
    const double warningThreshold = 45; // meters
    final distance = Distance();
    for (final pothole in _potholesAlongRoute()) {
      if (distance(currentLocation!, pothole) < warningThreshold) {
        return "Warning: Pothole ahead in less than 45 meters!";
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final warning = _nearbyPotholeWarning();

    if (locationError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pothole Detection')),
        body: Center(child: Text(locationError!)),
        bottomNavigationBar: _buildBottomNavBar(),
        floatingActionButton: _buildFAB(context),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Pothole Detection')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  // Card 1: Location & Destination
                  Expanded(
                    flex: 3,
                    child: Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.my_location,
                                  color: Colors.blue,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    currentLocation == null
                                        ? 'Locating...'
                                        : 'Current: ${currentLocation!.latitude.toStringAsFixed(4)}, ${currentLocation!.longitude.toStringAsFixed(4)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_pin,
                                  color: Colors.red,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: DropdownButton<String>(
                                    value: destination == null
                                        ? null
                                        : destinations.entries
                                              .firstWhere(
                                                (e) => e.value == destination,
                                              )
                                              .key,
                                    hint: const Text('Select Destination'),
                                    isExpanded: true,
                                    items: destinations.keys
                                        .map(
                                          (dest) => DropdownMenuItem(
                                            value: dest,
                                            child: Text(dest),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: isLoadingRoute
                                        ? null
                                        : _onDestinationSelected,
                                  ),
                                ),
                              ],
                            ),
                            if (distanceKm != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  'Distance: ${distanceKm!.toStringAsFixed(2)} km',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Card 2: Show Potholes Button
                  Expanded(
                    flex: 2,
                    child: Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          setState(() {
                            showPotholes = !showPotholes;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 24.0,
                            horizontal: 8,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: showPotholes
                                    ? Colors.orange
                                    : Colors.grey,
                                size: 32,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                showPotholes
                                    ? 'Hide Potholes'
                                    : 'Show Potholes',
                                style: TextStyle(
                                  color: showPotholes
                                      ? Colors.orange
                                      : Colors.black87,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (isLoadingRoute)
              const Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(),
              ),
            // Warning for nearby potholes
            if (warning != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Material(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.warning, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          warning,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            // Map
            Expanded(
              child: currentLocation == null
                  ? const Center(child: CircularProgressIndicator())
                  : FlutterMap(
                      options: MapOptions(
                        initialCenter: currentLocation!,
                        initialZoom: 14,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                          subdomains: ['a', 'b', 'c'],
                          userAgentPackageName: 'com.example.potholeapp',
                          retinaMode: true, // Enable retina mode
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: currentLocation!,
                              width: 40,
                              height: 40,
                              child: const Icon(
                                Icons.my_location,
                                color: Colors.blue,
                                size: 40,
                              ),
                            ),
                            if (destination != null)
                              Marker(
                                point: destination!,
                                width: 40,
                                height: 40,
                                child: const Icon(
                                  Icons.location_pin,
                                  color: Colors.red,
                                  size: 40,
                                ),
                              ),
                            // Pothole markers
                            if (showPotholes)
                              ...(routePoints.isNotEmpty
                                      ? _potholesAlongRoute()
                                      : potholeLocations)
                                  .map(
                                    (p) => Marker(
                                      point: p,
                                      width: 30,
                                      height: 30,
                                      child: const Icon(
                                        Icons.warning_amber_rounded,
                                        color: Colors.orange,
                                        size: 30,
                                      ),
                                    ),
                                  ),
                          ],
                        ),
                        if (routePoints.isNotEmpty)
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: routePoints,
                                strokeWidth: 6,
                                color: Colors.black.withOpacity(0.3), // shadow
                              ),
                              Polyline(
                                points: routePoints,
                                strokeWidth: 4,
                                color: Colors.green,
                              ),
                            ],
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
      floatingActionButton: _buildFAB(context),
    );
  }

  Widget _buildFAB(BuildContext context) {
    return FloatingActionButton.extended(
      icon: const Icon(Icons.route),
      label: const Text('Best Routes'),
      onPressed: () {
        showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          builder: (context) => _buildBestRoutesSheet(),
        );
      },
    );
  }

  Widget _buildBestRoutesSheet() {
    // For demo, show the destinations list. Replace with your best routes logic.
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Best Routes Nearby',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...destinations.entries.map(
            (entry) => ListTile(
              leading: const Icon(Icons.location_on),
              title: Text(entry.key),
              onTap: () {
                Navigator.pop(context);
                _onDestinationSelected(entry.key);
              },
            ),
          ),
        ],
      ),
    );
  }

  BottomNavigationBar _buildBottomNavBar() {
    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      onTap: (index) {
        setState(() {
          _selectedIndex = index;
        });
        if (index == 1) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('About This App'),
              content: const Text(
                'Pothole Detection App\n\n'
                'This app helps you detect potholes and find the best routes to avoid them.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
        }
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.info), label: 'About'),
      ],
    );
  }
}


//so far its well bt i need to get the dectection of potholes from the api and display them on the map
// and also the best routes to avoid them
// and also the distance from the current location to the destination
// and also the distance from the current location to the potholes
//so lets implement the fetching of potholes from the API and displaying them on the map
// and also the best routes to avoid them
// and also the distance from the current location to the destination

