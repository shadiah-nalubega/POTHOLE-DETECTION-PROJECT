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
  int _selectedIndex = 0;

  final String orsApiKey = 'your_api_key_here';
  final String thingSpeakUrl =
      'https://api.thingspeak.com/channels/3004931/feeds.json?api_key=your_api_key_here&results=100';

  final Map<String, LatLng> destinations = {
    'Kireka': LatLng(0.3333, 32.6650),
    'Banda': LatLng(0.3300, 32.6000),
    'Nakawa': LatLng(0.3200, 32.6200),
    'Wandegeya': LatLng(0.3379, 32.5714),
    'Makerere Main Gate': LatLng(0.3370, 32.5725),
  };

  List<LatLng> potholeLocations = [];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    fetchPotholesFromThingSpeak();
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

  Future<void> fetchPotholesFromThingSpeak() async {
    try {
      final response = await http.get(Uri.parse(thingSpeakUrl));
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final feeds = jsonData['feeds'] as List<dynamic>;
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
        throw Exception('Failed to fetch potholes: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching potholes: $e');
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        setState(() {
          locationError = 'Location permissions are denied.';
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        currentLocation = LatLng(position.latitude, position.longitude);
        locationError = null;
      });
    } catch (e) {
      setState(() {
        locationError = 'Failed to get current location: $e';
      });
    }
  }

  Future<List<LatLng>> fetchRoute(LatLng start, LatLng end) async {
    final url =
        'https://api.openrouteservice.org/v2/directions/driving-car?api_key=$orsApiKey&start=${start.longitude},${start.latitude}&end=${end.longitude},${end.latitude}';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final coords = data['features'][0]['geometry']['coordinates'] as List;
        return coords
            .map((point) => LatLng(point[1] as double, point[0] as double))
            .toList();
      } else {
        throw Exception('Failed to fetch route: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching route: $e');
    }
  }

  void _onDestinationSelected(String? selected) async {
    if (selected == null || currentLocation == null) return;
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
      final errorMsg = e.toString().contains('503')
          ? 'Route service temporarily unavailable. Try later.'
          : 'Error fetching route: $e';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg)),
      );
    } finally {
      setState(() {
        isLoadingRoute = false;
      });
    }
  }

  List<LatLng> _potholesAlongRoute() {
    if (routePoints.isEmpty) return [];
    const thresholdMeters = 50;
    final distance = Distance();

    return potholeLocations.where((pothole) {
      return routePoints.any((routePoint) =>
          distance(pothole, routePoint) < thresholdMeters);
    }).toList();
  }

  String? _nearbyPotholeWarning() {
    if (currentLocation == null || routePoints.isEmpty) return null;
    const warningThreshold = 45;
    final distance = Distance();

    for (final pothole in _potholesAlongRoute()) {
      if (distance(currentLocation!, pothole) < warningThreshold) {
        return "⚠️ Warning: Pothole ahead within 45 meters!";
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
      appBar: AppBar(
        title: const Text('Pothole Detection'),
        centerTitle: true,
        elevation: 2,
        backgroundColor: Colors.green.shade700,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 4,
                      color: Colors.white,
                      shadowColor: Colors.black26,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLocationRow(),
                            const SizedBox(height: 16),
                            _buildDestinationDropdown(),
                            if (distanceKm != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                'Distance: ${distanceKm!.toStringAsFixed(2)} km',
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 4,
                      color: Colors.white,
                      shadowColor: Colors.black26,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          setState(() {
                            showPotholes = !showPotholes;
                          });
                        },
                        splashColor: Colors.orange.withOpacity(0.3),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 28.0, horizontal: 12),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                showPotholes
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                size: 36,
                                color: showPotholes
                                    ? Colors.deepOrange
                                    : Colors.grey.shade600,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                showPotholes
                                    ? 'Hide Potholes'
                                    : 'Show Potholes',
                                style: TextStyle(
                                  color: showPotholes
                                      ? Colors.deepOrange
                                      : Colors.grey.shade800,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
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
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: LinearProgressIndicator(
                  color: Colors.green,
                  minHeight: 4,
                ),
              ),
            if (warning != null)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Material(
                  color: Colors.red.shade700,
                  borderRadius: BorderRadius.circular(12),
                  elevation: 3,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12.0, horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            color: Colors.white),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            warning,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Expanded(
              child: currentLocation == null
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 3))
                  : FlutterMap(
                      options: MapOptions(
                        initialCenter: currentLocation!,
                        initialZoom: 14,
                        maxZoom: 18,
                        minZoom: 3,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                          subdomains: const ['a', 'b', 'c'],
                          userAgentPackageName: 'com.example.potholeapp',
                          retinaMode: true,
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: currentLocation!,
                              width: 44,
                              height: 44,
                              child: const Icon(Icons.my_location,
                                  color: Colors.blue, size: 44),
                            ),
                            if (destination != null)
                              Marker(
                                point: destination!,
                                width: 44,
                                height: 44,
                                child: const Icon(Icons.location_pin,
                                    color: Colors.redAccent, size: 44),
                              ),
                            if (showPotholes)
                              ...(routePoints.isNotEmpty
                                      ? _potholesAlongRoute()
                                      : potholeLocations)
                                  .map(
                                    (p) => Marker(
                                      point: p,
                                      width: 32,
                                      height: 32,
                                      child: const Icon(
                                        Icons.warning_amber_rounded,
                                        color: Colors.deepOrange,
                                        size: 32,
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
                                strokeWidth: 7,
                                color: Colors.black.withOpacity(0.25),
                              ),
                              Polyline(
                                points: routePoints,
                                strokeWidth: 5,
                                color: Colors.green.shade700,
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
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildLocationRow() {
    return Row(
      children: [
        const Icon(Icons.my_location, color: Colors.green, size: 26),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            currentLocation == null
                ? 'Locating your position...'
                : 'Current: ${currentLocation!.latitude.toStringAsFixed(4)}, ${currentLocation!.longitude.toStringAsFixed(4)}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.my_location_outlined, color: Colors.green),
          tooltip: 'Refresh Location',
          onPressed: _getCurrentLocation,
        ),
      ],
    );
  }

  Widget _buildDestinationDropdown() {
    return Row(
      children: [
        const Icon(Icons.location_on, color: Colors.redAccent, size: 26),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButtonFormField<String>(
            value: destination == null
                ? null
                : destinations.entries
                    .firstWhere((e) => e.value == destination)
                    .key,
            hint: const Text('Select Destination'),
            decoration: InputDecoration(
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey.shade100,
            ),
            items: destinations.keys
                .map((dest) => DropdownMenuItem(
                      value: dest,
                      child: Text(dest),
                    ))
                .toList(),
            onChanged: isLoadingRoute ? null : _onDestinationSelected,
          ),
        ),
      ],
    );
  }

  Widget _buildFAB(BuildContext context) {
    return FloatingActionButton.extended(
      backgroundColor: Colors.green.shade700,
      icon: const Icon(Icons.alt_route),
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
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Best Routes Nearby',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          ...destinations.entries.map(
            (entry) => ListTile(
              leading: const Icon(Icons.location_on, color: Colors.green),
              title: Text(entry.key, style: const TextStyle(fontSize: 18)),
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
      selectedItemColor: Colors.green.shade700,
      unselectedItemColor: Colors.grey.shade600,
      onTap: (index) {
        setState(() {
          _selectedIndex = index;
        });

        if (index == 1) {
          showAboutDialog(
            context: context,
            applicationName: 'Pothole Detection App',
            applicationVersion: '1.0.0',
            applicationIcon:
                const Icon(Icons.warning_amber_rounded, size: 40),
            children: const [
              Text(
                  'This app helps you detect potholes and find the best routes to avoid them.')
            ],
          );
        }
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
        BottomNavigationBarItem(icon: Icon(Icons.info), label: 'About'),
      ],
    );
  }
}
