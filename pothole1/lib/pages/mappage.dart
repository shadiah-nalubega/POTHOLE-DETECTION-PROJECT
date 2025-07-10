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
