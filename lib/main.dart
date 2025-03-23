import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import './providers/theme_provider.dart';
import './screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // Ensure Firebase is initialized

  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return FutureBuilder(
      future: Firebase.initializeApp(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const MaterialApp(
            home: Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ), // Show loading screen
            ),
          );
        } else if (snapshot.hasError) {
          return MaterialApp(
            home: Scaffold(
              body: Center(
                child: Text("Firebase Init Error: ${snapshot.error}"),
              ),
            ),
          );
        }

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'UdharPe',
          theme: ThemeData(
            primaryColor: themeProvider.primaryColor,
            scaffoldBackgroundColor: themeProvider.backgroundColor,
            textTheme: Theme.of(context).textTheme.apply(
              bodyColor: themeProvider.textColor,
              displayColor: themeProvider.textColor,
            ),
            colorScheme: ColorScheme.fromSeed(
              seedColor: themeProvider.primaryColor,
              brightness:
                  themeProvider.isDarkMode ? Brightness.dark : Brightness.light,
            ),
          ),
          home: HomeScreen(
            toggleTheme: (bool value) {
              themeProvider.toggleTheme();
            },
          ),
        );
      },
    );
  }
}
