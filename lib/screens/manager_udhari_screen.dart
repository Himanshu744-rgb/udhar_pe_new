import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UdhariEntry {
  final String id;
  final String name;
  final String contact;
  final double amount;

  UdhariEntry({
    required this.id,
    required this.name,
    required this.contact,
    required this.amount,
  });

  // Convert to JSON for Firestore
  Map<String, dynamic> toJson() => {
    'name': name,
    'contact': contact,
    'amount': amount,
  };

  // Create from Firestore document
  factory UdhariEntry.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return UdhariEntry(
      id: doc.id,
      name: data['name'] ?? '',
      contact: data['contact'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
    );
  }
}

class ManagerUdhariScreen extends StatefulWidget {
  const ManagerUdhariScreen({Key? key}) : super(key: key);

  @override
  State<ManagerUdhariScreen> createState() => _ManagerUdhariScreenState();
}

class _ManagerUdhariScreenState extends State<ManagerUdhariScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  // Sample data
  final List<UdhariEntry> _sampleEntries = [
    UdhariEntry(id: '1', name: 'Manil Patiwar', contact: '+91', amount: 500),
    UdhariEntry(
      id: '2',
      name: 'Himanshu maliani',
      contact: '+91',
      amount: 1500,
    ),
  ];

  // Reference to Firestore collection
  final CollectionReference _udhariCollection = FirebaseFirestore.instance
      .collection('udhari_entries');

  // Update the stream to remove date ordering
  Stream<QuerySnapshot> get _udhariStream => _udhariCollection.snapshots();

  Future<void> _addUdhariEntry() async {
    if (_nameController.text.isEmpty ||
        _contactController.text.isEmpty ||
        _amountController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    final amount = double.tryParse(_amountController.text);
    if (amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    try {
      await _udhariCollection.add({
        'name': _nameController.text,
        'contact': _contactController.text,
        'amount': amount,
      });

      // Clear the form
      _nameController.clear();
      _contactController.clear();
      _amountController.clear();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error adding entry: $e')));
    }
  }

  Future<void> _markAsPaid(String documentId) async {
    try {
      await _udhariCollection.doc(documentId).delete();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error removing entry: $e')));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Widget _buildUdhariList(ThemeProvider themeProvider) {
    return StreamBuilder<QuerySnapshot>(
      stream: _udhariStream,
      builder: (context, snapshot) {
        List<UdhariEntry> entries = [];

        // Add sample entries for initial display
        entries.addAll(_sampleEntries);

        // Add Firebase entries if available
        if (snapshot.hasData) {
          entries.addAll(
            snapshot.data!.docs.map((doc) => UdhariEntry.fromFirestore(doc)),
          );
        }

        if (entries.isEmpty) {
          return Center(
            child: Text(
              'No udhari entries yet',
              style: TextStyle(color: themeProvider.textColor),
            ),
          );
        }

        return ListView.builder(
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final entry = entries[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color:
                    themeProvider.isDarkMode ? Colors.grey[800] : Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    // Amount section
                    Container(
                      width: 80,
                      child: Text(
                        '₹${entry.amount.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: themeProvider.textColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Customer info section
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: Colors.blue.withOpacity(0.2),
                                child: Text(
                                  entry.name[0],
                                  style: const TextStyle(
                                    color: Colors.blue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                entry.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: themeProvider.textColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            entry.contact,
                            style: TextStyle(
                              fontSize: 12,
                              color: themeProvider.textColor.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Paid button
                    ElevatedButton(
                      onPressed: () => _markAsPaid(entry.id),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      child: const Text('Paid'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: themeProvider.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: const Text(
          'Manage Udhari',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Track and add udhari for your customers.',
              style: TextStyle(fontSize: 16, color: themeProvider.textColor),
            ),
            const SizedBox(height: 20),
            // Input form
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Name',
                filled: true,
                fillColor:
                    themeProvider.isDarkMode ? Colors.grey[800] : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: Icon(Icons.clear, color: Colors.grey),
              ),
              style: TextStyle(color: themeProvider.textColor),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contactController,
              decoration: InputDecoration(
                labelText: 'Contact details',
                filled: true,
                fillColor:
                    themeProvider.isDarkMode ? Colors.grey[800] : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: Icon(Icons.clear, color: Colors.grey),
              ),
              style: TextStyle(color: themeProvider.textColor),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              decoration: InputDecoration(
                labelText: 'Amount',
                filled: true,
                fillColor:
                    themeProvider.isDarkMode ? Colors.grey[800] : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: Icon(Icons.clear, color: Colors.grey),
              ),
              keyboardType: TextInputType.number,
              style: TextStyle(color: themeProvider.textColor),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: _addUdhariEntry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                child: const Text('Add'),
              ),
            ),
            const SizedBox(height: 24),
            // Udhari list
            Expanded(child: _buildUdhariList(themeProvider)),
          ],
        ),
      ),
    );
  }
}
