import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class CustomerHomeScreen extends StatelessWidget {
  final List<Map<String, String>> shops = [
    {"name": "Sharma General Store", "amount": "₹26400"},
    {"name": "Gupta Kirana", "amount": "₹10000"},
    {"name": "Verma Electronics", "amount": "₹10101"},
  ];

  CustomerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: themeProvider.backgroundColor,
      appBar: AppBar(
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
            icon: Icon(
              themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
              color: Colors.white,
            ),
            onPressed: () => themeProvider.toggleTheme(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                "Search Shops",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: themeProvider.textColor,
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              style: TextStyle(color: themeProvider.textColor),
              decoration: InputDecoration(
                hintText: "Search...",
                hintStyle: TextStyle(
                  color:
                      themeProvider.isDarkMode
                          ? Colors.white60
                          : Colors.black45,
                ),
                prefixIcon: Icon(Icons.search, color: themeProvider.textColor),
                filled: true,
                fillColor:
                    themeProvider.isDarkMode
                        ? Colors.grey[800]
                        : Colors.grey[200],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color:
                    themeProvider.isDarkMode ? Colors.blue[900] : Colors.blue,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "UDHARI AT SHOPS",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 10),
                  Icon(Icons.store, color: Colors.white),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Shop Name",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: themeProvider.textColor,
                    ),
                  ),
                  Text(
                    "Amount Due",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: themeProvider.textColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 5),
            Expanded(
              child: ListView.builder(
                itemCount: shops.length,
                itemBuilder: (context, index) {
                  return Card(
                    elevation: 3,
                    color:
                        themeProvider.isDarkMode
                            ? Colors.grey[800]
                            : Colors.white,
                    child: ListTile(
                      title: Text(
                        shops[index]["name"]!,
                        style: TextStyle(
                          fontSize: 16,
                          color: themeProvider.textColor,
                        ),
                      ),
                      subtitle: Text(
                        shops[index]["amount"]!,
                        style: const TextStyle(fontSize: 16, color: Colors.red),
                      ),
                      trailing: ElevatedButton(
                        onPressed: () {
                          // Payment functionality
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          "PAY NOW",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
