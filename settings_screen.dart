import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_screen.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback toggleTheme;

  const SettingsScreen({super.key, required this.toggleTheme});

  @override
  SettingsScreenState createState() => SettingsScreenState();
}

class SettingsScreenState extends State<SettingsScreen> {
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

  void _logout(BuildContext context) async {
    final navigator = Navigator.of(context); // ✅ Store context before async call
    await FirebaseAuth.instance.signOut();
    navigator.pushReplacement(_slideTransition(AuthScreen(toggleTheme: widget.toggleTheme))); // ✅ Safe usage
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 🌙 Dark Mode Switch (Now in a Card)
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                title: const Text("Dark Mode", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                trailing: Switch(
                  value: isDarkMode,
                  activeColor: Colors.blue,
                  onChanged: (value) {
                    setState(() => isDarkMode = value);
                    widget.toggleTheme();
                  },
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 🔑 Logout Button (Now Styled & Rounded)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              ),
              onPressed: () => _logout(context),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.logout, color: Colors.white),
                  SizedBox(width: 10),
                  Text("Logout", style: TextStyle(color: Colors.white, fontSize: 16)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ Page Transition Animation (Slide In)
  PageRouteBuilder _slideTransition(Widget screen) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => screen,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOut;

        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        var offsetAnimation = animation.drive(tween);

        return SlideTransition(position: offsetAnimation, child: child);
      },
    );
  }
}
