import 'dart:async'; // Add this import
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/theme_provider.dart';

class ForgotPswdScreen extends StatefulWidget {
  const ForgotPswdScreen({Key? key}) : super(key: key);

  @override
  _ForgotPswdScreenState createState() => _ForgotPswdScreenState();
}

class _ForgotPswdScreenState extends State<ForgotPswdScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  bool _isOtpSent = false;
  bool _isLoading = false;

  Widget _buildTextField(
    String hint,
    TextEditingController controller,
    ThemeProvider themeProvider,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: controller,
        style: TextStyle(color: themeProvider.textColor),
        decoration: InputDecoration(
          hintText: hint,
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

  Future<void> _sendPasswordResetEmail() async {
    if (_emailController.text.isEmpty) {
      _showErrorDialog('Please enter your email address');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Verify email format
      String email = _emailController.text.trim();
      if (!email.contains('@') || !email.contains('.')) {
        throw FirebaseAuthException(
          code: 'invalid-email',
          message: 'Please enter a valid email address',
        );
      }

      // Send reset email
      await FirebaseAuth.instance
          .sendPasswordResetEmail(email: email)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw TimeoutException('Request timed out. Please try again.');
            },
          );

      if (mounted) {
        setState(() => _isLoading = false);
        _showSuccessDialog(
          'If an account exists with $email, a password reset link will be sent.\n\n'
          'Please also check your spam folder.\n\n'
          'The link will expire in 1 hour.',
        );

        // Clear email field after success
        _emailController.clear();
      }
    } on TimeoutException catch (_) {
      setState(() => _isLoading = false);
      _showErrorDialog('Request timed out. Please try again.');
    } on FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);
      String message = 'An error occurred';

      switch (e.code) {
        case 'invalid-email':
          message = 'Please enter a valid email address.';
          break;
        case 'user-not-found':
          // Don't reveal if user exists or not for security
          message = 'If an account exists, a reset link will be sent.';
          break;
        case 'too-many-requests':
          message = 'Too many attempts. Please try again later.';
          break;
        default:
          message = e.message ?? 'An error occurred';
      }
      _showErrorDialog(message);
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorDialog('An error occurred. Please try again.');
    }
  }

  void _verifyOTP() {
    if (_otpController.text.isEmpty) {
      _showErrorDialog('Please enter the OTP');
      return;
    }
    // Note: Firebase's default password reset flow uses email links rather than OTP
    // This is a placeholder for custom OTP verification logic
    _showSuccessDialog('OTP verified successfully!');
  }

  void _showErrorDialog(String message) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor:
                themeProvider.isDarkMode ? Colors.grey[800] : Colors.white,
            title: Text(
              'Error',
              style: TextStyle(color: themeProvider.textColor),
            ),
            content: Text(
              message,
              style: TextStyle(color: themeProvider.textColor),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK', style: TextStyle(color: Colors.blue)),
              ),
            ],
          ),
    );
  }

  void _showSuccessDialog(String message) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor:
                themeProvider.isDarkMode ? Colors.grey[800] : Colors.white,
            title: Text(
              'Success',
              style: TextStyle(color: themeProvider.textColor),
            ),
            content: Text(
              message,
              style: TextStyle(color: themeProvider.textColor),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK', style: TextStyle(color: Colors.blue)),
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Forgot Password',
          style: TextStyle(color: themeProvider.textColor),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: themeProvider.textColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            Text(
              'Reset Your Password',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: themeProvider.textColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Enter your registered email address. We will send you a link to reset your password.',
              style: TextStyle(
                fontSize: 16,
                color: themeProvider.textColor.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 32),
            _buildTextField('Email', _emailController, themeProvider),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _sendPasswordResetEmail,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child:
                  _isLoading
                      ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                      : const Text(
                        'Send Reset Link',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
            ),
            // Remove OTP section as Firebase uses email links
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }
}
