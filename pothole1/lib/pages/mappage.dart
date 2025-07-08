import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class TravelRouteMapPage extends StatelessWidget {
  const TravelRouteMapPage({super.key});

  @override
  Widget build(BuildContext context) {
    final routePoints = <LatLng>[
      LatLng(0.3379, 32.5714),  // Start point: Wandegeya
      LatLng(0.3385, 32.5720),
      LatLng(0.3390, 32.5730),
      LatLng(0.3400, 32.5735),  // End point
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Travel Route Map - Wandegeya'),
        centerTitle: true,
      ),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: routePoints[0],
          initialZoom: 15.0,
        ),
        children: [
          TileLayer(
            urlTemplate:
                'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
            subdomains: ['a', 'b', 'c'],
            userAgentPackageName: 'com.example.yourapp',
          ),
          PolylineLayer(
            polylines: [
              Polyline(
                points: routePoints,
                color: Colors.blue,
                strokeWidth: 4,
              ),
            ],
          ),
          MarkerLayer(
            markers: [
              // Start marker
              Marker(
                point: routePoints.first,
                width: 40,
                height: 40,
                child: const Icon(
                  Icons.location_on,
                  color: Colors.green,
                  size: 40,
                ),
              ),
              // End marker
              Marker(
                point: routePoints.last,
                width: 40,
                height: 40,
                child: const Icon(
                  Icons.flag,
                  color: Colors.red,
                  size: 40,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
