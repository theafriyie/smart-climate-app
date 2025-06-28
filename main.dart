import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_screen.dart';
import 'home_screen.dart';
import 'verify_email_screen.dart';

// 🔥 Initialize Local Push Notifications
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // ✅ Enable Offline Persistence for Firebase Database
  FirebaseDatabase.instance.setPersistenceEnabled(true);
  FirebaseDatabase.instance.ref().keepSynced(true);

  // ✅ Register Background Handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // ✅ Initialize Push Notifications
  await _setupFirebaseMessaging();

  runApp(const AppWrapper());
}

// ✅ Handle Background Messages
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("🔔 Background Message Received: ${message.notification?.title}");
}

// ✅ Setup Firebase Messaging
Future<void> _setupFirebaseMessaging() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  // ✅ Request Notification Permissions
  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    debugPrint("✅ Push Notifications Enabled");
  } else {
    debugPrint("🚫 Push Notifications Denied");
  }

  // ✅ Get FCM Token for Debugging
  String? token = await messaging.getToken();
  debugPrint("📲 FCM Token: $token");

  // ✅ Initialize Local Notifications
  const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initSettings = InitializationSettings(android: androidSettings);
  await flutterLocalNotificationsPlugin.initialize(initSettings);

  // ✅ Listen for Foreground Messages
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    if (message.notification != null) {
      _showNotification(message.notification!.title ?? "Alert", message.notification!.body ?? "Check climate status");
    }
  });

  // ✅ Listen for Notification Clicks
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    debugPrint("🔔 Notification Clicked: ${message.data}");
  });
}

// ✅ Show Local Notification
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

// ✅ App Wrapper (Handles Theme & Authentication)
class AppWrapper extends StatefulWidget {
  const AppWrapper({super.key});

  @override
  AppWrapperState createState() => AppWrapperState();
}

class AppWrapperState extends State<AppWrapper> {
  bool isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  void _loadTheme() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      isDarkMode = prefs.getBool("isDarkMode") ?? false;
    });
  }

  void _toggleTheme() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      isDarkMode = !isDarkMode;
      prefs.setBool("isDarkMode", isDarkMode);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: isDarkMode ? ThemeData.dark() : ThemeData.light(),
      home: AuthWrapper(toggleTheme: _toggleTheme),
    );
  }
}

// ✅ Handles Authentication & Home Screen
class AuthWrapper extends StatelessWidget {
  final VoidCallback toggleTheme;
  const AuthWrapper({super.key, required this.toggleTheme});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final user = snapshot.data;

        if (user != null) {
          if (user.emailVerified) {
            return HomeScreen(toggleTheme: toggleTheme);
          } else {
            return VerifyEmailScreen(toggleTheme: toggleTheme);
          }
        }

        return AuthScreen(toggleTheme: toggleTheme);
      },
    );
  }
}

