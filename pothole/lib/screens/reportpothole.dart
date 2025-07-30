import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:another_flushbar/flushbar.dart'; // << For fancy toasts

import 'package:pothole/theme_provider.dart'; // Replace with your actual ThemeProvider import

class ReportPotholePage extends StatefulWidget {
  const ReportPotholePage({super.key});

  @override
  State<ReportPotholePage> createState() => _ReportPotholePageState();
}

class _ReportPotholePageState extends State<ReportPotholePage>
    with SingleTickerProviderStateMixin {
  File? _image;
  String? _address;
  String? _region;
  Position? _position;
  double? _speed;
  bool _loading = false;
  bool _locationPermissionDenied = false;
  bool _cameraPermissionDenied = false;

  final picker = ImagePicker();

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    _fadeController.forward();

    _getLocationAndAddress();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _getImageFromCamera() async {
    try {
      final pickedFile = await picker.pickImage(source: ImageSource.camera);
      if (pickedFile != null) {
        setState(() => _image = File(pickedFile.path));
        _fadeController.reset();
        _fadeController.forward();
      }
    } catch (e) {
      setState(() => _cameraPermissionDenied = true);
      _showErrorToast('Camera access denied');
    }
  }

  Future<void> _getLocationAndAddress() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showErrorToast('Please enable location services');
      setState(() => _locationPermissionDenied = true);
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showErrorToast('Location permission denied');
        setState(() => _locationPermissionDenied = true);
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      _showErrorToast('Location permission denied permanently');
      setState(() => _locationPermissionDenied = true);
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      setState(() {
        _position = position;
        _speed = position.speed * 3.6;
        _region = placemarks.first.locality ?? 'Unknown';
        _address =
            '${placemarks.first.street}, ${_region}, ${placemarks.first.country}';
      });
    } catch (e) {
      _showErrorToast('Failed to get location/address');
    }
  }

  Future<String?> _uploadImageToFirebase(File image) async {
    try {
      final ref = FirebaseStorage.instance.ref(
        'potholes/${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await ref.putFile(image);
      return await ref.getDownloadURL();
    } catch (_) {
      return null;
    }
  }

  Future<void> _submitData() async {
    if (_image == null) {
      _showErrorToast('Please capture a photo before submitting');
      return;
    }
    if (_position == null || _address == null) {
      _showErrorToast('Location data not available');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Submission'),
        content: const Text(
          'Are you sure you want to submit this pothole report?',
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context, false),
          ),
          ElevatedButton(
            child: const Text('Submit'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _loading = true);

    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? 'anonymous';
    final email = user?.email ?? 'anonymous@example.com';

    final imageUrl = await _uploadImageToFirebase(_image!);
    if (imageUrl == null) {
      setState(() => _loading = false);
      _showErrorToast('Image upload failed');
      return;
    }

    // Send to ThingSpeak
    const String apiKey = 'UOPAYZP2P3Q5BDD0';
    const String url = 'https://api.thingspeak.com/update';

    await http.post(
      Uri.parse(url),
      body: {
        'api_key': apiKey,
        'field1': _position!.latitude.toString(),
        'field2': _position!.longitude.toString(),
        'field3': '9.8',
        'field4': _address!,
        'field5': _speed?.toStringAsFixed(2) ?? '0.0',
      },
    );

    // Save to Firestore pothole_reports
    await FirebaseFirestore.instance.collection('pothole_reports').add({
      'imageUrl': imageUrl,
      'latitude': _position!.latitude,
      'longitude': _position!.longitude,
      'speed': _speed?.toStringAsFixed(2) ?? '0.0',
      'address': _address,
      'region': _region ?? 'Unknown',
      'userId': uid,
      'userEmail': email,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Add notification document
    await FirebaseFirestore.instance.collection('notifications').add({
      'title': 'New pothole reported at $_address',
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
      'potholeLocation': GeoPoint(_position!.latitude, _position!.longitude),
      'reportedBy': email,
    });

    setState(() {
      _loading = false;
      _image = null;
      _address = null;
      _region = null;
      _position = null;
      _speed = null;
    });

    _showSuccessToast('Pothole report submitted!');
    _showSharePrompt(imageUrl);
  }

  void _showErrorToast(String message) {
    Flushbar(
      margin: const EdgeInsets.all(8),
      borderRadius: BorderRadius.circular(10),
      backgroundColor: Colors.black,
      icon: const Icon(Icons.error_outline, color: Colors.white),
      messageText: Text(
        message,
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
      duration: const Duration(seconds: 3),
      flushbarPosition: FlushbarPosition.TOP,
    ).show(context);
  }

  void _showSuccessToast(String message) {
    Flushbar(
      margin: const EdgeInsets.all(8),
      borderRadius: BorderRadius.circular(10),
      backgroundColor: Colors.black,
      icon: const Icon(Icons.check_circle_outline, color: Colors.white),
      messageText: Text(
        message,
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
      duration: const Duration(seconds: 2),
      flushbarPosition: FlushbarPosition.TOP,
    ).show(context);
  }

  void _showSharePrompt(String imageUrl) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Share your report',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Share.share(
                  'I just reported a pothole at $_address. See the photo: $imageUrl',
                );
                Navigator.pop(context);
              },
              icon: const Icon(Icons.share),
              label: const Text('Share'),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 28,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Dismiss'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    final themeData = Theme.of(context);
    final primaryColor = themeData.colorScheme.primary;
    final accentColor = themeData.colorScheme.secondary;

    // Define button colors based on dark mode: RED for dark mode, BLACK for light mode
    final buttonBackgroundColor = isDarkMode
        ? Colors.red.shade700
        : Colors.black;
    final submitButtonColor = isDarkMode ? Colors.red.shade700 : Colors.black;

    return Scaffold(
      backgroundColor: themeData.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Report Pothole',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        elevation: 3,
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: isDarkMode
                ? 'Switch to Light Mode'
                : 'Switch to Dark Mode',
            icon: Icon(
              isDarkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            ),
            onPressed: () =>
                themeProvider.toggleTheme(!themeProvider.isDarkMode),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FadeTransition(
              opacity: _fadeAnimation,
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                shadowColor: primaryColor.withOpacity(0.2),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: _image != null
                      ? Image.file(
                          _image!,
                          height: 240,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          height: 240,
                          color: primaryColor.withOpacity(0.05),
                          child: Icon(
                            Icons.photo_camera_outlined,
                            size: 100,
                            color: primaryColor.withOpacity(0.3),
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonBackgroundColor,
                elevation: 6,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                shadowColor: buttonBackgroundColor.withOpacity(0.5),
              ),
              onPressed: _cameraPermissionDenied ? null : _getImageFromCamera,
              icon: const Icon(Icons.camera_alt_outlined, size: 24),
              label: Text(
                'Capture Photo',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: Colors.white, // ensure text white in both modes
                ),
              ),
            ),
            if (_cameraPermissionDenied)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Camera permission denied. Please enable it in settings.',
                  style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 30),
            if (_locationPermissionDenied)
              Card(
                color: Colors.red.shade50,
                margin: const EdgeInsets.only(bottom: 20),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Location permission denied or location services are off. Please enable to report potholes.',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            if (_position != null && _address != null)
              Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                shadowColor: primaryColor.withOpacity(0.2),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_rounded,
                            color: accentColor,
                            size: 26,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              _address!,
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: themeData.textTheme.bodyLarge?.color,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Latitude: ${_position!.latitude.toStringAsFixed(6)}',
                        style: GoogleFonts.poppins(
                          color: themeData.textTheme.bodyMedium?.color,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Longitude: ${_position!.longitude.toStringAsFixed(6)}',
                        style: GoogleFonts.poppins(
                          color: themeData.textTheme.bodyMedium?.color,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Speed: ${_speed?.toStringAsFixed(2)} km/h',
                        style: GoogleFonts.poppins(
                          color: themeData.textTheme.bodyMedium?.color,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SizedBox(
                          height: 200,
                          child: GoogleMap(
                            initialCameraPosition: CameraPosition(
                              target: LatLng(
                                _position!.latitude,
                                _position!.longitude,
                              ),
                              zoom: 16,
                            ),
                            markers: {
                              Marker(
                                markerId: const MarkerId('pothole_marker'),
                                position: LatLng(
                                  _position!.latitude,
                                  _position!.longitude,
                                ),
                              ),
                            },
                            zoomControlsEnabled: false,
                            liteModeEnabled: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed:
                  (_loading ||
                      _locationPermissionDenied ||
                      _cameraPermissionDenied)
                  ? null
                  : _submitData,
              icon: _loading
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Icon(Icons.send_outlined),
              label: Text(
                _loading ? 'Submitting...' : 'Submit Report',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: Colors.white, // ensure white text
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: submitButtonColor,
                foregroundColor:
                    Colors.white, // For white text & icons on button
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 6,
                shadowColor: submitButtonColor.withOpacity(0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
