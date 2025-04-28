import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import '../providers/theme_provider.dart';
import '../services/firebase_service.dart';
import '../services/payment_service.dart';
import 'select_user_type.dart';

class CustomerHomeScreen extends StatefulWidget {
  CustomerHomeScreen({super.key});

  @override
  _CustomerHomeScreenState createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final user = FirebaseAuth.instance.currentUser;
  final Map<String, int> _shopCounts = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot> getUdhariStream() {
    if (user == null) return Stream.empty();

    return FirebaseFirestore.instance
        .collection('customers')
        .where('email', isEqualTo: user?.email)
        .snapshots()
        .asyncMap((customerSnapshot) async {
          if (customerSnapshot.docs.isEmpty) {
            print("Debug - No customer found for email: ${user?.email}");
            // Try to find customer by UID instead
            final userDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(user!.uid)
                .get();
            
            if (userDoc.exists && userDoc.data()?['phone'] != null) {
              String phoneNumber = userDoc.data()?['phone'] as String;
              print("Debug - Found phone number from users collection: $phoneNumber");
              
              // Try different phone number formats
              List<String> phoneFormats = [phoneNumber];
              
              // Add version without +91 prefix if it exists
              if (phoneNumber.startsWith('+91')) {
                phoneFormats.add(phoneNumber.substring(3));
                // Handle the case of double +91 prefix
                if (phoneNumber.startsWith('+91+91')) {
                  phoneFormats.add(phoneNumber.substring(6));
                  phoneFormats.add('+91${phoneNumber.substring(6)}');
                }
              }
              // Add version with +91 prefix if it doesn't have one
              else if (!phoneNumber.startsWith('+')) {
                phoneFormats.add('+91$phoneNumber');
              }
              
              print("Debug - Trying phone formats: $phoneFormats");
              
              // Query for any of the phone formats
              final querySnapshot = await FirebaseFirestore.instance
                  .collection('udhari_entries')
                  .where('contact', whereIn: phoneFormats)
                  .get();
                  
              print("Debug - Found ${querySnapshot.docs.length} entries");
              return querySnapshot;
            }
            
            return FirebaseFirestore.instance
                .collection('udhari_entries')
                .limit(0)
                .get();
          }

          final customerDoc = customerSnapshot.docs.first;
          final phoneNumber = customerDoc.data()['phoneNumber'] as String?;
          print("Debug - Customer phone number: $phoneNumber");

          if (phoneNumber == null) {
            print("Debug - Phone number is null, no udhari entries will be shown");
            return FirebaseFirestore.instance
                .collection('udhari_entries')
                .limit(0)
                .get();
          }

          // Try different phone number formats
          List<String> phoneFormats = [phoneNumber];
          
          // Add version without +91 prefix if it exists
          if (phoneNumber.startsWith('+91')) {
            phoneFormats.add(phoneNumber.substring(3));
            // Handle the case of double +91 prefix
            if (phoneNumber.startsWith('+91+91')) {
              phoneFormats.add(phoneNumber.substring(6));
              phoneFormats.add('+91${phoneNumber.substring(6)}');
            }
          }
          // Add version with +91 prefix if it doesn't have one
          else if (!phoneNumber.startsWith('+')) {
            phoneFormats.add('+91$phoneNumber');
          }
          
          print("Debug - Trying phone formats: $phoneFormats");
          
          // Query for any of the phone formats
          final querySnapshot = await FirebaseFirestore.instance
              .collection('udhari_entries')
              .where('contact', whereIn: phoneFormats)
              .get();
              
          print("Debug - Found ${querySnapshot.docs.length} entries");
          return querySnapshot;
        });
  }

  // Function to filter entries based on search
  List<Map<String, dynamic>> _filterEntries(
    List<Map<String, dynamic>> entries,
  ) {
    if (_searchQuery.isEmpty) return entries;

    return entries.where((entry) {
      final shopName = entry['name'].toString().toLowerCase();
      final amount = entry['amount'].toString().toLowerCase();
      final searchLower = _searchQuery.toLowerCase();

      return shopName.contains(searchLower) || amount.contains(searchLower);
    }).toList();
  }

  Future<int> getShopCountForCustomer(String customerId) async {
    try {
      // First check if we already have the count in our map
      if (_shopCounts.containsKey(customerId)) {
        return _shopCounts[customerId]!;
      }
      
      // Use a Set to count unique shop IDs
      final Set<String> uniqueShopIds = {};
      
      // Query to get distinct shops for this customer using customerId
      final QuerySnapshot customerIdQuery = await FirebaseFirestore.instance
          .collection('udhari_entries')
          .where('customerId', isEqualTo: customerId)
          .get();
      
      // Add shop IDs from customerId query
      for (var doc in customerIdQuery.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['shopId'] != null && data['shopId'].toString().isNotEmpty) {
          uniqueShopIds.add(data['shopId'].toString());
        }
      }
      
      // For pre-existing accounts, also check the contact field
      final QuerySnapshot contactQuery = await FirebaseFirestore.instance
          .collection('udhari_entries')
          .where('contact', isEqualTo: customerId)
          .get();
      
      // Add shop IDs from contact query (for pre-existing accounts)
      for (var doc in contactQuery.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['shopId'] != null && data['shopId'].toString().isNotEmpty) {
          uniqueShopIds.add(data['shopId'].toString());
        }
      }
      
      // Store the count in our map for future use
      _shopCounts[customerId] = uniqueShopIds.length;
      
      return uniqueShopIds.length;
    } catch (e) {
      print("Error getting shop count: $e");
      return 0;
    }
  }

  // Add a method to fetch shopkeeper's phone number from Firebase
  Future<String> _fetchShopkeeperPhone(String shopId, Map<String, dynamic> entry) async {
    try {
      print('DEBUG: Fetching phone for shopId: $shopId');
      
      // First, try to get the phone number directly from the users collection
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('userType', isEqualTo: 'Shopkeeper')
          .get();
          
      print('DEBUG: Found ${usersSnapshot.docs.length} shopkeeper users');
      
      // If we have a shopId, try to match it directly
      if (shopId.isNotEmpty) {
        for (var userDoc in usersSnapshot.docs) {
          if (userDoc.id == shopId) {
            final phone = userDoc.data()['phone'] ?? '';
            print('DEBUG: Found phone by direct user ID match: $phone');
            if (phone.isNotEmpty) {
              return phone;
            }
          }
        }
      }
      
      // Try to match by shop name
      final shopName = entry['name']?.toString() ?? '';
      if (shopName.isNotEmpty && shopName != 'Unknown Shop') {
        for (var userDoc in usersSnapshot.docs) {
          if (userDoc.data()['name'] == shopName || userDoc.data()['shopName'] == shopName) {
            final phone = userDoc.data()['phone'] ?? '';
            print('DEBUG: Found phone by shop name match: $phone');
            if (phone.isNotEmpty) {
              return phone;
            }
          }
        }
      }
      
      // As a last resort, check the udhari_entries to find the shopkeeper
      final udhariSnapshot = await FirebaseFirestore.instance
          .collection('udhari_entries')
          .get();
          
      print('DEBUG: Found ${udhariSnapshot.docs.length} udhari entries');
      
      // Find the shopkeeper who created this udhari entry
      for (var udhariDoc in udhariSnapshot.docs) {
        final udhariData = udhariDoc.data();
        
        // Check if this is the udhari entry we're looking at
        if (udhariData['shopName'] == shopName) {
          final shopkeeperId = udhariData['shopId']?.toString() ?? '';
          
          if (shopkeeperId.isNotEmpty) {
            // Get the shopkeeper's user document
            final shopkeeperDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(shopkeeperId)
                .get();
                
            if (shopkeeperDoc.exists) {
              final phone = shopkeeperDoc.data()?['phone'] ?? '';
              print('DEBUG: Found phone from udhari shopkeeper: $phone');
              if (phone.isNotEmpty) {
                return phone;
              }
            }
          }
        }
      }
      
      // If nothing worked, try to get the phone directly from the entry
      final directPhone = entry['shopPhone']?.toString() ?? 
                         entry['phone']?.toString() ?? 
                         '';
      
      if (directPhone.isNotEmpty) {
        print('DEBUG: Using direct phone from entry: $directPhone');
        return directPhone;
      }
      
      print('DEBUG: No phone number found through any method');
      return '';
    } catch (e) {
      print('Error fetching shopkeeper phone: $e');
      return '';
    }
  }

  // Helper method to format phone number (remove +91 if present)
  String _formatPhoneForCopy(String phone) {
    if (phone.startsWith('+91')) {
      return phone.substring(3);
    }
    return phone;
  }

  void _showShopContactDialog(BuildContext context, Map<String, dynamic> entry) {
    final shopName = entry['name'].toString();
    final shopId = entry['shopId'].toString();
    
    // Show loading state
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.4,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(20),
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: FutureBuilder<String>(
          future: _fetchShopkeeperPhone(shopId, entry),
          builder: (context, snapshot) {
            // Show loading indicator while fetching
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Fetching shop contact information...')
                  ],
                ),
              );
            }
            
            // Show error if any
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error loading contact information: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              );
            }
            
            // Get the phone number from the snapshot
            final shopPhone = snapshot.data ?? '';
            final formattedPhone = _formatPhoneForCopy(shopPhone);
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Shop Details',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
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
                
                // Shop Avatar and Name
                Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.blue.withOpacity(0.2),
                      child: Text(
                        shopName.isNotEmpty ? shopName[0] : '?',
                        style: const TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            shopName,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (shopPhone.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.phone, 
                                  size: 16, 
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: SelectableText(
                                    shopPhone,
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.copy, size: 20),
                                  padding: EdgeInsets.zero,
                                  constraints: BoxConstraints(),
                                  onPressed: () {
                                    // Copy the formatted phone number to clipboard
                                    Clipboard.setData(ClipboardData(text: formattedPhone));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Phone number copied without +91'),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ] else
                            Text(
                              'No contact information available',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showShopCountDialog(BuildContext context, Map<String, dynamic> entry) async {
    final customerId = entry['customerId'].toString();
    final shopName = entry['name'].toString();
    
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text("Loading shop information...")
          ],
        ),
      ),
    );
    
    // Get the shop count
    final shopCount = await getShopCountForCustomer(customerId);
    
    // Close the loading dialog
    Navigator.of(context).pop();
    
    // Show the shop count dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Shop Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Shop: $shopName'),
            SizedBox(height: 8),
            Text('Number of shops you have udhari with: $shopCount'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final AuthService _authService = AuthService();

    return Scaffold(
      backgroundColor: themeProvider.backgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor:
            themeProvider.isDarkMode ? Colors.grey[850] : Colors.blue,
        title: const Text(
          'Udhari Pe',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              final shouldLogout = await showDialog<bool>(
                context: context,
                builder:
                    (context) => AlertDialog(
                      title: const Text('Confirm Logout'),
                      content: const Text('Are you sure you want to logout?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Logout'),
                        ),
                      ],
                    ),
              );

              if (shouldLogout == true) {
                await _authService.signOut();
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SelectUserTypeScreen(),
                    ),
                    (route) => false,
                  );
                }
              }
            },
          ),
          IconButton(
            icon: Icon(
              themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
              color: Colors.white,
            ),
            onPressed: () => themeProvider.toggleTheme(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Header section that can scroll away
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.blue),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.store_rounded,
                    size: 24,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Udhari at Shops',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          // Updated Search bar
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              textAlignVertical: TextAlignVertical.center,
              decoration: InputDecoration(
                hintText: 'Search shops...',
                hintStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
                prefixIcon: Icon(Icons.search, color: Colors.grey),
                suffixIcon:
                    _searchQuery.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _searchQuery = '';
                            });
                          },
                        )
                        : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                isDense: true,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          // Updated StreamBuilder
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color:
                    themeProvider.isDarkMode
                        ? Colors.grey[900]
                        : Colors.grey[100],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
                child: StreamBuilder<QuerySnapshot>(
                  stream: getUdhariStream(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final entries =
                        snapshot.data?.docs.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          print(
                            "Debug - Entry data: $data",
                          ); // Add this debug print

                          // Parse date safely
                          DateTime parseDate() {
                            try {
                              if (data['date'] is Timestamp) {
                                return (data['date'] as Timestamp).toDate();
                              } else if (data['date'] is String) {
                                return DateTime.parse(data['date']);
                              }
                              return DateTime.now();
                            } catch (e) {
                              print("Debug - Error parsing date: $e");
                              return DateTime.now();
                            }
                          }

                          return {
                            'name': data['shopName'] ?? 'Unknown Shop',
                            'amount': '₹${data['amount']?.toString() ?? '0'}',
                            'date': parseDate(),
                            'shopId': data['shopId'] ?? '',
                            'customerId': data['customerId'] ?? data['contact'] ?? '',
                            'status': data['status'] ?? 'pending',
                            'shopPhone': data['shopPhone'] ?? data['phone'] ?? '',
                          };
                        }).toList() ??
                        [];

                    if (entries.isEmpty) {
                      return Center(
                        child: Text(
                          'No udhari entries found',
                          style: TextStyle(color: themeProvider.textColor),
                        ),
                      );
                    }

                    // Apply search filter
                    final filteredEntries = _filterEntries(entries);

                    if (filteredEntries.isEmpty) {
                      return Center(
                        child: Text(
                          'No matching entries found',
                          style: TextStyle(color: themeProvider.textColor),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredEntries.length,
                      itemBuilder: (context, index) {
                        final entry = filteredEntries[index];
                        final DateTime date = entry['date'] as DateTime;
                        final String formattedDate =
                            "${date.day}/${date.month}/${date.year}";

                        return Card(
                          elevation: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: InkWell(
                            onTap: () {
                              // Show shop contact information when card is tapped
                              _showShopContactDialog(context, entry);
                            },
                            borderRadius: BorderRadius.circular(15),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              title: Text(
                                entry['name'].toString(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      entry['amount'].toString(),
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Added on $formattedDate',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: themeProvider.textColor.withOpacity(
                                        0.7,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              trailing: ElevatedButton(
                                onPressed: () {
                                  // Show a simple payment confirmation dialog
                                  showDialog(
                                    context: context,
                                    builder:
                                        (context) => AlertDialog(
                                          title: const Text(
                                            'Payment Confirmation',
                                          ),
                                          content: Text(
                                            'Do you want to pay ${entry['amount']}?',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed:
                                                  () => Navigator.pop(context),
                                              child: const Text('Cancel'),
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                // Show payment app chooser
                                                PaymentService.showPaymentAppChooser(
                                                  context: context,
                                                  receiverUpiId: entry['upiId']?.toString() ?? '',
                                                  receiverName: entry['name'].toString(),
                                                  receiverPhone: entry['phone']?.toString() ?? '',
                                                  amount: double.tryParse(entry['amount'].toString().replaceAll('₹', '')) ?? 0.0,
                                                  transactionNote: 'Payment to ${entry['name']}',
                                                  onPaymentComplete: (success) {
                                                    if (success) {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        const SnackBar(content: Text('Payment initiated successfully')),
                                                      );
                                                    }
                                                  },
                                                );
                                                Navigator.pop(context);
                                              },
                                              child: const Text('Pay'),
                                            ),
                                          ],
                                        ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                ),
                                child: const Text(
                                  'Pay Now',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
