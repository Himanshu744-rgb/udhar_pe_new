import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:math' show max;
import '../providers/theme_provider.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({Key? key}) : super(key: key);

  @override
  _StatisticsScreenState createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  String _selectedTimeRange = 'Last 7 Days';
  final List<String> _timeRanges = [
    'Last 7 Days',
    'Last 30 Days',
    'Last 90 Days',
  ];

  DateTime _getStartDate() {
    switch (_selectedTimeRange) {
      case 'Last 7 Days':
        return DateTime.now().subtract(const Duration(days: 7));
      case 'Last 30 Days':
        return DateTime.now().subtract(const Duration(days: 30));
      case 'Last 90 Days':
        return DateTime.now().subtract(const Duration(days: 90));
      default:
        return DateTime.now().subtract(const Duration(days: 7));
    }
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
    ThemeProvider themeProvider,
  ) {
    return Card(
      elevation: 4,
      color: themeProvider.isDarkMode ? Colors.grey[800] : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: themeProvider.textColor.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  color: themeProvider.textColor,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineChart(List<FlSpot> spots, ThemeProvider themeProvider, [List<DateTime>? dates]) {
    return AspectRatio(
      aspectRatio: 1.7,
      child: Card(
        elevation: 4,
        color: themeProvider.isDarkMode ? Colors.grey[800] : Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LineChart(
            LineChartData(
              gridData: FlGridData(show: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        '₹${value.toInt()}',
                        style: TextStyle(
                          color: themeProvider.textColor.withOpacity(0.7),
                          fontSize: 10,
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (value, meta) {
                      if (dates == null || dates.isEmpty || value.toInt() >= dates.length) {
                        return const SizedBox.shrink();
                      }
                      // Only show some dates to avoid overcrowding
                      if (value.toInt() % max(1, (dates.length / 5).floor()) != 0 && 
                          value.toInt() != dates.length - 1) {
                        return const SizedBox.shrink();
                      }
                      final date = dates[value.toInt()];
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          '${date.day}/${date.month}',
                          style: TextStyle(
                            color: themeProvider.textColor.withOpacity(0.7),
                            fontSize: 10,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                topTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border.all(color: const Color(0xff37434d), width: 1),
              ),
              minX: 0,
              maxX: spots.length.toDouble() - 1,
              minY: 0,
              maxY:
                  spots.isEmpty
                      ? 1000
                      : spots
                              .map((spot) => spot.y)
                              .reduce((a, b) => a > b ? a : b) *
                          1.2,
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: Colors.blue,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) {
                      return FlDotCirclePainter(
                        radius: 4,
                        color: Colors.blue,
                        strokeWidth: 2,
                        strokeColor: Colors.white,
                      );
                    },
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: Colors.blue.withOpacity(0.2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: themeProvider.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Statistics',
          style: TextStyle(color: themeProvider.textColor),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButton<String>(
              value: _selectedTimeRange,
              dropdownColor:
                  themeProvider.isDarkMode ? Colors.grey[800] : Colors.white,
              style: TextStyle(color: themeProvider.textColor),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() => _selectedTimeRange = newValue);
                }
              },
              items:
                  _timeRanges.map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('udhari_entries')
                .where('shopId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // Filter entries by date range
          final DateTime startDate = _getStartDate();
          final allEntries = snapshot.data!.docs;
          
          final entries = allEntries.where((doc) {
            DateTime entryDate;
            if (doc['date'] is Timestamp) {
              entryDate = (doc['date'] as Timestamp).toDate();
            } else if (doc['date'] is String) {
              entryDate = DateTime.parse(doc['date']);
            } else {
              return false;
            }
            return entryDate.isAfter(startDate) || entryDate.isAtSameMomentAs(startDate);
          }).toList();
          
          final totalAmount = entries.fold<double>(
            0,
            (sum, doc) => sum + (doc['amount'] as num).toDouble(),
          );

          final averageAmount =
              entries.isEmpty ? 0.0 : totalAmount / entries.length;

          // Check if isPaid field exists and handle it correctly
          final paidEntries = entries.where((doc) => 
            doc.data().toString().contains('isPaid') && doc['isPaid'] == true
          ).length;
          final paymentRate =
              entries.isEmpty ? 0.0 : (paidEntries / entries.length) * 100;

          // Prepare data for line chart
          final Map<DateTime, double> dailyTotals = {};
          for (var doc in entries) {
            DateTime entryDate;
            if (doc['date'] is Timestamp) {
              entryDate = (doc['date'] as Timestamp).toDate();
            } else if (doc['date'] is String) {
              entryDate = DateTime.parse(doc['date']);
            } else {
              continue;
            }
            final dateKey = DateTime(entryDate.year, entryDate.month, entryDate.day);
            dailyTotals[dateKey] =
                (dailyTotals[dateKey] ?? 0) + (doc['amount'] as num).toDouble();
          }

          final sortedDates = dailyTotals.keys.toList()..sort();
          final spots = List.generate(
            sortedDates.length,
            (index) =>
                FlSpot(index.toDouble(), dailyTotals[sortedDates[index]]!),
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Summary',
                  style: TextStyle(
                    color: themeProvider.textColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildSummaryCard(
                      'Total Outstanding',
                      '₹${totalAmount.toStringAsFixed(2)}',
                      Icons.account_balance_wallet,
                      Colors.blue,
                      themeProvider,
                    ),
                    _buildSummaryCard(
                      'Average Amount',
                      '₹${averageAmount.toStringAsFixed(2)}',
                      Icons.trending_up,
                      Colors.green,
                      themeProvider,
                    ),
                    _buildSummaryCard(
                      'Total Entries',
                      entries.length.toString(),
                      Icons.receipt_long,
                      Colors.orange,
                      themeProvider,
                    ),
                    _buildSummaryCard(
                      'Payment Rate',
                      '${paymentRate.toStringAsFixed(1)}%',
                      Icons.payments,
                      Colors.purple,
                      themeProvider,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Daily Udhari Trend',
                  style: TextStyle(
                    color: themeProvider.textColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildLineChart(spots, themeProvider, sortedDates),
              ],
            ),
          );
        },
      ),
    );
  }
}
