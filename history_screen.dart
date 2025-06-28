import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final databaseRef = FirebaseDatabase.instance.ref('history');
  List<FlSpot> tempSpots = [];
  List<FlSpot> humiditySpots = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _listenToLiveUpdates();
  }

  void _listenToLiveUpdates() {
    databaseRef.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;

      if (data == null) {
        setState(() {
          tempSpots.clear();
          humiditySpots.clear();
          isLoading = false;
        });
        return;
      }

      // Sort by timestamp
      final sortedEntries = data.entries.toList()
        ..sort((a, b) => DateTime.parse(a.value['timestamp'])
            .compareTo(DateTime.parse(b.value['timestamp'])));

      // Keep only last 9 entries
      final recentEntries = sortedEntries.length > 5
          ? sortedEntries.sublist(sortedEntries.length - 5)
          : sortedEntries;

      List<FlSpot> tempData = [];
      List<FlSpot> humidityData = [];

      for (int i = 0; i < recentEntries.length; i++) {
        final entry = recentEntries[i].value;
        double temp = double.tryParse(entry['temperature'].toString()) ?? 0.0;
        double humidity = double.tryParse(entry['humidity'].toString()) ?? 0.0;
        tempData.add(FlSpot(i.toDouble(), temp));
        humidityData.add(FlSpot(i.toDouble(), humidity));
      }

      setState(() {
        tempSpots = tempData;
        humiditySpots = humidityData;
        isLoading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border(
                bottom: BorderSide(color: Colors.white24, width: 0.5),
              ),
            ),
            child: SafeArea(
              child: Center(
                child: Text(
                  "Historical Data Trends",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.7,
                    shadows: [
                      Shadow(
                        blurRadius: 8,
                        color: Colors.black45,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),


        body: isLoading
    ? const Center(child: CircularProgressIndicator())
        : Container(
    decoration: const BoxDecoration(
    gradient: LinearGradient(
    colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    ),
    ),
    child: Padding(
    padding: const EdgeInsets.all(16.0),
    child: Column(
    children: [
            _buildHistoryCard(
              title: "🌡️ Temperature Trend",
              color: Colors.red,
              spots: tempSpots,
              noDataMessage: "No temperature data yet.",
            ),
            const SizedBox(height: 20),
            _buildHistoryCard(
              title: "💧 Humidity Trend",
              color: Colors.blue,
              spots: humiditySpots,
              noDataMessage: "No humidity data yet.",
            ),
          ],
        ),
      ),
    )
    );
  }

  Widget _buildHistoryCard({
    required String title,
    required Color color,
    required List<FlSpot> spots,
    required String noDataMessage,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(title,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color)),
            const SizedBox(height: 10),
            SizedBox(
              height: 200,
              child: spots.isNotEmpty
                  ? LineChart(
                LineChartData(
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 42,
                        getTitlesWidget: (value, meta) => Text(
                          value.toStringAsFixed(1),
                          style: const TextStyle(fontSize: 12),
                          textAlign: TextAlign.left,
                        ),
                      ),
                    ),

                    bottomTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: true)),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: color,
                      barWidth: 4,
                      belowBarData: BarAreaData(show: false),
                    ),
                  ],
                ),
              )
                  : Center(child: Text(noDataMessage, style: TextStyle(color: color))),
            ),
          ],
        ),
      ),
    );
  }
}
