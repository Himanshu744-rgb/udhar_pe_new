import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import './providers/theme_provider.dart';
import 'screens/login_screen.dart';
import 'screens/shopkeeper_home.dart';
import 'screens/customer_home.dart';
import 'screens/select_user_type.dart'; // Add this import

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
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rememberMe = prefs.getBool('rememberMe') ?? false;
      final userType = prefs.getString('userType');
      final user = FirebaseAuth.instance.currentUser;

      if (rememberMe && user != null) {
        if (userType == "Shopkeeper") {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const ShopkeeperHomeScreen(),
            ),
          );
        } else if (userType == "Customer") {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => CustomerHomeScreen()),
          );
        } else {
          _redirectToHome();
        }
      } else {
        _redirectToHome();
      }
    } catch (e) {
      _redirectToHome();
    }
  }

  void _redirectToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const SelectUserTypeScreen(), // Change this line
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
