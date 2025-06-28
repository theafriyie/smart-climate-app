import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shimmer/shimmer.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'dart:ui';
import 'home_screen.dart';

void _noop() {}


class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final databaseRef = FirebaseDatabase.instance.ref('notifications');
  List<Map<String, dynamic>> notifications = [];
  bool isLoading = true;
  String filter = "all";

  @override
  void initState() {
    super.initState();
    fetchNotifications();
  }

  void fetchNotifications() {
    databaseRef.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;

      if (data == null) {
        setState(() {
          isLoading = false;
          notifications.clear();
        });
        return;
      }

      final seen = <String>{};
      final tempList = <Map<String, dynamic>>[];

      data.forEach((key, value) {
        final title = value["title"];
        final message = value["message"];
        final timestamp = value["timestamp"];
        final unique = "$title|$message|$timestamp";

        if (!seen.contains(unique)) {
          seen.add(unique);
          tempList.add({
            "id": key,
            "title": title,
            "message": message,
            "timestamp": DateTime.tryParse(timestamp) ?? DateTime.now(),
          });
        }
      });

      tempList.sort((a, b) => b["timestamp"].compareTo(a["timestamp"]));

      setState(() {
        notifications = tempList;
        isLoading = false;
      });
    });
  }


  void deleteNotification(String id) {
    databaseRef.child(id).remove(); // deletes from Firebase
    setState(() {
      notifications.removeWhere((notif) => notif["id"] == id);
    });
  }


  void clearAllNotifications() {
    databaseRef.remove();
    setState(() => notifications.clear());
  }


  Future<void> exportNotificationsToPDF() async {
    final doc = pw.Document();
    final grouped = groupNotificationsByDay(notifications);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Text('📬 Climate Alert Report',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          for (var entry in grouped.entries) ...[
            pw.Text(entry.key,
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 5),
            for (var notif in entry.value)
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 6),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("🔔 ${notif['title']}",
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text("💬 ${notif['message']}"),
                    pw.Text("🕓 ${formatTime(notif['timestamp'])}"),
                    pw.SizedBox(height: 5),
                  ],
                ),
              ),
            pw.Divider()
          ]
        ],
      ),
    );

    try {
      // 🔐 Request permission first
      final status = await Permission.manageExternalStorage.request();
      if (!status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Storage permission denied")),
        );
        return;
      }

      final directory = Directory('/storage/emulated/0/Download');
      final filePath = "${directory.path}/climate_alert_${DateTime.now().millisecondsSinceEpoch}.pdf";
      final file = File(filePath);
      await file.writeAsBytes(await doc.save());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("📄 PDF saved to Downloads:\n$filePath")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Failed to save PDF: $e")),
      );
    }
  }



  String formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : dt.hour;
    final ampm = dt.hour >= 12 ? "PM" : "AM";
    final min = dt.minute.toString().padLeft(2, '0');
    return "$hour:$min $ampm";
  }

  String groupDate(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year &&
        dt.month == now.month &&
        dt.day == now.day) {
      return "Today";
    } else if (dt.year == now.year &&
        dt.month == now.month &&
        dt.day == now.day - 1) {
      return "Yesterday";
    } else {
      return "${dt.day}/${dt.month}/${dt.year}";
    }
  }

  IconData getIcon(String title) {
    if (title.toLowerCase().contains("temperature")) return Icons.thermostat;
    if (title.toLowerCase().contains("humidity")) return Icons.water_drop;
    return Icons.notifications;
  }

  Color getColor(String title) {
    if (title.toLowerCase().contains("temperature")) return Colors.red;
    if (title.toLowerCase().contains("humidity")) return Colors.blue;
    return Colors.grey;
  }

  Map<String, List<Map<String, dynamic>>> groupNotificationsByDay(
      List<Map<String, dynamic>> list) {
    Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var notif in list) {
      final dt = notif["timestamp"];
      final groupKey = groupDate(dt);
      grouped.putIfAbsent(groupKey, () => []).add(notif);
    }
    return grouped;
  }

  Widget _buildShimmerCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: Container(
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String type) {
    return FilterChip(
      label: Text(label,
          style: TextStyle(color: filter == type ? Colors.white : Colors.black)),
      selected: filter == type,
      selectedColor: Colors.blue,
      backgroundColor: Colors.grey[300],
      onSelected: (_) => setState(() => filter = type),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notif) {
    final title = notif["title"];
    final message = notif["message"];
    final dt = notif["timestamp"];
    final icon = getIcon(title);
    final color = getColor(title);

    return Dismissible(
        key: Key(notif["id"]),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          color: Colors.red,
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        onDismissed: (_) => deleteNotification(notif["id"]),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                // 🔲 Backdrop blur
                BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(),
                ),

                // 🔳 Foreground card
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.35),
                        blurRadius: 20,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),

                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: color.withAlpha(40),
                      child: Icon(icon, color: color),
                    ),
                    title: Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        color: Colors.white,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          message,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formatTime(dt),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

        )
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = notifications.where((notif) {
      if (filter == "all") return true;
      if (filter == "temperature" && notif["title"].contains("Temperature")) return true;
      if (filter == "humidity" && notif["title"].contains("Humidity")) return true;
      return false;
    }).toList();

    final grouped = groupNotificationsByDay(filtered);

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(70),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.blueGrey,
            border: Border(
              bottom: BorderSide(color: Colors.white.withOpacity(0.05)),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),

          child: SafeArea(
            child: Stack(
              children: [
                // 🔙 Back button
                Positioned(
                  left: 0,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      } else {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (context) => const HomeScreen(toggleTheme: _noop)),
                              (route) => false,
                        );
                      }
                    },

                  ),
                ),

                // 📬 Centered title
                Align(
                  alignment: Alignment.center,
                  child: Text(
                    "Notification Log",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          blurRadius: 10,
                          color: Colors.blueAccent.withOpacity(0.6),
                          offset: Offset(0, 2),
                        ),
                        Shadow(
                          blurRadius: 4,
                          color: Colors.black45,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),


                // 🛠 Right-side actions
                Positioned(
                  right: 0,
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                        onPressed: () {
                          if (notifications.isNotEmpty) {
                            exportNotificationsToPDF();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("No notifications to export.")),
                            );
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_forever, color: Colors.white),
                        onPressed: () => showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text("Clear All Notifications?"),
                            content: const Text("This will delete all notifications."),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text("Cancel"),
                              ),
                              TextButton(
                                onPressed: () {
                                  clearAllNotifications();
                                  Navigator.pop(context);
                                },
                                child: const Text("Clear All",
                                    style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

          ),
        ),
      ),


      body: isLoading
          ? ListView.builder(
        itemCount: 4,
        itemBuilder: (_, __) => _buildShimmerCard(),
      )
        : Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),

        child: Column(
    children: [
    Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: ["all", "temperature", "humidity"].map((type) {
                final label = type[0].toUpperCase() + type.substring(1);
                final isSelected = filter == type;



                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: GestureDetector(
                    onTap: () => setState(() => filter = type),
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 300),
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? Color(0xFF1E88E5).withOpacity(0.25) : Colors.transparent,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: isSelected ? Color(0xFF1E88E5) : Colors.grey.shade700,
                          width: 1.2,
                        ),
                        boxShadow: isSelected
                            ? [
                          BoxShadow(
                            color: Color(0xFF1E88E5).withOpacity(0.4),
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          )
                        ]
                            : [],
                      ),

                      child: Text(
                        label,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.grey.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          Expanded(
            child: grouped.isEmpty
                ? const Center(child: Text("No notifications available."))
                : ListView(
              children: grouped.entries.map((entry) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Text(
                        entry.key,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.85),
                          letterSpacing: 0.3,
                          shadows: [
                            Shadow(
                              blurRadius: 8,
                              color: Colors.black.withOpacity(0.25),
                              offset: Offset(0, 2),
                            )
                          ],
                        ),
                      ),

                    ),
                    ...entry.value.map(_buildNotificationCard).toList(),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    )
    );
  }
}
