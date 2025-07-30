import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:pothole/screens/reportpothole.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pothole Statistics',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.red,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.red.shade700,
          centerTitle: true,
          elevation: 0,
          titleTextStyle: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        textTheme: GoogleFonts.poppinsTextTheme(
          ThemeData.light().textTheme.apply(
            bodyColor: Colors.black,
            displayColor: Colors.black,
          ),
        ),
        cardColor: Colors.grey.shade100,
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Colors.red.shade400,
            textStyle: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.red,
        scaffoldBackgroundColor: Colors.grey.shade900,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.red.shade700,
          centerTitle: true,
          elevation: 0,
          titleTextStyle: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        textTheme: GoogleFonts.poppinsTextTheme(
          ThemeData.dark().textTheme.apply(
            bodyColor: Colors.white,
            displayColor: Colors.white,
          ),
        ),
        cardColor: Colors.grey.shade700,
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Colors.red.shade400,
            textStyle: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ),
      home: const StatsPage(),
      routes: {'/reportpothole': (context) => const ReportPotholePage()},
    );
  }
}

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  List<int> _lineData = [];
  List<String> _fullLabels = [];
  List<String> _shortLabels = [];
  List<Map<String, dynamic>> _reportedList = [];

  bool _isLoadingChart = true;
  bool _isLoadingReports = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    await Future.wait([_fetchLineChartData(), _fetchReportedPotholes()]);
  }
//this retrieves data from thingspeak 
  Future<void> _fetchLineChartData() async {
    const apiKey = 'I7I05AI7PDG2GY6T';
    final url = Uri.parse(
      'https://api.thingspeak.com/channels/3003013/feeds.json?api_key=$apiKey&results=100',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final feeds = data['feeds'] as List<dynamic>;

        final Map<String, int> counts = {};
        for (var feed in feeds) {
          final loc = (feed['field4'] as String?)?.trim() ?? 'Unknown';
          counts[loc] = (counts[loc] ?? 0) + 1;
        }

        final sortedLocations = counts.keys.toList()..sort();
        final shorts = sortedLocations
            .map(
              (loc) => loc.length >= 3
                  ? loc.substring(0, 3).toUpperCase()
                  : loc.toUpperCase(),
            )
            .toList();

        setState(() {
          _fullLabels = sortedLocations;
          _shortLabels = shorts;
          _lineData = sortedLocations.map((loc) => counts[loc] ?? 0).toList();
          _isLoadingChart = false;
        });
      } else {
        setState(() {
          _errorMessage =
              'Failed to load chart data (status ${response.statusCode})';
          _isLoadingChart = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading chart data: $e';
        _isLoadingChart = false;
      });
    }
  }

  Future<void> _fetchReportedPotholes() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('pothole_reports')
          .orderBy('timestamp', descending: true)
          .get();

      final docs = snapshot.docs.map((doc) => doc.data()).toList();

      setState(() {
        _reportedList = docs.cast<Map<String, dynamic>>();
        _isLoadingReports = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading reported potholes: $e';
        _isLoadingReports = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Pothole Statistics')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _errorMessage != null
            ? Center(
                child: Text(
                  _errorMessage!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.red.shade400,
                  ),
                  textAlign: TextAlign.center,
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Potholes by Region', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 220,
                    child: _isLoadingChart
                        ? const Center(child: CircularProgressIndicator())
                        : _fullLabels.isEmpty
                        ? Center(
                            child: Text(
                              'No data available.',
                              style: theme.textTheme.bodyMedium,
                            ),
                          )
                        : PotholeLineChart(
                            data: _lineData,
                            shortLabels: _shortLabels,
                            fullLabels: _fullLabels,
                          ),
                  ),
                  const SizedBox(height: 30),
                  Row(
                    children: [
                      // this is the text widget for the pothole  
                      Text(
                        'Potholes Reported',
                        style: theme.textTheme.titleLarge,
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () =>
                            Navigator.pushNamed(context, '/reportpothole'),
                        style: TextButton.styleFrom(
                          backgroundColor: isDarkMode
                              ? Colors.red
                              : Colors.black,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Report Pothole',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _isLoadingReports
                        ? const Center(child: CircularProgressIndicator())
                        : _reportedList.isEmpty
                        ? Center(
                            child: Text(
                              'No pothole reports found.',
                              style: theme.textTheme.bodyMedium,
                            ),
                          )
                        : ListView.builder(
                            itemCount: _reportedList.length > 6
                                ? 6
                                : _reportedList.length,
                            itemBuilder: (context, index) {
                              final report = _reportedList[index];
                              final timestamp = report['timestamp'];
                              String formattedDate = 'Unknown';

                              if (timestamp is Timestamp) {
                                final date = timestamp.toDate();

                                formattedDate = DateFormat(
                                  'yyyy-MM-dd HH:mm',
                                ).format(date);
                              }

                              return Card(
                                color: theme.cardColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 5,
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          ReportDetailsPage(report: report),
                                    ),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    leading: Hero(
                                      tag:
                                          report['imageUrl'] ??
                                          'no-image-$index',
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.network(
                                          report['imageUrl'] ??
                                              'https://i.pravatar.cc/150?img=1',
                                          width: 50,
                                          height: 50,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      report['userEmail'] ?? 'Unknown User',
                                      style: theme.textTheme.bodyLarge,
                                    ),
                                    subtitle: Text(
                                      report['region'] ?? 'Unknown Region',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(color: Colors.white70),
                                    ),
                                    trailing: Text(
                                      formattedDate,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: isDarkMode
                                            ? Colors.white60
                                            : Colors
                                                  .black54, // Changed this line
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}

class PotholeLineChart extends StatelessWidget {
  final List<int> data;
  final List<String> shortLabels;
  final List<String> fullLabels;

  const PotholeLineChart({
    super.key,
    required this.data,
    required this.shortLabels,
    required this.fullLabels,
  });

  @override
  Widget build(BuildContext context) {
    final maxY =
        (data.isNotEmpty ? (data.reduce((a, b) => a > b ? a : b) + 5) : 5)
            .toDouble();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return LineChart(
      LineChartData(
        backgroundColor: Colors.transparent,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 5,
          getDrawingHorizontalLine: (value) => FlLine(
            color: isDarkMode ? Colors.white24 : Colors.grey.shade400,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            bottom: BorderSide(
              color: isDarkMode ? Colors.white24 : Colors.grey.shade400,
              width: 1,
            ),
            left: BorderSide(
              color: isDarkMode ? Colors.white24 : Colors.grey.shade400,
              width: 1,
            ),
            right: const BorderSide(color: Colors.transparent),
            top: const BorderSide(color: Colors.transparent),
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              interval: maxY / 5,
              getTitlesWidget: (value, meta) => Padding(
                padding: const EdgeInsets.only(right: 6.0),
                child: Text(
                  value.toInt().toString(),
                  style: TextStyle(
                    color: isDarkMode ? Colors.white70 : Colors.black87,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= shortLabels.length) {
                  return const SizedBox.shrink();
                }
                return Tooltip(
                  message: fullLabels[index],
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      shortLabels[index],
                      style: TextStyle(
                        color: isDarkMode ? Colors.white70 : Colors.black87,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        minY: 0,
        maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(
              data.length,
              (i) => FlSpot(i.toDouble(), data[i].toDouble()),
            ),
            isCurved: true,
            color: Colors.redAccent.shade400,
            barWidth: 4,
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  Colors.redAccent.shade400.withOpacity(0.5),
                  Colors.redAccent.shade400.withOpacity(0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            dotData: const FlDotData(show: true),
            preventCurveOverShooting: true,
          ),
        ],
      ),
    );
  }
}
//this is the reportpothole details its good 
class ReportDetailsPage extends StatefulWidget {
  final Map<String, dynamic> report;

  const ReportDetailsPage({super.key, required this.report});

  @override
  State<ReportDetailsPage> createState() => _ReportDetailsPageState();
}

class _ReportDetailsPageState extends State<ReportDetailsPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final imageUrl = report['imageUrl'] ?? '';
    final user = report['userEmail'] ?? 'Unknown User';
    final username = report['username'] ?? 'Unknown Name';
    final region = report['region'] ?? 'Unknown Region';
    final timestamp = report['timestamp'];
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final backgroundColor = isDarkMode ? Colors.black : Colors.white;

    String formattedDate = 'Unknown';
    if (timestamp is Timestamp) {
      formattedDate = DateFormat(
        'EEEE, MMM d, yyyy – h:mm a',
      ).format(timestamp.toDate());
    }

    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: backgroundColor,
        cardColor: backgroundColor,
        textTheme: GoogleFonts.poppinsTextTheme(
          Theme.of(
            context,
          ).textTheme.apply(bodyColor: textColor, displayColor: textColor),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: Text('Pothole Report', style: TextStyle(color: textColor)),
          iconTheme: IconThemeData(color: textColor),
          backgroundColor: backgroundColor,
          centerTitle: true,
          elevation: 1.5,
        ),
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Hero(
                  tag: imageUrl,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            width: double.infinity,
                            height: 270,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return SizedBox(
                                height: 270,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    value: progress.expectedTotalBytes != null
                                        ? progress.cumulativeBytesLoaded /
                                              (progress.expectedTotalBytes ?? 1)
                                        : null,
                                    color: Colors.red.shade400,
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) =>
                                _imagePlaceholder(),
                          )
                        : _imagePlaceholder(),
                  ),
                ),
                const SizedBox(height: 28),
                Card(
                  elevation: 5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  shadowColor: Colors.red.shade400.withOpacity(0.3),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 22,
                    ),
                    child: Column(
                      children: [
                        _infoRow(
                          icon: Icons.person_outline,
                          label: 'User Name',
                          value: username,
                          iconColor: Colors.red.shade400,
                          textColor: textColor,
                        ),
                        const Divider(height: 36, thickness: 1.2),
                        _infoRow(
                          icon: Icons.email_outlined,
                          label: 'Email',
                          value: user,
                          iconColor: Colors.red.shade400,
                          textColor: textColor,
                        ),
                        const Divider(height: 36, thickness: 1.2),
                        _infoRow(
                          icon: Icons.place_outlined,
                          label: 'Region',
                          value: region,
                          iconColor: Colors.red.shade400,
                          textColor: textColor,
                        ),
                        const Divider(height: 36, thickness: 1.2),
                        _infoRow(
                          icon: Icons.calendar_today_outlined,
                          label: 'Reported on',
                          value: formattedDate,
                          iconColor: Colors.red.shade400,
                          textColor: textColor,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  "Additional Notes",
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.red.shade900.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.shade900.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Text(
                    report['notes']?.toString().trim().isNotEmpty == true
                        ? report['notes']
                        : 'No additional information provided.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      height: 1.5,
                      color: textColor.withOpacity(0.7),
                    ),
                  ),
                ),
                const SizedBox(height: 42),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      height: 270,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.red.shade900.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Icon(
        Icons.broken_image_outlined,
        size: 100,
        color: Colors.white54,
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? iconColor,
    Color? textColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor ?? Colors.red.shade400, size: 28),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  letterSpacing: 0.7,
                  color: textColor?.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
