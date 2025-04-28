import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/theme_provider.dart';
import '../models/udhari_entry.dart';

class UdhariListScreen extends StatelessWidget {
  final Stream<QuerySnapshot> _udhariStream;

  UdhariListScreen({super.key})
    : _udhariStream =
          FirebaseFirestore.instance
              .collection('udhari_entries')
              .where(
                'shopId',
                isEqualTo: FirebaseAuth.instance.currentUser?.uid,
              )
              .orderBy('date', descending: true)
              .snapshots();

  Widget _buildUdhariCard(
    UdhariEntry entry,
    ThemeProvider themeProvider,
    BuildContext context,
  ) {
    String formattedDate =
        "${entry.date.day}/${entry.date.month}/${entry.date.year}";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: themeProvider.isDarkMode ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.withOpacity(0.2),
          child: Text(
            entry.name[0],
            style: const TextStyle(color: Colors.blue),
          ),
        ),
        title: Text(
          entry.name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: themeProvider.textColor,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              formattedDate,
              style: TextStyle(
                color: themeProvider.textColor.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
            Text(
              entry.contact,
              style: TextStyle(
                color: themeProvider.textColor.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '₹${entry.amount.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.check_circle, color: Colors.green),
              onPressed: () => _showPaymentDialog(context, entry),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPaymentDialog(
    BuildContext context,
    UdhariEntry entry,
  ) async {
    try {
      await showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Mark as Paid'),
              content: Text(
                'Confirm payment of ₹${entry.amount} from ${entry.name}?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('CANCEL'),
                ),
                TextButton(
                  onPressed: () async {
                    try {
                      // Start a batch
                      final batch = FirebaseFirestore.instance.batch();

                      // Delete the udhari entry
                      batch.delete(
                        FirebaseFirestore.instance
                            .collection('udhari_entries')
                            .doc(entry.id),
                      );

                      // Update customer's total udhari
                      final customerRef = FirebaseFirestore.instance
                          .collection('customers')
                          .doc(entry.contact);

                      final customerDoc = await customerRef.get();
                      if (customerDoc.exists) {
                        final currentTotal =
                            (customerDoc.data()?['totalUdhari'] ?? 0)
                                .toDouble();
                        batch.update(customerRef, {
                          'totalUdhari': currentTotal - entry.amount,
                          'lastUpdated': FieldValue.serverTimestamp(),
                        });
                      }

                      // Commit the batch
                      await batch.commit();

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Payment marked as completed'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('CONFIRM'),
                ),
              ],
            ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: themeProvider.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: const Text('Udhari List'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              // Add filter functionality later
            },
          ),
        ],
      ),
      body: FutureBuilder(
        // Wait for index to be ready
        future: FirebaseFirestore.instance.waitForPendingWrites(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Setting up the database...\nThis may take a moment.'),
                ],
              ),
            );
          }

          return StreamBuilder<QuerySnapshot>(
            stream: _udhariStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final entries =
                  snapshot.data?.docs
                      .map((doc) => UdhariEntry.fromFirestore(doc))
                      .toList() ??
                  [];

              if (entries.isEmpty) {
                return Center(
                  child: Text(
                    'No udhari entries found',
                    style: TextStyle(color: themeProvider.textColor),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  return _buildUdhariCard(
                    entries[index],
                    themeProvider,
                    context,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
