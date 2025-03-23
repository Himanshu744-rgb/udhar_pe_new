import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'signup_screen.dart';
import 'forgot_pswd.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/firebase_service.dart';
import 'shopkeeper_home.dart';
import 'customer_home.dart';

class LoginScreen extends StatefulWidget {
  final String userType;

  const LoginScreen({Key? key, required this.userType}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  bool _isPasswordVisible = false;
  bool _rememberMe = false;
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Widget _buildTextField(
    ThemeProvider themeProvider,
    String hintText,
    IconData icon,
    bool isPassword,
    TextEditingController controller,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: controller,
        style: TextStyle(color: themeProvider.textColor),
        obscureText: isPassword ? !_isPasswordVisible : false,
        decoration: InputDecoration(
          prefixIcon: Icon(
            icon,
            color: themeProvider.isDarkMode ? Colors.white70 : Colors.black54,
          ),
          suffixIcon:
              isPassword
                  ? IconButton(
                    icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color:
                          themeProvider.isDarkMode
                              ? Colors.white70
                              : Colors.black54,
                    ),
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                  )
                  : null,
          hintText: hintText,
          hintStyle: TextStyle(
            color: themeProvider.isDarkMode ? Colors.white60 : Colors.black45,
          ),
          filled: true,
          fillColor:
              themeProvider.isDarkMode ? Colors.grey[800] : Colors.grey[200],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildSocialButton(ThemeProvider themeProvider, String assetPath) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: themeProvider.isDarkMode ? Colors.grey[800] : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Image.asset(assetPath, height: 24),
        onPressed: () {},
      ),
    );
  }

  void _handleLogin() async {
    String email = _emailController.text;
    String password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all fields'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        Navigator.pop(context); // Close loading dialog

        if (context.mounted) {
          if (widget.userType == "Shopkeeper") {
            // Show dialog to collect shop name
            String? shopName = await showDialog<String>(
              context: context,
              barrierDismissible: false,
              builder: (BuildContext dialogContext) {
                // Get ThemeProvider inside the builder
                final dialogThemeProvider = Provider.of<ThemeProvider>(
                  context,
                  listen: false,
                );
                String tempShopName = '';
                return AlertDialog(
                  title: Text(
                    'Enter Shop Name',
                    style: TextStyle(color: dialogThemeProvider.textColor),
                  ),
                  content: TextField(
                    onChanged: (value) => tempShopName = value,
                    decoration: InputDecoration(
                      hintText: 'Enter your shop name',
                      hintStyle: TextStyle(
                        color:
                            dialogThemeProvider.isDarkMode
                                ? Colors.white60
                                : Colors.black45,
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      child: const Text('Submit'),
                      onPressed: () {
                        if (tempShopName.trim().isNotEmpty) {
                          Navigator.of(dialogContext).pop(tempShopName);
                        }
                      },
                    ),
                  ],
                );
              },
            );

            if (shopName != null && shopName.trim().isNotEmpty) {
              await FirebaseFirestore.instance
                  .collection('shops')
                  .doc(credential.user!.uid)
                  .set({'name': shopName.trim()});

              if (context.mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ShopkeeperHomeScreen(),
                  ),
                );
              }
            }
          } else {
            // Navigate to CustomerScreen for customer login
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => CustomerHomeScreen(), // Remove const
              ),
            );
          }

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Login successful!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      Navigator.pop(context); // Close loading dialog
      String message;
      if (e.code == 'user-not-found') {
        message = 'No user found with this email.';
      } else if (e.code == 'wrong-password') {
        message = 'Wrong password provided.';
      } else {
        message = e.message ?? 'An error occurred';
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('An unexpected error occurred'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _showDialog(String title, String message, {required bool isError}) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title, style: TextStyle(color: themeProvider.textColor)),
          content: Text(
            message,
            style: TextStyle(color: themeProvider.textColor),
          ),
          backgroundColor:
              themeProvider.isDarkMode ? Colors.grey[800] : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
                if (!isError) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ShopkeeperHomeScreen(),
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: themeProvider.isDarkMode ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "${widget.userType} Login",
          style: TextStyle(
            color: themeProvider.isDarkMode ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: themeProvider.isDarkMode ? Colors.white : Colors.black,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
              color: themeProvider.textColor,
            ),
            onPressed: () {
              themeProvider.toggleTheme();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            themeProvider.isDarkMode
                                ? Colors.grey[800]
                                : Colors.grey[100],
                      ),
                      child: Image.asset(
                        "assets/image.jpg",
                        height: 80,
                        width: 80,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      "Welcome back, ${widget.userType}!",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: themeProvider.textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Login to continue",
                      style: TextStyle(
                        fontSize: 16,
                        color:
                            themeProvider.isDarkMode
                                ? Colors.white70
                                : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 32),
                    _buildTextField(
                      themeProvider,
                      "Email",
                      Icons.email,
                      false,
                      _emailController,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      themeProvider,
                      "Password",
                      Icons.lock,
                      true,
                      _passwordController,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Switch(
                              value: _rememberMe,
                              onChanged: (value) {
                                setState(() {
                                  _rememberMe = value;
                                });
                              },
                              activeColor: const Color(0xFF2296F3),
                            ),
                            Text(
                              "Remember Me",
                              style: TextStyle(
                                color:
                                    themeProvider.isDarkMode
                                        ? Colors.white70
                                        : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) =>
                                        const ForgotPswdScreen(), // Update this line
                              ),
                            );
                          },
                          child: const Text(
                            "Forgot Password?",
                            style: TextStyle(
                              color: Color(0xFF2296F3),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              themeProvider.isDarkMode
                                  ? Colors.blue
                                  : Colors.blue.shade100,
                          foregroundColor:
                              themeProvider.isDarkMode
                                  ? Colors.white
                                  : Colors.blue.shade900,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        onPressed: _handleLogin,
                        child: Text(
                          "Login",
                          style: TextStyle(
                            fontSize: 16,
                            color:
                                themeProvider.isDarkMode
                                    ? Colors.white
                                    : Colors.blue.shade900,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color:
                                themeProvider.isDarkMode
                                    ? Colors.white30
                                    : Colors.grey[400],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            "Or continue with",
                            style: TextStyle(
                              color:
                                  themeProvider.isDarkMode
                                      ? Colors.white70
                                      : Colors.grey[600],
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color:
                                themeProvider.isDarkMode
                                    ? Colors.white30
                                    : Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildSocialButton(themeProvider, "assets/google.png"),
                        const SizedBox(width: 20),
                        _buildSocialButton(themeProvider, "assets/apple.png"),
                        const SizedBox(width: 20),
                        _buildSocialButton(
                          themeProvider,
                          "assets/facebook.png",
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "New user? ",
                          style: TextStyle(
                            color:
                                themeProvider.isDarkMode
                                    ? Colors.white70
                                    : Colors.black87,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) =>
                                        SignupScreen(userType: widget.userType),
                              ),
                            );
                          },
                          child: const Text(
                            "Click here",
                            style: TextStyle(
                              color: Color(0xFF2296F3),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          " to register.",
                          style: TextStyle(
                            color:
                                themeProvider.isDarkMode
                                    ? Colors.white70
                                    : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
