import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lottie/lottie.dart';
import 'auth_screen.dart';


class VerifyEmailScreen extends StatefulWidget {
  final VoidCallback toggleTheme;

  const VerifyEmailScreen({super.key, required this.toggleTheme});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool isLoading = false;

  Future<void> checkVerification() async {
    setState(() => isLoading = true);

    await FirebaseAuth.instance.currentUser?.reload();
    final user = FirebaseAuth.instance.currentUser;

    if (user != null && user.emailVerified) {
      await FirebaseAuth.instance.signOut(); // ✅ safely sign out before login

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => AuthScreen(toggleTheme: widget.toggleTheme),
        ),
      );
    }
    else {
      setState(() => isLoading = false);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Still not verified. Please check your inbox."),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final navigator = Navigator.of(context);

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (!didPop) {
          await FirebaseAuth.instance.signOut();

          navigator.pushReplacement(
            MaterialPageRoute(
              builder: (_) => AuthScreen(toggleTheme: widget.toggleTheme),
            ),
          );
        }
      },

      child: Scaffold(
        backgroundColor: Colors.blue.shade50,
        appBar: AppBar(
          backgroundColor: Colors.blue.shade800,
          automaticallyImplyLeading: false,
          title: const Text(
            "📩 Email Verification",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          actions: [
            IconButton(icon: const Icon(Icons.brightness_6),
                onPressed: widget.toggleTheme),
          ],
        ),
        body: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFbbdefb), Color(0xFFe3f2fd)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  elevation: 8,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Lottie.asset(
                            "assets/animations/email_verify.json", height: 150),
                        const SizedBox(height: 16),
                        const Text(
                          "🎉 Account Created!",
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          "📩 A verification email has been sent to your inbox.\nPlease verify before continuing.",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 30),
                        isLoading
                            ? const CircularProgressIndicator()
                            : ElevatedButton.icon(
                          icon: const Icon(Icons.refresh),
                          label: const Text("I've Verified"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: checkVerification,
                        ),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: () async {
                            await FirebaseAuth.instance.currentUser
                                ?.sendEmailVerification();
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Verification email resent."),
                                backgroundColor: Colors.green,
                              ),
                            );
                          },
                          child: const Text("Resend verification email"),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
