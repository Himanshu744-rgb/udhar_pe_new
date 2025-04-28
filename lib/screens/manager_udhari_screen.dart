import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UdhariEntry {
  final String id;
  final String name;
  final String contact;
  final double amount;
  final DateTime date; // Add date field
  final String shopId; // Add shop ID field
  final String shopName; // Add shop name field

  UdhariEntry({
    required this.id,
    required this.name,
    required this.contact,
    required this.amount,
    required this.date,
    required this.shopId,
    required this.shopName,
  });

  // Convert to JSON for Firestore
  Map<String, dynamic> toJson() => {
    'name': name,
    'contact': contact,
    'amount': amount,
    'date': date.toIso8601String(), // Store date as string
    'shopId': shopId,
    'shopName': shopName,
  };

  // Create from Firestore document
  factory UdhariEntry.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return UdhariEntry(
      id: doc.id,
      name: data['name'] ?? '',
      contact: data['contact'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      date: DateTime.parse(data['date'] ?? DateTime.now().toIso8601String()),
      shopId: data['shopId'] ?? '',
      shopName: data['shopName'] ?? '',
    );
  }
}

class ManagerUdhariScreen extends StatefulWidget {
  final String? initialCustomerPhone;
  final String? initialCustomerName;
  
  const ManagerUdhariScreen({
    Key? key,
    this.initialCustomerPhone,
    this.initialCustomerName,
  }) : super(key: key);

  @override
  State<ManagerUdhariScreen> createState() => _ManagerUdhariScreenState();
}

class _ManagerUdhariScreenState extends State<ManagerUdhariScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  DateTime _selectedDate = DateTime.now(); // Add this line
  String _shopName = 'Loading...'; // Add this line
  String? _contactError;

  @override
  void initState() {
    super.initState();
    _loadShopName();
    
    // Initialize with customer data if provided
    if (widget.initialCustomerPhone != null && widget.initialCustomerPhone!.isNotEmpty) {
      _contactController.text = widget.initialCustomerPhone!;
      // Pre-validate the phone number
      _validatePhoneNumber(widget.initialCustomerPhone!);
    }
    
    if (widget.initialCustomerName != null && widget.initialCustomerName!.isNotEmpty) {
      _nameController.text = widget.initialCustomerName!;
    }
  }

  Future<void> _loadShopName() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final shopDoc =
            await FirebaseFirestore.instance
                .collection('shops')
                .doc(user.uid)
                .get();

        if (mounted) {
          setState(() {
            _shopName = shopDoc.data()?['name'] ?? 'Unknown Shop';
          });
        }
      }
    } catch (e) {
      print('Error loading shop name: $e');
    }
  }
  
  // Check if a customer exists with the given phone number
  Future<Map<String, dynamic>?> _checkCustomerExists(String phoneNumber) async {
    try {
      print('Checking if customer exists with phone number: $phoneNumber');
      
      // Check in customers collection
      final customerDoc = await FirebaseFirestore.instance
          .collection('customers')
          .doc(phoneNumber)
          .get();
      
      if (customerDoc.exists) {
        print('Customer found in customers collection');
        return customerDoc.data();
      }
      
      // If not found in customers collection, check in users collection
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('phone', isEqualTo: phoneNumber)
          .limit(1)
          .get();
      
      if (usersSnapshot.docs.isNotEmpty) {
        print('User found in users collection');
        return usersSnapshot.docs.first.data();
      }
      
      // Additional check: try with different phone number formats
      if (phoneNumber.startsWith('+91')) {
        // Try without the +91 prefix
        final phoneWithoutPrefix = phoneNumber.substring(3);
        final altUsersSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('phone', isEqualTo: phoneWithoutPrefix)
            .limit(1)
            .get();
            
        if (altUsersSnapshot.docs.isNotEmpty) {
          print('User found in users collection with alternative format');
          return altUsersSnapshot.docs.first.data();
        }
      } else if (!phoneNumber.startsWith('+')) {
        // Try with +91 prefix if it doesn't already have a + prefix
        final phoneWithPrefix = '+91$phoneNumber';
        final altUsersSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('phone', isEqualTo: phoneWithPrefix)
            .limit(1)
            .get();
            
        if (altUsersSnapshot.docs.isNotEmpty) {
          print('User found in users collection with added prefix');
          return altUsersSnapshot.docs.first.data();
        }
      }
      
      print('No user found with phone number: $phoneNumber');
      // No user found with this phone number
      return null;
    } catch (e) {
      print('Error checking customer: $e');
      return null;
    }
  }
  
  // Validate phone number format and existence
  Future<bool> _validatePhoneNumber(String phoneNumber) async {
    // Reset any previous error
    setState(() {
      _contactError = null;
    });
    
    // First check if the format is valid
    if (phoneNumber.isEmpty) {
      setState(() {
        _contactError = 'Phone number cannot be empty';
      });
      return false;
    }
    
    // Remove any non-digit characters except the + prefix
    if (phoneNumber.startsWith('+')) {
      String plus = '+';
      phoneNumber = plus + phoneNumber.substring(1).replaceAll(RegExp(r'\D'), '');
    } else {
      phoneNumber = phoneNumber.replaceAll(RegExp(r'\D'), '');
    }
    
    // Check if the number is valid (10 digits for Indian numbers without prefix)
    String digitsOnly = phoneNumber.startsWith('+') ? phoneNumber.substring(1) : phoneNumber;
    digitsOnly = digitsOnly.startsWith('91') ? digitsOnly.substring(2) : digitsOnly;
    
    if (digitsOnly.length != 10) {
      setState(() {
        _contactError = 'Please enter a valid 10-digit number';
      });
      return false;
    }
    
    // Normalize phone number format with +91 prefix, ensuring we don't add it twice
    if (phoneNumber.startsWith('+91')) {
      // Already has the correct format
    } else if (phoneNumber.startsWith('91')) {
      phoneNumber = '+$phoneNumber';
    } else if (phoneNumber.startsWith('+')) {
      phoneNumber = '+91${phoneNumber.substring(1)}';
    } else {
      phoneNumber = '+91$phoneNumber';
    }
    
    // Check if user exists in Firebase - but don't update the name field
    final customerData = await _checkCustomerExists(phoneNumber);
    if (customerData == null) {
      setState(() {
        _contactError = 'This phone number is not registered on Udhar Pe. Cannot add udhari for unregistered users.';
      });
      return false;
    }
    
    // Don't update the name field with the name from Firebase
    // Keep the name that the user entered
    
    // Clear any error if validation passes
    setState(() {
      _contactError = null;
    });
    
    return true;
  }

  // Sample data
  final List<UdhariEntry> _sampleEntries = [
    UdhariEntry(
      id: '1',
      name: 'Manil Patiwar',
      contact: '+91',
      amount: 500,
      date: DateTime.now(),
      shopId: '1',
      shopName: 'Shop 1',
    ),
    UdhariEntry(
      id: '2',
      name: 'Himanshu maliani',
      contact: '+91',
      amount: 1500,
      date: DateTime.now(),
      shopId: '2',
      shopName: 'Shop 2',
    ),
  ];

  // Reference to Firestore collection
  final CollectionReference _udhariCollection = FirebaseFirestore.instance
      .collection('udhari_entries');

  // Update the stream to remove date ordering
  Stream<QuerySnapshot> get _udhariStream => _udhariCollection.snapshots();

  Future<void> _addUdhariEntry() async {
    // Check if fields are empty
    if (_nameController.text.isEmpty ||
        _contactController.text.isEmpty ||
        _amountController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }
    
    // Validate phone number format and existence
    String phoneNumber = _contactController.text.trim();
    
    // Validate the phone number using the validation function
    bool isValid = await _validatePhoneNumber(phoneNumber);
    if (!isValid) {
      // Error message is already set in the _validatePhoneNumber function
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_contactError ?? 'Invalid phone number'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Remove any non-digit characters except the + prefix
    if (phoneNumber.startsWith('+')) {
      String plus = '+';
      phoneNumber = plus + phoneNumber.substring(1).replaceAll(RegExp(r'\D'), '');
    } else {
      phoneNumber = phoneNumber.replaceAll(RegExp(r'\D'), '');
    }
    
    // Normalize phone number format with +91 prefix, ensuring we don't add it twice
    if (phoneNumber.startsWith('+91')) {
      // Already has the correct format
    } else if (phoneNumber.startsWith('91')) {
      phoneNumber = '+$phoneNumber';
    } else if (phoneNumber.startsWith('+')) {
      phoneNumber = '+91${phoneNumber.substring(1)}';
    } else {
      phoneNumber = '+91$phoneNumber';
    }
    
    // Double-check that the user exists before proceeding, but don't use the returned data
    final customerExists = await _checkCustomerExists(phoneNumber) != null;
    if (!customerExists) {
      setState(() {
        _contactError = 'This phone number is not registered on Udhar Pe. Cannot add udhari for unregistered users.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_contactError!),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Always use the name entered by the shopkeeper
      final String customerName = _nameController.text.trim();

      // First check if customer exists in customers collection
      final customerDoc =
          await FirebaseFirestore.instance
              .collection('customers')
              .doc(phoneNumber)
              .get();
              
      // Create the udhari data with the selected date
      final udhariData = {
        'name': customerName,  // Use the name entered by shopkeeper
        'contact': phoneNumber,
        'amount': double.parse(_amountController.text),
        'date': _selectedDate.toIso8601String(), // Use selected date
        'shopId': user.uid,
        'shopName': _shopName,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'customerId': phoneNumber,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Start a batch write
      WriteBatch batch = FirebaseFirestore.instance.batch();

      // Add udhari entry
      DocumentReference udhariRef = _udhariCollection.doc();
      batch.set(udhariRef, udhariData);

      // Update or create customer document
      DocumentReference customerRef = FirebaseFirestore.instance
          .collection('customers')
          .doc(phoneNumber);

      if (!customerDoc.exists) {
        batch.set(customerRef, {
          'name': customerName,  // Use the name entered by shopkeeper
          'phoneNumber': phoneNumber,
          'totalUdhari': double.parse(_amountController.text),
          'lastUpdated': FieldValue.serverTimestamp(),
          'associatedShops': [user.uid],
          'lastUdhariDate': _selectedDate.toIso8601String(), // Add this line
        });
      } else {
        final currentTotal =
            (customerDoc.data()?['totalUdhari'] ?? 0).toDouble();
        final shops = List<String>.from(
          customerDoc.data()?['associatedShops'] ?? [],
        );

        if (!shops.contains(user.uid)) {
          shops.add(user.uid);
        }

        batch.update(customerRef, {
          'totalUdhari': currentTotal + double.parse(_amountController.text),
          'lastUpdated': FieldValue.serverTimestamp(),
          'associatedShops': shops,
          'name': customerName,  // Use the name entered by shopkeeper
          'lastUdhariDate': _selectedDate.toIso8601String(), // Add this line
        });
      }

      await batch.commit();

      // Clear form and show success message
      _nameController.clear();
      _contactController.clear();
      _amountController.clear();
      setState(() {
        _selectedDate =
            DateTime.now(); // Reset date to current after successful entry
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Udhari added for ${_selectedDate.toString().split(' ')[0]}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error adding entry: $e')));
      }
    }
  }

  Future<void> _markAsPaid(String documentId) async {
    try {
      // Get the udhari entry first
      final udhariDoc = await _udhariCollection.doc(documentId).get();
      final udhariData = udhariDoc.data() as Map<String, dynamic>;

      // Show confirmation dialog
      final confirm = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Confirm Payment'),
              content: Text(
                'Mark payment of ₹${udhariData['amount']} as paid?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Confirm'),
                ),
              ],
            ),
      );

      if (confirm == true) {
        // Start a batch write
        final batch = FirebaseFirestore.instance.batch();

        // Move the udhari entry to paid_udhari collection instead of deleting
        final paidUdhariRef =
            FirebaseFirestore.instance.collection('paid_udhari').doc();

        batch.set(paidUdhariRef, {
          ...udhariData,
          'paidAt': FieldValue.serverTimestamp(),
          'status': 'paid',
        });

        // Delete from active udhari
        batch.delete(_udhariCollection.doc(documentId));

        // Update customer's total udhari
        final customerRef = FirebaseFirestore.instance
            .collection('customers')
            .doc(udhariData['contact']);

        final customerDoc = await customerRef.get();
        if (customerDoc.exists) {
          final currentTotal =
              (customerDoc.data()?['totalUdhari'] ?? 0).toDouble();
          final newTotal = currentTotal - (udhariData['amount'] ?? 0);

          batch.update(customerRef, {
            'totalUdhari': newTotal,
            'lastUpdated': FieldValue.serverTimestamp(),
            'lastPaymentDate': FieldValue.serverTimestamp(),
          });
        }

        // Commit all changes
        await batch.commit();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment recorded successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error recording payment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final ThemeProvider themeProvider = Provider.of<ThemeProvider>(
      context,
      listen: false,
    );

    // Use more efficient DatePickerEntryMode and DatePickerMode settings
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(
        const Duration(days: 1),
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue,
              onPrimary: Colors.white,
              surface: themeProvider.backgroundColor,
              onSurface: themeProvider.textColor,
            ),
            dialogBackgroundColor: themeProvider.backgroundColor,
          ),
          child: child!,
        );
      },
      // Optimize for faster selection
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      initialDatePickerMode: DatePickerMode.day,
    );

    // Optimize state update by checking if date actually changed
    if (picked != null && mounted && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  Widget _buildDateSelector(ThemeProvider themeProvider) {
    return InkWell(
      onTap: () => _selectDate(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: themeProvider.isDarkMode ? Colors.grey[800] : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.withOpacity(0.3), width: 1),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today,
              color:
                  themeProvider.isDarkMode ? Colors.white70 : Colors.grey[600],
              size: 20,
            ),
            const SizedBox(width: 12),
            // Use a more efficient text display that doesn't trigger unnecessary rebuilds
            Text(
              '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
              style: TextStyle(color: themeProvider.textColor, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Widget _buildUdhariList(ThemeProvider themeProvider) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Container();

    return StreamBuilder<QuerySnapshot>(
      // Modify the query to use only where clause initially
      stream:
          FirebaseFirestore.instance
              .collection('udhari_entries')
              .where('shopId', isEqualTo: user.uid)
              .snapshots(),
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

        // Sort entries by createdAt on client side
        entries.sort((a, b) => b.date.compareTo(a.date));

        if (entries.isEmpty) {
          return Center(
            child: Text(
              'No udhari entries yet',
              style: TextStyle(color: themeProvider.textColor),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: entries.length,
          itemBuilder: (context, index) {
            return _buildUdhariCard(entries[index], themeProvider);
          },
        );
      },
    );
  }

  Widget _buildUdhariCard(UdhariEntry entry, ThemeProvider themeProvider) {
    String formattedDate =
        entry.date != null
            ? "${entry.date.day}/${entry.date.month}/${entry.date.year}"
            : "Date not available";

    return InkWell(
      onTap: () => _showUdhariDetails(entry, themeProvider),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: themeProvider.isDarkMode ? Colors.grey[800] : Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: themeProvider.textColor,
                          ),
                        ),
                        Text(
                          formattedDate,
                          style: TextStyle(
                            fontSize: 12,
                            color: themeProvider.textColor.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
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
                  TextButton.icon(
                    onPressed: () => _markAsPaid(entry.id),
                    icon: const Icon(Icons.check_circle, color: Colors.green),
                    label: const Text(
                      'Mark as Paid',
                      style: TextStyle(color: Colors.green),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      backgroundColor: Colors.green.withOpacity(0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _showUdhariDetails(UdhariEntry entry, ThemeProvider themeProvider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: themeProvider.backgroundColor,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(20),
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Udhari Details',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: themeProvider.textColor,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 16),
            
            // Customer Avatar and Name
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.blue.withOpacity(0.2),
                  child: Text(
                    entry.name[0],
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.name,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: themeProvider.textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.phone, 
                          size: 16, 
                          color: themeProvider.textColor.withOpacity(0.7),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          entry.contact,
                          style: TextStyle(
                            fontSize: 16,
                            color: themeProvider.textColor.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Amount
            _detailItem(
              themeProvider,
              Icons.currency_rupee,
              'Amount',
              '₹${entry.amount.toStringAsFixed(2)}',
              Colors.blue,
            ),
            
            // Date
            _detailItem(
              themeProvider,
              Icons.calendar_today,
              'Date',
              '${entry.date.day}/${entry.date.month}/${entry.date.year}',
              Colors.orange,
            ),
            
            // Transaction ID removed as per requirement
            
            // Shop Name
            _detailItem(
              themeProvider,
              Icons.store,
              'Shop',
              entry.shopName,
              Colors.green,
            ),
            
            // Status
            _detailItem(
              themeProvider,
              Icons.pending_actions,
              'Status',
              'Pending',
              Colors.red,
            ),
            
            const Spacer(),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _markAsPaid(entry.id),
                    icon: const Icon(Icons.check_circle, color: Colors.white),
                    label: const Text(
                      'Mark as Paid',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _detailItem(ThemeProvider themeProvider, IconData icon, String label, String value, Color iconColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: themeProvider.textColor.withOpacity(0.7),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: themeProvider.textColor,
                ),
              ),
            ],
          ),
        ],
      ),
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
      body: Column(
        children: [
          // Add a container for top section
          Container(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Track and add udhari for your customers.',
                  style: TextStyle(
                    fontSize: 16,
                    color: themeProvider.textColor,
                  ),
                ),
                const SizedBox(height: 20),
                // Add button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      // Show bottom sheet for adding udhari
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder:
                            (context) => Container(
                              height: MediaQuery.of(context).size.height * 0.85,
                              decoration: BoxDecoration(
                                color: themeProvider.backgroundColor,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(20),
                                ),
                              ),
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Add New Udhari',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: themeProvider.textColor,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.close),
                                        onPressed: () => Navigator.pop(context),
                                      ),
                                    ],
                                  ),
                                  const Divider(),
                                  Expanded(
                                    child: SingleChildScrollView(
                                      child: Column(
                                        children: [
                                          // Reuse existing form fields
                                          TextField(
                                            controller: _nameController,
                                            decoration: InputDecoration(
                                              labelText: 'Name',
                                              filled: true,
                                              fillColor:
                                                  themeProvider.isDarkMode
                                                      ? Colors.grey[800]
                                                      : Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          TextField(
                                            controller: _contactController,
                                            decoration: InputDecoration(
                                              labelText: 'Contact details',
                                              hintText: 'Enter 10-digit number of registered user',
                                              filled: true,
                                              fillColor:
                                                  themeProvider.isDarkMode
                                                      ? Colors.grey[800]
                                                      : Colors.white,
                                              prefixText: '+91 ',
                                              errorText: _contactError,
                                              helperText: 'User must be registered on Udhar Pe',
                                              helperStyle: TextStyle(
                                                fontSize: 12,
                                                color: themeProvider.isDarkMode
                                                    ? Colors.grey[400]
                                                    : Colors.grey[600],
                                              ),
                                            ),
                                            keyboardType: TextInputType.number,
                                            onChanged: (value) async {
                                              // Clear error when user types
                                              if (_contactError != null) {
                                                setState(() {
                                                  _contactError = null;
                                                });
                                              }
                                              
                                              // Auto-fetch customer details if phone number is valid
                                              if (value.length >= 10) {
                                                // Normalize phone number format
                                                String phoneNumber = value.trim();
                                                if (phoneNumber.startsWith('+')) {
                                                  String plus = '+';
                                                  phoneNumber = plus + phoneNumber.substring(1).replaceAll(RegExp(r'\D'), '');
                                                } else {
                                                  phoneNumber = phoneNumber.replaceAll(RegExp(r'\D'), '');
                                                }
                                                
                                                // Ensure proper format with +91 prefix
                                                if (phoneNumber.startsWith('+91')) {
                                                  // Already has the correct format
                                                } else if (phoneNumber.startsWith('91')) {
                                                  phoneNumber = '+$phoneNumber';
                                                } else if (phoneNumber.startsWith('+')) {
                                                  phoneNumber = '+91${phoneNumber.substring(1)}';
                                                } else {
                                                  phoneNumber = '+91$phoneNumber';
                                                }
                                                
                                                // Show loading indicator
                                                setState(() {
                                                  _contactError = 'Searching for customer...';
                                                });
                                                
                                                // Check if customer exists and fetch details
                                                final customerData = await _checkCustomerExists(phoneNumber);
                                                if (customerData != null) {
                                                  // Customer found, do not auto-fill name field
                                                  setState(() {
                                                    _contactError = null; // Clear the searching message
                                                  });
                                                } else {
                                                  // No customer found
                                                  setState(() {
                                                    _contactError = 'This phone number is not registered on Udhar Pe';
                                                  });
                                                }
                                              }
                                            },
                                          ),
                                          const SizedBox(height: 12),
                                          TextField(
                                            controller: _amountController,
                                            decoration: InputDecoration(
                                              labelText: 'Amount',
                                              filled: true,
                                              fillColor:
                                                  themeProvider.isDarkMode
                                                      ? Colors.grey[800]
                                                      : Colors.white,
                                            ),
                                            keyboardType: TextInputType.number,
                                          ),
                                          const SizedBox(height: 12),
                                          // Date picker
                                          _buildDateSelector(themeProvider),
                                        ],
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: () {
                                        _addUdhariEntry();
                                        Navigator.pop(context);
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 15,
                                        ),
                                      ),
                                      child: const Text('Add Udhari'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Add New Udhari',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16), // Add extra spacing
          // Recent Udhari section
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color:
                    themeProvider.isDarkMode
                        ? Colors.grey[900]
                        : Colors.grey[100],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Text(
                          'Recent Udhari Entries',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: themeProvider.textColor,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: () {
                            // Add refresh functionality if needed
                          },
                        ),
                      ],
                    ),
                  ),
                  Expanded(child: _buildUdhariList(themeProvider)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
