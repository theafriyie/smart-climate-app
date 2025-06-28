import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'history_screen.dart';
import 'notification_screen.dart';
import 'settings_screen.dart';

// 🔔 Initialize Local Notifications
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

class HomeScreen extends StatefulWidget {
  final VoidCallback toggleTheme;
  const HomeScreen({super.key, required this.toggleTheme});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final databaseRef = FirebaseDatabase.instance.ref('data');
  final notificationsRef = FirebaseDatabase.instance.ref('notifications');

  double temperature = 0.0;
  double humidity = 0.0;
  int unreadCount = 0;
  Timer? timer;

  double? lastTempAlertValue;
  double? lastHumidityAlertValue;
  DateTime? lastTempAlertTime;
  DateTime? lastHumidityAlertTime;
  int? lastHistorySavedMinute;

  @override
  void initState() {
    super.initState();
    _loadLocalData();
    _fetchDataFromFirebase();
    _countUnreadNotifications();
    _checkInternetAndSync();

    timer = Timer.periodic(const Duration(seconds: 60), (timer) {
      _fetchDataFromFirebase();
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void _loadLocalData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      temperature = prefs.getDouble("temperature") ?? 0.0;
      humidity = prefs.getDouble("humidity") ?? 0.0;
    });
    _fetchDataFromFirebase(); // Ensure freshness
  }

  void _fetchDataFromFirebase() async {
    databaseRef.once().then((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        setState(() {
          temperature = double.tryParse(data['temperature'].toString()) ?? 0.0;
          humidity = double.tryParse(data['humidity'].toString()) ?? 0.0;
        });
        _saveDataLocally();
      }
    });

    databaseRef.onValue.listen((event) async {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        double newTemp = double.tryParse(data['temperature'].toString()) ?? 0.0;
        double newHumidity = double.tryParse(data['humidity'].toString()) ?? 0.0;

        setState(() {
          temperature = newTemp;
          humidity = newHumidity;
        });

        _saveDataLocally();

        // 🕒 Save history once per minute
        int currentMinute = DateTime.now().minute;
        if (currentMinute % 1 == 0 && lastHistorySavedMinute != currentMinute) {
          FirebaseDatabase.instance.ref('history').push().set({
            "temperature": newTemp,
            "humidity": newHumidity,
            "timestamp": DateTime.now().toIso8601String(),
          });
          lastHistorySavedMinute = currentMinute;
        }

        // ✅ Smart Temp Alert
        if ((newTemp < 28 || newTemp > 32) &&
            (lastTempAlertValue != newTemp || _isCooldownOver(lastTempAlertTime))) {
          _sendAlert("🔥 Temperature Alert!", "Temperature is ${newTemp.toStringAsFixed(1)}°C");
          lastTempAlertValue = newTemp;
          lastTempAlertTime = DateTime.now();
        }

        // ✅ Smart Humidity Alert
        if ((newHumidity < 60 || newHumidity > 70) &&
            (lastHumidityAlertValue != newHumidity || _isCooldownOver(lastHumidityAlertTime))) {
          _sendAlert("💧 Humidity Alert!", "Humidity is ${newHumidity.toStringAsFixed(1)}%");
          lastHumidityAlertValue = newHumidity;
          lastHumidityAlertTime = DateTime.now();
        }
      }
    });
  }

  bool _isCooldownOver(DateTime? lastAlertTime) {
    if (lastAlertTime == null) return true;
    return DateTime.now().difference(lastAlertTime).inMinutes >= 10;
  }

  void _saveDataLocally() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setDouble("temperature", temperature);
    prefs.setDouble("humidity", humidity);
  }

  void _sendAlert(String title, String message) async {
    final now = DateTime.now();

    // 🧠 Check last notification in database
    final snapshot = await notificationsRef.orderByKey().limitToLast(1).get();

    if (snapshot.exists) {
      final last = (snapshot.value as Map).values.first;
      final lastTitle = last["title"];
      final lastMessage = last["message"];

      if (lastTitle == title && lastMessage == message) {
        return; // 🚫 Duplicate: don't save again
      }
    }

    _showNotification(title, message);

    notificationsRef.push().set({
      "title": title,
      "message": message,
      "timestamp": now.toIso8601String(),
    });
  }


  void _showNotification(String title, String body) {
    var androidDetails = const AndroidNotificationDetails(
      "high_importance_channel",
      "High Importance Notifications",
      importance: Importance.max,
      priority: Priority.high,
    );

    var generalNotificationDetails = NotificationDetails(android: androidDetails);
    flutterLocalNotificationsPlugin.show(0, title, body, generalNotificationDetails);
  }

  void _countUnreadNotifications() {
    notificationsRef.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      setState(() {
        unreadCount = data?.length ?? 0;
      });
    });
  }

  void _checkInternetAndSync() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.wifi) ||
        connectivityResult.contains(ConnectivityResult.mobile)) {
      databaseRef.set({
        "temperature": temperature,
        "humidity": humidity,
      });
    }
  }

  String getFormattedDate() {
    final now = DateTime.now();
    return DateFormat('EEE, MMM d').format(now); // Tue, Jul 16
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          Image.asset(
            "assets/images/bg_home.png",
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
          Container(color: Colors.black.withOpacity(0.3)),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Text(getFormattedDate(),
                      style: const TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 8),
                  _glassTextBox("Smart Climate Monitoring"),
                  const SizedBox(height: 36),

                  _glowingCard(
                    icon: Icons.thermostat,
                    label: "Temperature",
                    value: "${temperature.toStringAsFixed(1)}°C",
                    color: Colors.redAccent,
                  ),
                  const SizedBox(height: 20),
                  _glowingCard(
                    icon: Icons.water_drop,
                    label: "Humidity",
                    value: "${humidity.toStringAsFixed(1)}%",
                    color: Colors.lightBlueAccent,
                  ),
                  const Spacer(),
                  _bottomNavBar(),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _glassTextBox(String text) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white30),
          ),
          child: Text(
            text,
            style: const TextStyle(
                fontSize: 18,
                color: Colors.white,
                fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  Widget _glowingCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [color.withOpacity(0.25), Colors.white.withOpacity(0.08)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.6),
            blurRadius: 25,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 52, color: color),
          const SizedBox(height: 16),
          Text(label,
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: Colors.white)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
        ],
      ),
    );
  }

  Widget _bottomNavBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white30),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(Icons.show_chart, "Trends", () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const HistoryScreen()));
              }),
              _navItem(Icons.home, "Home", null, selected: true),
              _navItem(Icons.notifications, "Alerts", () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const NotificationScreen()));
              }),
              _navItem(Icons.settings, "Settings", () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            SettingsScreen(toggleTheme: widget.toggleTheme)));
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, VoidCallback? onTap,
      {bool selected = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      splashColor: Colors.white24,
      highlightColor: Colors.white10,
      child: Column(
        children: [
          Icon(icon,
              size: 24,
              color: selected ? Colors.white : Colors.white70),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: selected ? Colors.white : Colors.white70)),
        ],
      ),
    );
  }
}



